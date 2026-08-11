#!/usr/bin/env julia
#
# Fast pipeline-value regression fixture builder.
#
# Builds a small, reduced fixture tree out of the maintainer's complete local
# ISP 2024 data collection (production-relative shape, mirroring a
# `pisp-downloads`-style source root), suitable for committing to git (via Git
# LFS) so that routine tests never need the full ~66GB collection.
#
# This script only builds and checks the fixture tree; it does not implement
# Git LFS wiring, `.gitattributes`/`.gitignore` changes, or the
# `verify-fixture`/`capture` regression-comparison operations (see
# `scripts/audit_pipeline_regression.jl` for those).
#
# Usage:
#   julia --project=. scripts/build_pipeline_regression_data_2024.jl build --source-root <path> --output-root <path>
#   julia --project=. scripts/build_pipeline_regression_data_2024.jl check --source-root <path> --fixture-root <path>

using CSV
using DataFrames
using OrderedCollections
using SHA
using TOML

# ---------------------------------------------------------------------------
# Fixture contents specification
# ---------------------------------------------------------------------------

const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))

const ROOT_WORKBOOKS = [
    "2019-input-and-assumptions-workbook-v1-3-dec-19.xlsx",
    "2023-iasr-ev-workbook.xlsx",
    "2024-isp-inputs-and-assumptions-workbook.xlsx",
]

const AUXILIARY_WORKBOOKS = [
    "CapacityOutlook2024_Condensed.xlsx",
    "StorageCapacityOutlook_2024_ISP.xlsx",
    "StorageEnergyOutlook_2024_ISP.xlsx",
    "2024 ISP - Progressive Change - Core_REZCAP.xlsx",
    "2024 ISP - Step Change - Core_REZCAP.xlsx",
    "2024 ISP - Green Energy Exports - Core_REZCAP.xlsx",
]

const TRACE_KINDS = ("solar", "wind")
const TRACE_REFERENCE_YEARS = (4006, 2011)

# (Year, Month, Day) tuples every solar/wind/demand/hydro-inflow daily trace
# must retain. Covers the internal financial-year/weather-year splice
# (2025-06-30/07-01), the September-October seasonal boundary, and the
# dstart <= 2024-07-01 branch.
const REQUIRED_DATES = [(2024, 7, 1), (2024, 9, 30), (2024, 10, 1), (2025, 6, 30), (2025, 7, 1)]

# Years every hydro annual-energy-limit file must retain (covers the two
# calendar years spanned by REQUIRED_DATES).
const REQUIRED_YEARS = (2024, 2025)

const SCENARIOS = ["Progressive Change", "Step Change", "Green Energy Exports"]

const DEMAND_FILE_KINDS = ("PV_TOT", "OPSO_MODELLING_PVLITE")

# (refyear, poe, scenario) combinations selected by the fixed pipeline
# regression case matrix (test/support/pipeline_regression.jl).
const DEMAND_COMBOS = [
    (refyear=4006, poe=10, scenario="Progressive Change"),
    (refyear=4006, poe=10, scenario="Step Change"),
    (refyear=4006, poe=10, scenario="Green Energy Exports"),
    (refyear=4006, poe=50, scenario="Step Change"),
    (refyear=2011, poe=10, scenario="Step Change"),
]

const HYDRO_SCENARIO_DIRS = [
    "2024 ISP Progressive Change",
    "2024 ISP Step Change",
    "2024 ISP Green Energy Exports",
]

const MANIFEST_FILENAME = "fixture-manifest.toml"

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

"""
    canonical_path(path)

Canonicalize `path` for containment checks: resolves symlinks via `realpath`
for the longest existing prefix, then reattaches any remaining (not yet
created) trailing components with `abspath`/`joinpath`. Works for paths that
do not exist yet (e.g. a `--output-root` still to be created).
"""
function canonical_path(path::AbstractString)
    path = abspath(path)
    ispath(path) && return realpath(path)
    parent = dirname(path)
    remainder = basename(path)
    # Walk up until we find an existing ancestor, then rebuild.
    trail = String[]
    while !isempty(parent) && !ispath(parent) && parent != dirname(parent)
        pushfirst!(trail, basename(parent))
        parent = dirname(parent)
    end
    if ispath(parent)
        resolved = realpath(parent)
        for part in trail
            resolved = joinpath(resolved, part)
        end
        return joinpath(resolved, remainder)
    end
    return path
