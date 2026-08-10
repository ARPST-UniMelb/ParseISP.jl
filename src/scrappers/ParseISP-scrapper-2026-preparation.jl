module ISP2026InputPreparation

using ZipFile
using ..ISP2026FileDownloader

export prepare_isp2026_inputs

const _TARGET_KEYS = (
    :isp26_inputs,
    :isp26_ev_support,
    :isp26_outlook,
    :isp26_model,
    :isp26_solar_traces,
    :isp26_wind_traces,
)

const _CORE_WORKBOOKS = [
    "2026 ISP - Slower Growth - Core.xlsx",
    "2026 ISP - Step Change - Core.xlsx",
    "2026 ISP - Accelerated Transition - Core.xlsx",
]

const _SCENARIOS = [
    "2026 ISP Slower Growth",
    "2026 ISP Step Change",
    "2026 ISP Accelerated Transition",
]

const _MODEL_TRACE_FAMILIES = [
    "demand",
    "dnsp",
    "gas",
    "hydro",
    "load_subtractor",
    "rooftop PV",
]

const _STAGING_PREFIX = "parseisp-isp2026-"
const _COPY_CHUNK_BYTES = 1024 * 1024
const _WINDOWS_RESERVED_BASENAMES = Set([
    "CON", "PRN", "AUX", "NUL",
    ["COM$(i)" for i in 1:9]...,
    ["LPT$(i)" for i in 1:9]...,
])

struct _ArchiveMember
    target::Symbol
    archive::String
    member::String
    staged::String
    destination::String
end

_source_error(key::Symbol, path::AbstractString, message::AbstractString) =
    ErrorException("ISP 2026 target $(key) at $(path): $(message)")

function _is_real_file(path::AbstractString)
    return !islink(path) && isfile(path)
end

function _require_real_directory(path::AbstractString, key::Symbol, source_path::AbstractString)
    if islink(path) || !isdir(path)
        throw(_source_error(key, source_path,
            "destination ancestor is not a real directory: $(path)"))
    end
end

function _resolve_targets(root::String)
    targets = ISP2026FileDownloader.isp_file_targets()
    resolved = Dict{Symbol,String}()

    for key in _TARGET_KEYS
        matches = filter(target -> target.key == key, targets)
        length(matches) == 1 || throw(_source_error(key, root,
            "expected exactly one downloader target, found $(length(matches))"))
        target = only(matches)
        path = abspath(normpath(joinpath(root, target.subdir, target.filename)))
        _is_real_file(path) || throw(_source_error(key, path,
            "required input is missing or is not a regular file"))
        resolved[key] = path
    end

    return resolved
end


function _normalise_member(raw_name::AbstractString)
    isempty(raw_name) && throw(ArgumentError("member has an empty name"))
    occursin('\0', raw_name) && throw(ArgumentError("member name contains a NUL byte"))

    slash_name = replace(String(raw_name), '\\' => '/')
    startswith(slash_name, '/') && throw(ArgumentError("member uses an absolute path"))
    occursin(r"^[A-Za-z]:($|/)", slash_name) &&
        throw(ArgumentError("member uses a Windows drive path"))

    is_directory = endswith(slash_name, '/')
    parts = split(slash_name, '/'; keepempty = true)
    is_directory && pop!(parts)
    isempty(parts) && throw(ArgumentError("member has an empty name"))
    any(isempty, parts) && throw(ArgumentError("member contains an empty path component"))

    for part in parts
        part in (".", "..") && throw(ArgumentError("member contains a $(repr(part)) path component"))
        occursin(':', part) && throw(ArgumentError("member contains a Windows-unsafe colon"))
        (endswith(part, '.') || endswith(part, ' ')) &&
            throw(ArgumentError("member has a Windows-unsafe trailing dot or space"))
        basename = uppercase(first(split(part, '.'; limit = 2)))
        basename in _WINDOWS_RESERVED_BASENAMES &&
            throw(ArgumentError("member uses reserved Windows device name $(repr(part))"))
    end

    return join(parts, '/'), is_directory
