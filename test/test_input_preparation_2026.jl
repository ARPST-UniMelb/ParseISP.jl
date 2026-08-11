using ParseISP
using Test
using ZipFile

const ISP2026_PREPARATION_SCENARIOS = [
    "2026 ISP Slower Growth",
    "2026 ISP Step Change",
    "2026 ISP Accelerated Transition",
]

const ISP2026_PREPARATION_FAMILIES = [
    "demand",
    "dnsp",
    "gas",
    "hydro",
    "load_subtractor",
    "rooftop PV",
]

function write_test_zip(path::AbstractString, entries;
                        method::Integer = ZipFile.Deflate)
    mkpath(dirname(path))
    writer = ZipFile.Writer(path)
    try
        for (name, content) in entries
            file = ZipFile.addfile(writer, name; method = method)
            write(file, content)
        end
    finally
        close(writer)
    end
    return path
end

function valid_outlook_entries()
    return [
        "Core scenarios/2026 ISP - Slower Growth - Core.xlsx" => "slower",
        "Core scenarios/2026 ISP - Step Change - Core.xlsx" => "step",
        "Core scenarios/2026 ISP - Accelerated Transition - Core.xlsx" => "accelerated",
        "Sensitivities/2026 ISP - Step Change - Higher Demand.xlsx" => "sensitivity",
    ]
end

function valid_model_entries()
    entries = Pair{String,String}[]
    for scenario in ISP2026_PREPARATION_SCENARIOS
        root = "2026 ISP Model/$(scenario)"
        push!(entries, "$(root)/$(scenario) Model.xml" => "<model/>")
        for family in ISP2026_PREPARATION_FAMILIES
            push!(entries, "$(root)/Traces/$(family)/sample.csv" => "Year,Value\n2026,1\n")
        end
    end
    return entries
end

valid_solar_entries() = [
    "2026 ISP Solar traces/solar/sample.csv" => "Year,Value\n2026,1\n",
]

valid_wind_entries() = [
    "2026 ISP Wind traces/wind/sample.csv" => "Year,Value\n2026,1\n",
]

function target_path(root::AbstractString, key::Symbol)
    matches = filter(target -> target.key == key,
                     ParseISP.ISP2026FileDownloader.isp_file_targets())
    @assert length(matches) == 1
    target = only(matches)
    return abspath(normpath(joinpath(root, target.subdir, target.filename)))
end

function setup_valid_isp2026_root(root::AbstractString)
    mkpath(root)
    write(target_path(root, :isp26_inputs), "inputs")
    write(target_path(root, :isp26_ev_support), "ev")
    write_test_zip(target_path(root, :isp26_outlook), valid_outlook_entries())
    write_test_zip(target_path(root, :isp26_model), valid_model_entries())
    write_test_zip(target_path(root, :isp26_solar_traces), valid_solar_entries())
    write_test_zip(target_path(root, :isp26_wind_traces), valid_wind_entries())
    return root
end

function preparation_error(f::Function)
    try
        f()
        return ""
    catch err
        return sprint(showerror, err)
    end
end

function tree_snapshot(root::AbstractString)
    snapshot = Pair{String,Any}[]
    for (directory, directories, files) in walkdir(root)
        sort!(directories)
        sort!(files)
        relative_directory = relpath(directory, root)
        relative_directory == "." || push!(snapshot, relative_directory => :directory)
        for name in files
            path = joinpath(directory, name)
            relative = relpath(path, root)
            if islink(path)
                push!(snapshot, relative => (:symlink, readlink(path)))
            elseif isfile(path)
                push!(snapshot, relative => read(path))
            else
                push!(snapshot, relative => :special)
            end
        end
    end
    return snapshot
end

function staging_directories()
    return Set(filter(name -> startswith(name, "parseisp-isp2026-"), readdir(tempdir())))
end

function find_zip_signature(bytes::Vector{UInt8}, signature::NTuple{4,UInt8})
    for index in 1:(length(bytes) - 3)
        Tuple(bytes[index:(index + 3)]) == signature && return index
    end
    error("ZIP signature not found")
end

function patch_zip_method!(path::AbstractString, method::UInt16)
    bytes = read(path)
    local_header = find_zip_signature(bytes, (0x50, 0x4b, 0x03, 0x04))
    central_header = find_zip_signature(bytes, (0x50, 0x4b, 0x01, 0x02))
    bytes[local_header + 8] = UInt8(method & 0xff)
    bytes[local_header + 9] = UInt8(method >> 8)
    bytes[central_header + 10] = UInt8(method & 0xff)
    bytes[central_header + 11] = UInt8(method >> 8)
    write(path, bytes)
    return path