end

# ---------------------------------------------------------------------------
# Hashing and manifest records
# ---------------------------------------------------------------------------

sha256_file(path::AbstractString) = bytes2hex(sha256(read(path)))

function new_record(path::AbstractString, mode::AbstractString, source_sha::AbstractString,
                     fixture_sha::AbstractString, size_bytes::Integer;
                     source_rows::Union{Nothing,Integer}=nothing,
                     fixture_rows::Union{Nothing,Integer}=nothing)
    record = OrderedDict{String,Any}(
        "path" => path,
        "mode" => mode,
        "source_sha256" => source_sha,
        "fixture_sha256" => fixture_sha,
        "size_bytes" => size_bytes,
    )
    if source_rows !== nothing
        record["source_rows"] = source_rows
        record["fixture_rows"] = fixture_rows
    end
    return record
end

"""
    copy_whole!(source_root, output_root, relpath)

Copy `relpath` byte-for-byte from `source_root` to `output_root` and return
its manifest record.
"""
function copy_whole!(source_root::AbstractString, output_root::AbstractString, relpath::AbstractString)
    src = joinpath(source_root, relpath)
    isfile(src) || error("expected fixture input file missing from source root: $relpath (looked at $src)")
    dst = joinpath(output_root, relpath)
    mkpath(dirname(dst))
    cp(src, dst)
    sha = sha256_file(dst)
    size_bytes = filesize(dst)
    println("  copied   $relpath ($(size_bytes) bytes)")
    return new_record(relpath, "copy", sha, sha, size_bytes)
end

"""
    crop_by_date!(source_root, output_root, relpath)

Read the `Year,Month,Day,...` CSV at `relpath`, keep only the rows whose
`(Year, Month, Day)` matches one of [`REQUIRED_DATES`](@ref), write the
cropped CSV to `output_root`, and return its manifest record. Fails loudly
(naming the file and the missing date) if any required date is absent from
the source file.
"""
function crop_by_date!(source_root::AbstractString, output_root::AbstractString, relpath::AbstractString)
    src = joinpath(source_root, relpath)
    isfile(src) || error("expected fixture input file missing from source root: $relpath (looked at $src)")
    source_sha = sha256_file(src)

    df = CSV.read(src, DataFrame)
    all(hasproperty(df, c) for c in (:Year, :Month, :Day)) ||
        error("file is missing one of the Year/Month/Day columns: $relpath")

    row_keys = collect(zip(df.Year, df.Month, df.Day))
    key_set = Set(row_keys)
    missing_dates = [d for d in REQUIRED_DATES if d ∉ key_set]
    isempty(missing_dates) || error(
        "cannot build fixture: required date(s) $(missing_dates) missing from source file $relpath",
    )

    required_set = Set(REQUIRED_DATES)
    cropped = df[[k in required_set for k in row_keys], :]

    dst = joinpath(output_root, relpath)
    mkpath(dirname(dst))
    CSV.write(dst, cropped)
    fixture_sha = sha256_file(dst)
    size_bytes = filesize(dst)
    println("  cropped  $relpath ($(nrow(df)) -> $(nrow(cropped)) rows)")
    return new_record(relpath, "crop", source_sha, fixture_sha, size_bytes;
                       source_rows=nrow(df), fixture_rows=nrow(cropped))
end

"""
    crop_by_year!(source_root, output_root, relpath)

Read the `Year,...` annual CSV at `relpath`, keep only the rows whose `Year`
is one of [`REQUIRED_YEARS`](@ref), write the cropped CSV to `output_root`,
and return its manifest record. Fails loudly if any required year is absent.
"""
function crop_by_year!(source_root::AbstractString, output_root::AbstractString, relpath::AbstractString)
    src = joinpath(source_root, relpath)
    isfile(src) || error("expected fixture input file missing from source root: $relpath (looked at $src)")
    source_sha = sha256_file(src)

    df = CSV.read(src, DataFrame)
    hasproperty(df, :Year) || error("file is missing the Year column: $relpath")

    present_years = Set(df.Year)
    missing_years = [y for y in REQUIRED_YEARS if y ∉ present_years]
    isempty(missing_years) || error(
        "cannot build fixture: required year(s) $(missing_years) missing from source file $relpath",
    )

    required_set = Set(REQUIRED_YEARS)
    cropped = df[[y in required_set for y in df.Year], :]

    dst = joinpath(output_root, relpath)
    mkpath(dirname(dst))
    CSV.write(dst, cropped)
    fixture_sha = sha256_file(dst)
    size_bytes = filesize(dst)
    println("  cropped  $relpath ($(nrow(df)) -> $(nrow(cropped)) rows)")
    return new_record(relpath, "crop", source_sha, fixture_sha, size_bytes;
                       source_rows=nrow(df), fixture_rows=nrow(cropped))