end

function _validate_member_tree(files, key::Symbol, archive::String)
    entries = NamedTuple{(:file, :name, :is_directory),Tuple{Any,String,Bool}}[]
    exact_names = Set{String}()
    folded_names = Dict{String,String}()

    for file in files
        name, is_directory = try
            _normalise_member(file.name)
        catch err
            throw(_source_error(key, archive,
                "rejected member $(repr(file.name)): $(sprint(showerror, err))"))
        end

        name in exact_names && throw(_source_error(key, archive,
            "duplicate normalized member $(repr(name))"))
        folded = lowercase(name)
        if haskey(folded_names, folded)
            throw(_source_error(key, archive,
                "case-fold-equivalent members $(repr(folded_names[folded])) and $(repr(name))"))
        end
        push!(exact_names, name)
        folded_names[folded] = name
        push!(entries, (file = file, name = name, is_directory = is_directory))
    end

    regular_names = Set(entry.name for entry in entries if !entry.is_directory)
    all_names = collect(exact_names)
    for file_name in regular_names
        prefix = file_name * "/"
        descendant_index = findfirst(name -> startswith(name, prefix), all_names)
        descendant_index === nothing || throw(_source_error(key, archive,
            "regular-file member $(repr(file_name)) is an ancestor of $(repr(all_names[descendant_index]))"))
    end

    return entries
end

function _copy_member!(destination::AbstractString, file)
    open(destination, "w") do io
        if file.uncompressedsize == 0
            read(file, 0) # Force ZipFile's CRC check for an empty member.
        else
            while !eof(file)
                remaining = Int(file.uncompressedsize - position(file))
                write(io, read(file, min(_COPY_CHUNK_BYTES, remaining)))
            end
        end
    end
end

function _destination_base(root::String, key::Symbol)
    return key in (:isp26_solar_traces, :isp26_wind_traces) ? joinpath(root, "Traces") : root
end

function _archive_roots(key::Symbol)
    key == :isp26_outlook && return ["Core scenarios", "Sensitivities"]
    key == :isp26_model && return ["2026 ISP Model"]
    key == :isp26_solar_traces && return ["2026 ISP Solar traces"]
    key == :isp26_wind_traces && return ["2026 ISP Wind traces"]
    error("unsupported ISP 2026 archive target $(key)")
end

function _stage_archive(key::Symbol, archive::String, root::String, staging_root::String)
    archive_stage = joinpath(staging_root, String(key))
    mkpath(archive_stage)
    reader = try
        ZipFile.Reader(archive)
    catch err
        throw(_source_error(key, archive, "cannot open archive: $(sprint(showerror, err))"))
    end

    try
        entries = _validate_member_tree(reader.files, key, archive)
        allowed_roots = _archive_roots(key)
        for entry in entries
            any(archive_root -> entry.name == archive_root ||
                                startswith(entry.name, archive_root * "/"), allowed_roots) ||
                throw(_source_error(key, archive,
                    "unexpected top-level member $(repr(entry.name))"))
        end
        staged = _ArchiveMember[]
        destination_base = _destination_base(root, key)

        for entry in entries
            entry.is_directory && continue
            relative_parts = split(entry.name, '/')
            staged_path = joinpath(archive_stage, relative_parts...)
            destination = abspath(normpath(joinpath(destination_base, relative_parts...)))
            startswith(destination, root * Base.Filesystem.path_separator) ||
                throw(_source_error(key, archive,
                    "rejected member $(repr(entry.name)): destination escapes root"))
            mkpath(dirname(staged_path))
            try
                _copy_member!(staged_path, entry.file)
            catch err
                throw(_source_error(key, archive,
                    "failed to read member $(repr(entry.name)): $(sprint(showerror, err))"))
            end
            push!(staged, _ArchiveMember(key, archive, entry.name, staged_path, destination))
        end

        return staged
    finally
        close(reader)
    end