end

function corrupt_zip_crc!(path::AbstractString)
    bytes = read(path)
    central_header = find_zip_signature(bytes, (0x50, 0x4b, 0x01, 0x02))
    bytes[central_header + 16] ⊻= 0xff
    write(path, bytes)
    return path
end

@testset "ISP 2026 input preparation" begin
    @test isdefined(ParseISP, :prepare_isp2026_inputs)
    @test !(:prepare_isp2026_inputs in names(ParseISP))

    @testset "successful, normalized, and idempotent" begin
        mktempdir() do parent
            root = joinpath(parent, "source", "..", "source")
            setup_valid_isp2026_root(root)
            sentinel = joinpath(root, "unrelated", "sentinel.txt")
            mkpath(dirname(sentinel))
            write(sentinel, "keep")
            before_staging = staging_directories()

            cd(parent) do
                result = ParseISP.prepare_isp2026_inputs(root)
                expected_root = abspath(normpath(root))
                @test keys(result) == (
                    :root, :inputs_workbook, :ev_workbook, :outlook_archive,
                    :model_archive, :solar_archive, :wind_archive, :core_workbooks,
                    :model_root, :scenario_roots, :solar_trace_dir, :wind_trace_dir,
                )
                @test result.root == expected_root
                @test result.inputs_workbook == target_path(root, :isp26_inputs)
                @test result.ev_workbook == target_path(root, :isp26_ev_support)
                @test result.outlook_archive == target_path(root, :isp26_outlook)
                @test result.model_archive == target_path(root, :isp26_model)
                @test result.solar_archive == target_path(root, :isp26_solar_traces)
                @test result.wind_archive == target_path(root, :isp26_wind_traces)
                @test result.core_workbooks == [
                    joinpath(expected_root, "Core scenarios", "2026 ISP - Slower Growth - Core.xlsx"),
                    joinpath(expected_root, "Core scenarios", "2026 ISP - Step Change - Core.xlsx"),
                    joinpath(expected_root, "Core scenarios", "2026 ISP - Accelerated Transition - Core.xlsx"),
                ]
                @test result.model_root == joinpath(expected_root, "2026 ISP Model")
                @test result.scenario_roots == [
                    joinpath(result.model_root, scenario)
                    for scenario in ISP2026_PREPARATION_SCENARIOS
                ]
                @test result.solar_trace_dir == joinpath(expected_root, "Traces", "2026 ISP Solar traces", "solar")
                @test result.wind_trace_dir == joinpath(expected_root, "Traces", "2026 ISP Wind traces", "wind")
                @test all(isfile, result.core_workbooks)
                @test all(isdir, result.scenario_roots)
                @test isfile(joinpath(result.solar_trace_dir, "sample.csv"))
                @test isfile(joinpath(result.wind_trace_dir, "sample.csv"))
                @test !ispath(joinpath(root, "Auxiliary"))
                @test !ispath(joinpath(parent, "Auxiliary"))

                first_snapshot = tree_snapshot(root)
                repeated = ParseISP.prepare_isp2026_inputs(root)
                @test repeated == result
                @test tree_snapshot(root) == first_snapshot
            end

            @test read(sentinel, String) == "keep"
            @test staging_directories() == before_staging
        end
    end

    @testset "conflicts and explicit regular-file overwrite" begin
        mktempdir() do root
            setup_valid_isp2026_root(root)
            result = ParseISP.prepare_isp2026_inputs(root)
            destination = result.core_workbooks[1]
            write(destination, "local change")

            message = preparation_error() do
                ParseISP.prepare_isp2026_inputs(root)
            end
            @test occursin("isp26_outlook", message)
            @test occursin(target_path(root, :isp26_outlook), message)
            @test occursin(destination, message)
            @test read(destination, String) == "local change"

            ParseISP.prepare_isp2026_inputs(root; overwrite = true)
            @test read(destination, String) == "slower"
        end

        mktempdir() do root
            setup_valid_isp2026_root(root)
            destination = joinpath(root, "Core scenarios", "2026 ISP - Slower Growth - Core.xlsx")
            mkpath(destination)
            message = preparation_error() do
                ParseISP.prepare_isp2026_inputs(root; overwrite = true)
            end
            @test occursin("isp26_outlook", message)
            @test occursin(target_path(root, :isp26_outlook), message)
            @test occursin("not a regular file", message)
            @test isdir(destination)
        end
    end

    @testset "required downloader inputs" begin
        mktempdir() do root
            setup_valid_isp2026_root(root)
            missing = target_path(root, :isp26_ev_support)
            rm(missing)
            message = preparation_error() do
                ParseISP.prepare_isp2026_inputs(root)
            end
            @test occursin("isp26_ev_support", message)
            @test occursin(missing, message)
        end

        mktempdir() do root
            setup_valid_isp2026_root(root)
            wrong_type = target_path(root, :isp26_inputs)
            rm(wrong_type)
            mkpath(wrong_type)
            message = preparation_error() do
                ParseISP.prepare_isp2026_inputs(root)
            end
            @test occursin("isp26_inputs", message)
            @test occursin(wrong_type, message)
        end
    end

    @testset "physical layout requirements" begin
        mktempdir() do root
            setup_valid_isp2026_root(root)
            entries = filter(pair -> !occursin("Slower Growth - Core", first(pair)),
                             valid_outlook_entries())
            write_test_zip(target_path(root, :isp26_outlook), entries)
            message = preparation_error() do
                ParseISP.prepare_isp2026_inputs(root)
            end
            @test occursin("isp26_outlook", message)
            @test occursin("Slower Growth", message)
        end

        mktempdir() do root
            setup_valid_isp2026_root(root)
            entries = [valid_outlook_entries(); "Core scenarios/extra.xlsx" => "extra"]
            write_test_zip(target_path(root, :isp26_outlook), entries)
            message = preparation_error() do
                ParseISP.prepare_isp2026_inputs(root)
            end
            @test occursin("isp26_outlook", message)
            @test occursin("exactly", message)
            @test occursin("extra.xlsx", message)
        end

        mktempdir() do root
            setup_valid_isp2026_root(root)
            entries = filter(pair -> !occursin("/Traces/gas/", first(pair)), valid_model_entries())
            write_test_zip(target_path(root, :isp26_model), entries)
            message = preparation_error() do
                ParseISP.prepare_isp2026_inputs(root)
            end
            @test occursin("isp26_model", message)
            @test occursin("gas", message)
        end

        for (key, entries) in (
            (:isp26_outlook, ["elsewhere/file.xlsx" => "bad"]),
            (:isp26_model, ["elsewhere/file.csv" => "bad"]),
            (:isp26_solar_traces, ["elsewhere/sample.csv" => "bad"]),
            (:isp26_wind_traces, ["elsewhere/sample.csv" => "bad"]),
        )
            mktempdir() do root
                setup_valid_isp2026_root(root)
                write_test_zip(target_path(root, key), entries)
                message = preparation_error() do
                    ParseISP.prepare_isp2026_inputs(root)
                end
                @test occursin(String(key), message)
                @test occursin(target_path(root, key), message)
                @test occursin("elsewhere/file", message) || occursin("elsewhere/sample", message)
            end
        end

        mktempdir() do root
            setup_valid_isp2026_root(root)
            write_test_zip(target_path(root, :isp26_outlook), ["elsewhere/" => ""])
            message = preparation_error() do
                ParseISP.prepare_isp2026_inputs(root)
            end
            @test occursin("isp26_outlook", message)
            @test occursin(target_path(root, :isp26_outlook), message)
            @test occursin("elsewhere", message)
        end
    end

    @testset "unsafe archive member names and layouts" begin
        unsafe_cases = [
            ["" => "bad"] => "empty name",
            ["Core scenarios/nul\0name.xlsx" => "bad"] => "NUL",
            ["../escape.csv" => "bad"] => "..",
            ["/absolute.csv" => "bad"] => "absolute",
            ["C:/drive.csv" => "bad"] => "Windows drive",
            ["Core scenarios\\..\\escape.csv" => "bad"] => "..",
            ["Core scenarios//empty.csv" => "bad"] => "empty path component",
            ["Core scenarios/bad:name.xlsx" => "bad"] => "colon",
            ["Core scenarios/trailing. " => "bad"] => "trailing",
            ["Core scenarios/CON.txt" => "bad"] => "reserved Windows",
            ["Core scenarios/A.xlsx" => "one", "Core scenarios/a.xlsx" => "two"] => "case-fold",
            ["Core scenarios/a" => "file", "Core scenarios/a/b.csv" => "child"] => "ancestor",
            ["Core scenarios/duplicate.xlsx" => "one", "Core scenarios/duplicate.xlsx" => "two"] => "duplicate",
        ]

        for (entries, expected) in unsafe_cases
            mktempdir() do root
                setup_valid_isp2026_root(root)
                write_test_zip(target_path(root, :isp26_outlook), entries)
                message = preparation_error() do
                    ParseISP.prepare_isp2026_inputs(root)
                end
                @test occursin("isp26_outlook", message)
                @test occursin(target_path(root, :isp26_outlook), message)
                @test occursin(expected, message)
            end
        end
    end

    @testset "malformed, unsupported, and corrupt archives" begin
        mktempdir() do root
            setup_valid_isp2026_root(root)
            archive = target_path(root, :isp26_outlook)
            patch_zip_method!(archive, UInt16(99))
            message = preparation_error() do
                ParseISP.prepare_isp2026_inputs(root)
            end
            @test occursin("isp26_outlook", message)
            @test occursin(archive, message)
            @test occursin("compression method", message)
        end

        mktempdir() do root
            setup_valid_isp2026_root(root)
            archive = target_path(root, :isp26_solar_traces)
            corrupt_zip_crc!(archive)
            message = preparation_error() do
                ParseISP.prepare_isp2026_inputs(root)
            end
            @test occursin("isp26_solar_traces", message)
            @test occursin(archive, message)
            @test occursin("crc32", lowercase(message))
        end

        mktempdir() do root
            setup_valid_isp2026_root(root)
            archive = target_path(root, :isp26_wind_traces)
            write(archive, "not a ZIP archive")
            before = tree_snapshot(root)
            before_staging = staging_directories()
            message = preparation_error() do
                ParseISP.prepare_isp2026_inputs(root)
            end
            @test occursin("isp26_wind_traces", message)
            @test occursin(archive, message)
            @test tree_snapshot(root) == before
            @test staging_directories() == before_staging
            @test !ispath(joinpath(root, "Core scenarios"))
            @test !ispath(joinpath(root, "2026 ISP Model"))
            @test !ispath(joinpath(root, "Traces", "2026 ISP Solar traces"))
        end
    end

    @testset "symlinks and special destinations never replace" begin
        mktempdir() do parent
            real_root = joinpath(parent, "real-root")
            setup_valid_isp2026_root(real_root)
            linked_root = joinpath(parent, "linked-root")
            symlink_supported = try
                symlink(real_root, linked_root)
                true
            catch
                false
            end
            if symlink_supported
                message = preparation_error() do
                    ParseISP.prepare_isp2026_inputs(linked_root; overwrite = true)
                end
                @test occursin("isp26_inputs", message)
                @test occursin(abspath(linked_root), message)
                @test occursin("real directory", message)
                @test !ispath(joinpath(real_root, "Core scenarios"))
            else
                @test_skip "symlink creation is unavailable"
            end
        end

        mktempdir() do parent
            root = joinpath(parent, "root")
            setup_valid_isp2026_root(root)
            outside = joinpath(parent, "outside")
            mkpath(outside)
            link = joinpath(root, "Core scenarios")
            symlink_supported = try
                symlink(outside, link)
                true
            catch
                false
            end
            if symlink_supported
                message = preparation_error() do
                    ParseISP.prepare_isp2026_inputs(root; overwrite = true)
                end
                @test occursin("isp26_outlook", message)
                @test occursin(target_path(root, :isp26_outlook), message)
                @test occursin("symlink", message)
                @test isempty(readdir(outside))
            else
                @test_skip "symlink creation is unavailable"
            end
        end

        mktempdir() do parent
            root = joinpath(parent, "root")
            setup_valid_isp2026_root(root)
            destination = joinpath(root, "Core scenarios", "2026 ISP - Slower Growth - Core.xlsx")
            mkpath(dirname(destination))
            outside = joinpath(parent, "outside.xlsx")
            write(outside, "outside")
            symlink_supported = try
                symlink(outside, destination)
                true
            catch
                false
            end
            if symlink_supported
                message = preparation_error() do
                    ParseISP.prepare_isp2026_inputs(root; overwrite = true)
                end
                @test occursin("isp26_outlook", message)
                @test occursin(destination, message)
                @test occursin("symlink", message)
                @test read(outside, String) == "outside"
            else
                @test_skip "symlink creation is unavailable"
            end
        end

        if Sys.isunix()
            mktempdir() do root
                setup_valid_isp2026_root(root)
                destination = joinpath(root, "Core scenarios", "2026 ISP - Slower Growth - Core.xlsx")
                mkpath(dirname(destination))
                result = ccall(:mkfifo, Cint, (Cstring, Cuint), destination, 0o600)
                @test result == 0
                message = preparation_error() do
                    ParseISP.prepare_isp2026_inputs(root; overwrite = true)
                end
                @test occursin("isp26_outlook", message)
                @test occursin(destination, message)
                @test occursin("not a regular file", message)
                @test !isfile(destination) && !isdir(destination) && !islink(destination)
            end
        else
            @test_skip "special-file creation test is Unix-only"
        end
    end
end