end

# ---------------------------------------------------------------------------
# Demand subregion / scenario-code derivation (never hardcoded)
# ---------------------------------------------------------------------------

"""
    derive_demand_subregions(source_root)

List `<source_root>/Traces`, keep entries named `demand_<SUBREGION>_<scenario>`
for a known scenario in [`SCENARIOS`](@ref), and return the sorted, de-duplicated
set of `<SUBREGION>` tokens. Errors if the result is not exactly 12 subregions.
"""
function derive_demand_subregions(source_root::AbstractString)
    traces_dir = joinpath(source_root, "Traces")
    isdir(traces_dir) || error("expected Traces directory missing under source root: $traces_dir")

    subregions = Set{String}()
    for entry in readdir(traces_dir)
        startswith(entry, "demand_") || continue
        for scenario in SCENARIOS
            suffix = "_" * scenario
            if endswith(entry, suffix)
                subregion = entry[(length("demand_") + 1):(end - length(suffix))]
                isempty(subregion) && continue
                push!(subregions, subregion)
            end
        end
    end
    result = sort!(collect(subregions))
    length(result) == 12 || error(
        "expected exactly 12 demand subregions under $traces_dir, derived $(length(result)): $result",
    )
    return result
end

"""
    derive_scenario_code(source_root, subregion, scenario)

Derive the upper-snake-case scenario token actually used in real demand
filenames for `scenario`, by scanning filenames in
`demand_<subregion>_<scenario>/` rather than guessing a tokenization.
"""
function derive_scenario_code(source_root::AbstractString, subregion::AbstractString, scenario::AbstractString)
    dir = joinpath(source_root, "Traces", "demand_$(subregion)_$(scenario)")
    isdir(dir) || error("missing demand directory needed to derive its scenario code token: $dir")

    prefix = "$(subregion)_RefYear_"
    pattern = r"^(\d+)_(.+)_POE(\d+)_(PV_TOT|OPSO_MODELLING_PVLITE|OPSO_MODELLING)\.csv$"
    for fname in sort(readdir(dir))
        startswith(fname, prefix) || continue
        rest = fname[(length(prefix) + 1):end]
        m = match(pattern, rest)
        m === nothing && continue
        return String(m.captures[2])
    end
    error("could not derive a scenario code token from any filename in $dir")
end

"""
    derive_scenario_codes(source_root, subregions)

Return a `Dict` mapping each entry of [`SCENARIOS`](@ref) to its real
filename token, derived from the first subregion's demand directories.
"""
function derive_scenario_codes(source_root::AbstractString, subregions::Vector{String})
    probe_subregion = first(subregions)
    return Dict(scenario => derive_scenario_code(source_root, probe_subregion, scenario) for scenario in SCENARIOS)
end

# ---------------------------------------------------------------------------
# Fixture assembly
# ---------------------------------------------------------------------------

function bump_group!(groups::OrderedDict{String,Tuple{Int,Int}}, group::AbstractString, record)
    files, bytes = get(groups, group, (0, 0))
    groups[group] = (files + 1, bytes + Int(record["size_bytes"]))
    return nothing
end