end

function _validate_outlook(members, archive::String)
    key = :isp26_outlook
    names = Set(member.member for member in members)
    required_core = Set("Core scenarios/$(workbook)" for workbook in _CORE_WORKBOOKS)
    observed_core = Set(name for name in names if startswith(name, "Core scenarios/"))
    observed_core == required_core || throw(_source_error(key, archive,
        "Core scenarios must contain exactly $(sort!(collect(required_core))); observed $(sort!(collect(observed_core)))"))
    for workbook in _CORE_WORKBOOKS
        required = "Core scenarios/$(workbook)"
        required in names || throw(_source_error(key, archive,
            "missing required member $(repr(required))"))
    end
end

function _validate_model(members, archive::String)
    key = :isp26_model
    names = [member.member for member in members]

    for scenario in _SCENARIOS
        scenario_root = "2026 ISP Model/$(scenario)"
        model_file = "$(scenario_root)/$(scenario) Model.xml"
        count(==(model_file), names) == 1 || throw(_source_error(key, archive,
            "scenario $(repr(scenario)) must contain exactly one $(repr(model_file))"))

        for family in _MODEL_TRACE_FAMILIES
            trace_root = "$(scenario_root)/Traces/$(family)/"
            any(name -> startswith(name, trace_root) && endswith(lowercase(name), ".csv"), names) ||
                throw(_source_error(key, archive,
                    "scenario $(repr(scenario)) has no CSV under trace directory $(repr(family))"))
        end
    end
end

function _validate_renewable(members, key::Symbol, archive::String,
                             archive_root::String, family::String)
    trace_root = "$(archive_root)/$(family)/"
    any(member -> startswith(member.member, trace_root) &&
                  endswith(lowercase(member.member), ".csv"), members) ||
        throw(_source_error(key, archive,
            "no CSV found under required trace directory $(repr(trace_root))"))
end

function _files_identical(first_path::AbstractString, second_path::AbstractString)
    filesize(first_path) == filesize(second_path) || return false
    open(first_path, "r") do first_io
        open(second_path, "r") do second_io
            while !eof(first_io)
                first_chunk = read(first_io, _COPY_CHUNK_BYTES)
                second_chunk = read(second_io, length(first_chunk))
                first_chunk == second_chunk || return false
            end
            return eof(second_io)
        end
    end
end

function _check_destination_ancestors(root::String, destination::String,
                                      key::Symbol, archive::String)
    _require_real_directory(root, key, archive)
    relative_parent = relpath(dirname(destination), root)
    relative_parent == "." && return

    current = root
    for part in splitpath(relative_parent)
        current = joinpath(current, part)
        if islink(current)
            throw(_source_error(key, archive,
                "destination ancestor is a symlink: $(current)"))
        elseif ispath(current) && !isdir(current)
            throw(_source_error(key, archive,
                "destination ancestor is not a directory: $(current)"))
        end
    end
end

function _preflight_destinations(members::Vector{_ArchiveMember}, root::String,
                                 overwrite::Bool)
    folded = Dict{String,_ArchiveMember}()
    exact = Dict{String,_ArchiveMember}()

    for member in members
        if haskey(exact, member.destination)
            previous = exact[member.destination]
            throw(_source_error(member.target, member.archive,
                "member $(repr(member.member)) shares destination $(member.destination) with target $(previous.target)"))
        end
        fold = lowercase(member.destination)
        if haskey(folded, fold)
            previous = folded[fold]
            throw(_source_error(member.target, member.archive,
                "member $(repr(member.member)) has case-fold-equivalent destination $(previous.destination)"))
        end
        exact[member.destination] = member
        folded[fold] = member
    end

    destinations = collect(keys(exact))
    for destination in destinations
        prefix = destination * Base.Filesystem.path_separator
        descendant_index = findfirst(path -> startswith(path, prefix), destinations)
        descendant_index === nothing || begin
            member = exact[destination]
            throw(_source_error(member.target, member.archive,
                "regular-file destination $(destination) is an ancestor of $(destinations[descendant_index])"))
        end
    end

    for member in members
        _check_destination_ancestors(root, member.destination, member.target, member.archive)
        if islink(member.destination)
            throw(_source_error(member.target, member.archive,
                "destination is a symlink and cannot be replaced: $(member.destination)"))
        elseif isfile(member.destination)
            if !_files_identical(member.staged, member.destination) && !overwrite
                throw(_source_error(member.target, member.archive,
                    "destination conflicts with archive member $(repr(member.member)): $(member.destination)"))
            end
        elseif ispath(member.destination)
            throw(_source_error(member.target, member.archive,
                "destination is not a regular file and cannot be replaced: $(member.destination)"))
        end
    end
end

function _install_members!(members::Vector{_ArchiveMember}, root::String, overwrite::Bool)
    for member in members
        _check_destination_ancestors(root, member.destination, member.target, member.archive)
        if isfile(member.destination) &&
           _files_identical(member.staged, member.destination)
            continue
        end
        mkpath(dirname(member.destination))
        cp(member.staged, member.destination; force = overwrite)
    end
end

"""
    prepare_isp2026_inputs(root::AbstractString; overwrite::Bool = false)

Validate and extract the four downloader-owned ISP 2026 archives beneath `root`.
The two downloader-owned workbooks must already be present. All archives are fully
staged and preflighted before any archive member is installed.
"""
function prepare_isp2026_inputs(root::AbstractString; overwrite::Bool = false)
    normalized_root = abspath(normpath(root))
    _require_real_directory(normalized_root, :isp26_inputs, normalized_root)
    paths = _resolve_targets(normalized_root)

    mktempdir(; prefix = _STAGING_PREFIX) do staging_root
        outlook = _stage_archive(:isp26_outlook, paths[:isp26_outlook], normalized_root, staging_root)
        model = _stage_archive(:isp26_model, paths[:isp26_model], normalized_root, staging_root)
        solar = _stage_archive(:isp26_solar_traces, paths[:isp26_solar_traces], normalized_root, staging_root)
        wind = _stage_archive(:isp26_wind_traces, paths[:isp26_wind_traces], normalized_root, staging_root)

        _validate_outlook(outlook, paths[:isp26_outlook])
        _validate_model(model, paths[:isp26_model])
        _validate_renewable(solar, :isp26_solar_traces, paths[:isp26_solar_traces],
                            "2026 ISP Solar traces", "solar")
        _validate_renewable(wind, :isp26_wind_traces, paths[:isp26_wind_traces],
                            "2026 ISP Wind traces", "wind")

        members = vcat(outlook, model, solar, wind)
        _preflight_destinations(members, normalized_root, overwrite)
        _install_members!(members, normalized_root, overwrite)
    end

    core_workbooks = [
        joinpath(normalized_root, "Core scenarios", workbook)
        for workbook in _CORE_WORKBOOKS
    ]
    model_root = joinpath(normalized_root, "2026 ISP Model")
    scenario_roots = [joinpath(model_root, scenario) for scenario in _SCENARIOS]

    return (
        root = normalized_root,
        inputs_workbook = paths[:isp26_inputs],
        ev_workbook = paths[:isp26_ev_support],
        outlook_archive = paths[:isp26_outlook],
        model_archive = paths[:isp26_model],
        solar_archive = paths[:isp26_solar_traces],
        wind_archive = paths[:isp26_wind_traces],
        core_workbooks = core_workbooks,
        model_root = model_root,
        scenario_roots = scenario_roots,
        solar_trace_dir = joinpath(normalized_root, "Traces", "2026 ISP Solar traces", "solar"),
        wind_trace_dir = joinpath(normalized_root, "Traces", "2026 ISP Wind traces", "wind"),
    )
end

end