"""
    build_fixture!(source_root, output_root)

Populate `output_root` with the complete reduced fixture tree read from
`source_root`. Returns `(records, groups)`: `records` is the sorted vector of
manifest entries (one per fixture file), `groups` is an `OrderedDict` from
group name to `(file_count, total_bytes)` for the end-of-run summary.
"""
function build_fixture!(source_root::AbstractString, output_root::AbstractString)
    records = Vector{OrderedDict{String,Any}}()
    groups = OrderedDict{String,Tuple{Int,Int}}(
        "root_workbooks" => (0, 0), "auxiliary" => (0, 0),
        "solar" => (0, 0), "wind" => (0, 0), "demand" => (0, 0), "hydro" => (0, 0),
    )

    println("== root workbooks ==")
    for name in ROOT_WORKBOOKS
        rec = copy_whole!(source_root, output_root, name)
        push!(records, rec)
        bump_group!(groups, "root_workbooks", rec)
    end

    println("== Auxiliary ==")
    for name in AUXILIARY_WORKBOOKS
        relpath = "Auxiliary/" * name
        rec = copy_whole!(source_root, output_root, relpath)
        push!(records, rec)
        bump_group!(groups, "auxiliary", rec)
    end

    println("== solar / wind traces ==")
    for kind in TRACE_KINDS, refyear in TRACE_REFERENCE_YEARS
        dir_relpath = "Traces/$(kind)_$(refyear)"
        srcdir = joinpath(source_root, dir_relpath)
        isdir(srcdir) || error("expected trace directory missing: $srcdir")
        for fname in sort(readdir(srcdir))
            relpath = dir_relpath * "/" * fname
            rec = crop_by_date!(source_root, output_root, relpath)
            push!(records, rec)
            bump_group!(groups, kind, rec)
        end
    end

    println("== demand traces ==")
    subregions = derive_demand_subregions(source_root)
    println("  derived $(length(subregions)) demand subregions: $(join(subregions, ", "))")
    scenario_codes = derive_scenario_codes(source_root, subregions)
    for scenario in SCENARIOS
        println("  derived scenario code for \"$scenario\": $(scenario_codes[scenario])")
    end
    for subregion in subregions, combo in DEMAND_COMBOS
        code = scenario_codes[combo.scenario]
        dir_relpath = "Traces/demand_$(subregion)_$(combo.scenario)"
        for kind in DEMAND_FILE_KINDS
            fname = "$(subregion)_RefYear_$(combo.refyear)_$(code)_POE$(combo.poe)_$(kind).csv"
            relpath = dir_relpath * "/" * fname
            rec = crop_by_date!(source_root, output_root, relpath)
            push!(records, rec)
            bump_group!(groups, "demand", rec)
        end
    end

    println("== hydro ==")
    for scenario_dir in HYDRO_SCENARIO_DIRS
        dir_relpath = "2024 ISP Model/$(scenario_dir)/Traces/hydro"
        srcdir = joinpath(source_root, dir_relpath)
        isdir(srcdir) || error("expected hydro trace directory missing: $srcdir")
        for fname in sort(readdir(srcdir))
            relpath = dir_relpath * "/" * fname
            rec = if startswith(fname, "MonthlyNaturalInflow_")
                crop_by_date!(source_root, output_root, relpath)
            elseif startswith(fname, "MaxEnergyYear_")
                crop_by_year!(source_root, output_root, relpath)
            else
                error("unexpected hydro file (neither MonthlyNaturalInflow_* nor MaxEnergyYear_*): $relpath")
            end
            push!(records, rec)
            bump_group!(groups, "hydro", rec)
        end
    end

    sort!(records; by=r -> r["path"])
    return records, groups
end

function write_manifest(manifest_path::AbstractString, records::Vector{OrderedDict{String,Any}})
    manifest = OrderedDict{String,Any}("schema_version" => 1, "files" => records)
    open(manifest_path, "w") do io
        TOML.print(io, manifest)
    end
    return nothing
end

function print_summary(records::Vector{OrderedDict{String,Any}}, groups::OrderedDict{String,Tuple{Int,Int}})
    total_files = length(records)
    total_bytes = sum(Int(r["size_bytes"]) for r in records; init=0)
    println()
    println("fixture summary:")
    for (group, (files, bytes)) in groups
        println("  $group: $files file(s), $bytes byte(s)")
    end
    println("  TOTAL: $total_files file(s), $total_bytes byte(s)")
    return nothing
end

# ---------------------------------------------------------------------------
# build / check entry points
# ---------------------------------------------------------------------------

function run_build(source_root_raw::AbstractString, output_root_raw::AbstractString)
    source_root = canonical_path(source_root_raw)
    isdir(source_root) || error("--source-root does not exist or is not a directory: $source_root")

    output_root = canonical_path(output_root_raw)

    if ispath(output_root)
        isdir(output_root) || error("--output-root exists and is not a directory: $output_root")
    else
        mkpath(output_root)
    end

    println("building fixture from $source_root into $output_root")
    records, groups = build_fixture!(source_root, output_root)
    write_manifest(joinpath(output_root, MANIFEST_FILENAME), records)
    print_summary(records, groups)
    return true
end

"""
    directory_snapshot(root)

Return a `Dict` mapping every relative file path under `root` (using `/`
separators) to its raw bytes, for byte-for-byte comparison.
"""
function directory_snapshot(root::AbstractString)
    files = Dict{String,Vector{UInt8}}()
    for (dirpath, _, filenames) in walkdir(root)
        for fname in filenames
            abs_file = joinpath(dirpath, fname)
            rel = relpath(abs_file, root)
            rel = replace(rel, Base.Filesystem.path_separator => "/")
            files[rel] = read(abs_file)
        end
    end
    return files
end

function run_check(source_root_raw::AbstractString, fixture_root_raw::AbstractString)
    source_root = canonical_path(source_root_raw)
    isdir(source_root) || error("--source-root does not exist or is not a directory: $source_root")

    fixture_root = canonical_path(fixture_root_raw)
    isdir(fixture_root) || error("--fixture-root does not exist or is not a directory: $fixture_root")

    tmp = mktempdir()
    println("rebuilding fixture from $source_root into fresh temp dir $tmp")
    records, _ = build_fixture!(source_root, tmp)
    write_manifest(joinpath(tmp, MANIFEST_FILENAME), records)

    println()
    println("comparing rebuilt fixture against --fixture-root ($fixture_root)")
    expected = directory_snapshot(tmp)
    actual = directory_snapshot(fixture_root)

    mismatches = String[]
    for path in sort(collect(union(keys(expected), keys(actual))))
        if !haskey(actual, path)
            push!(mismatches, "missing from --fixture-root: $path")
        elseif !haskey(expected, path)
            push!(mismatches, "unexpected extra file in --fixture-root: $path")
        elseif expected[path] != actual[path]
            push!(mismatches, "content differs: $path")
        end
    end

    if isempty(mismatches)
        println("PASS: $(length(expected)) file(s) match byte-for-byte (including $MANIFEST_FILENAME)")
        return true
    else
        println("FAIL: $(length(mismatches)) mismatch(es)")
        for msg in mismatches
            println("  ", msg)
        end
        return false
    end
end

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

function usage()
    return """
    Usage:
      julia --project=. scripts/build_pipeline_regression_data_2024.jl build --source-root <path> --output-root <path>
      julia --project=. scripts/build_pipeline_regression_data_2024.jl check --source-root <path> --fixture-root <path>

    build populates --output-root (created if missing) with the reduced
    `fast` pipeline-regression fixture tree read from --source-root (a
    complete, `pisp-downloads`-shaped local ISP 2024 data collection), plus a
    deterministic $MANIFEST_FILENAME at its root.

    check is read-only: it rebuilds the fixture into a fresh temporary
    directory from --source-root and diffs every file (plus the manifest)
    byte-for-byte against --fixture-root, printing PASS/FAIL and exiting
    nonzero on any mismatch. It never writes into --fixture-root.
    """
end

function parse_kv_args(args::Vector{String})
    opts = Dict{String,String}()
    i = 1
    while i <= length(args)
        a = args[i]
        startswith(a, "--") || error("expected an --option, got `$a`")
        key = a[3:end]
        i == length(args) && error("missing value for --$key")
        opts[key] = args[i + 1]
        i += 2
    end
    return opts
end

function main(args::Vector{String}=ARGS)
    if isempty(args) || args[1] in ("-h", "--help")
        println(usage())
        return isempty(args) ? 1 : 0
    end

    mode = args[1]
    mode in ("build", "check") || (println(stderr, "error: unknown mode `$mode` (expected `build` or `check`)\n");
                                    println(stderr, usage()); return 1)

    local opts
    try
        opts = parse_kv_args(args[2:end])
    catch e
        println(stderr, "error: ", sprint(showerror, e), "\n")
        println(stderr, usage())
        return 1
    end

    try
        if mode == "build"
            haskey(opts, "source-root") && haskey(opts, "output-root") ||
                error("build requires --source-root and --output-root")
            run_build(opts["source-root"], opts["output-root"])
            return 0
        else
            haskey(opts, "source-root") && haskey(opts, "fixture-root") ||
                error("check requires --source-root and --fixture-root")
            ok = run_check(opts["source-root"], opts["fixture-root"])
            return ok ? 0 : 1
        end
    catch e
        println(stderr, "error: ", sprint(showerror, e))
        return 1
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main(ARGS))
end
