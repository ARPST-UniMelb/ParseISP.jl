#!/usr/bin/env julia
#
# Fast pipeline-value regression auditor.
#
# Implements two subcommands:
#
#   verify-fixture  proves a reduced fixture directory is value-preserving for
#                   the fixed `PIPELINE_REGRESSION_CASES` matrix: every case is
#                   run once against a complete local `pisp-downloads`-shaped
#                   directory and once against the candidate fixture
#                   directory, and the resulting 19 in-memory tables are
#                   compared exactly. Both roots are treated as read-only.
#
#   check           runs the current candidate `ParseISP` (whatever this
#                   script's own `--project=` activated) against a fixture
#                   directory and compares its 19 in-memory tables against the
#                   committed trusted baseline (`test/data/isp2024/pisp-baselines/`
#                   by default). Never creates, updates, or promotes a
#                   baseline; purely read-only against fixture and baseline
#                   trees.
#
# `capture` (trusted-baseline capture) lives in
# scripts/capture_pipeline_regression_baseline.jl, not here.
#
# Usage:
#   julia --project=. scripts/audit_pipeline_regression.jl verify-fixture \
#       --full-data-root <path> --fixture-root <path> [--case <case-id>]
#   julia --project=. scripts/audit_pipeline_regression.jl check \
#       [--fixture-root <path>] [--baseline-root <path>] [--case <case-id>]

using ParseISP
using DataFrames
using Arrow
using SHA
using TOML

if !isdefined(@__MODULE__, :PipelineRegressionCase)
    include(joinpath(@__DIR__, "..", "test", "support", "pipeline_regression.jl"))
end

const DEFAULT_FIXTURE_ROOT = joinpath(@__DIR__, "..", "test", "data", "isp2024", "pisp-downloads")
const DEFAULT_BASELINE_ROOT = joinpath(@__DIR__, "..", "test", "data", "isp2024", "pisp-baselines")

"""
    parse_args(args)

Small manual parser for this script's flags. Returns a NamedTuple with
`subcommand`, `full_data_root`, `fixture_root`, `baseline_root`, `case_id`,
and `help`. Raises an `ErrorException` with a human-readable message on
malformed input.
"""
function parse_args(args::Vector{String})
    subcommand = nothing
    full_data_root = nothing
    fixture_root = nothing
    baseline_root = nothing
    case_id = nothing
    help = false

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "-h" || a == "--help"
            help = true
            i += 1
        elseif a == "verify-fixture" || a == "check"
            subcommand === nothing || error("subcommand already given (`$subcommand`); unexpected extra `$a`")
            subcommand = a
            i += 1
        elseif a == "--full-data-root"
            i < length(args) || error("--full-data-root requires a value")
            full_data_root = args[i+1]
            i += 2
        elseif a == "--fixture-root"
            i < length(args) || error("--fixture-root requires a value")
            fixture_root = args[i+1]
            i += 2
        elseif a == "--baseline-root"
            i < length(args) || error("--baseline-root requires a value")
            baseline_root = args[i+1]
            i += 2
        elseif a == "--case"
            i < length(args) || error("--case requires a value")
            case_id = args[i+1]
            i += 2
        else
            error("unrecognised argument: $a")
        end
    end

    return (subcommand=subcommand, full_data_root=full_data_root, fixture_root=fixture_root,
            baseline_root=baseline_root, case_id=case_id, help=help)
end

function usage()
    known_cases = join(("  - " * c.id for c in PIPELINE_REGRESSION_CASES), "\n")
    return """
    Usage:
      julia --project=. scripts/audit_pipeline_regression.jl verify-fixture --full-data-root <path> --fixture-root <path> [--case <case-id>]
      julia --project=. scripts/audit_pipeline_regression.jl check [--fixture-root <path>] [--baseline-root <path>] [--case <case-id>]

    verify-fixture runs each case in PIPELINE_REGRESSION_CASES (or only the
    single case named by --case) once against --full-data-root and once
    against --fixture-root, then compares the 19 resulting in-memory tables
    exactly (isequal on every cell, including missing/NaN/signed-zero
    distinctions). Both roots are read-only; nothing is written to either.

    check runs each selected case's *current* ParseISP candidate against
    --fixture-root (default: the committed test/data/isp2024/pisp-downloads/
    fixture) and compares the result against the committed baseline under
    --baseline-root (default: test/data/isp2024/pisp-baselines/). It verifies
    every baseline Arrow file's checksum first (failing clearly on an
    unresolved Git LFS pointer) and never creates, updates, or promotes a
    baseline.

    Known case ids:
    $known_cases

    Baseline capture lives in scripts/capture_pipeline_regression_baseline.jl.
    """
end

"""
    compare_table(name, a, b)

Compare two `DataFrame`s exactly: column names/order, row count, then every
cell with `isequal`. Returns `(true, "")` on success, or `(false, message)`
describing the first mismatch found, in row-major order.
"""
function compare_table(name::AbstractString, a::DataFrames.DataFrame, b::DataFrames.DataFrame)
    cols_a = names(a)
    cols_b = names(b)
    if cols_a != cols_b
        return (false, "table `$name`: column names/order differ\n" *
                       "    first columns:  $cols_a\n" *
                       "    second columns: $cols_b")
    end

    if nrow(a) != nrow(b)
        return (false, "table `$name`: row count differs " *
                       "(first has $(nrow(a)) rows, second has $(nrow(b)) rows)")
    end

    for i in 1:nrow(a)
        for col in cols_a
            va = a[i, col]
            vb = b[i, col]
            if !isequal(va, vb)
                return (false, "table `$name`: mismatch at row $i, column `$col`\n" *
                               "    first value:  $(repr(va)) ($(typeof(va)))\n" *
                               "    second value: $(repr(vb)) ($(typeof(vb)))")
            end
        end
    end

    return (true, "")
end

"""
    compare_case_tables(tables_a, tables_b)

Compare two collections of named tables (each anything supporting `keys`,
`pairs`, and key-indexing — a `NamedTuple` or a `Dict{String,DataFrame}`)
key-by-key, in order: (1) same keys present, (2) each table via
[`compare_table`](@ref). Returns `(true, "")` or `(false, message)` for the
first mismatching table.
"""
function compare_case_tables(tables_a, tables_b)
    keys_a = Set(String(k) for k in keys(tables_a))
    keys_b = Set(String(k) for k in keys(tables_b))
    if keys_a != keys_b
        return (false, "table keys differ: first has $keys_a, second has $keys_b")
    end

    for (k, v) in pairs(tables_a)
        key = String(k)
        other = tables_b isa AbstractDict ? tables_b[key] : tables_b[Symbol(key)]
        ok, msg = compare_table(key, v, other)
        ok || return (false, msg)
    end

    return (true, "")
end

"""
    run_case_isolated(case, download_root, original_cwd)

Run [`run_case`](@ref) for `case` against `download_root` (using the
statically-imported `ParseISP` — the current candidate) inside a fresh
`mktempdir()`, restoring the working directory afterwards regardless of
success or failure (`cd(f, tmp)` guarantees this). Afterwards, verifies that
no stray file or directory was left behind in `original_cwd` (the process's
working directory at script start) by comparing `readdir(original_cwd)`
before and after; any stray entries are reported as a warning but do not by
themselves fail the case (the comparison in [`compare_case_tables`](@ref) is
the correctness oracle).
"""
function run_case_isolated(case::PipelineRegressionCase, download_root::AbstractString, original_cwd::AbstractString)
    before = Set(readdir(original_cwd))

    result = cd(mktempdir()) do
        run_case(ParseISP, case, download_root)
    end

    after = Set(readdir(original_cwd))
    stray = setdiff(after, before)
    if !isempty(stray)
        println(stderr, "  warning: stray entries appeared in $original_cwd while running case `$(case.id)` against $download_root: ", join(sort(collect(stray)), ", "))
    end

    return result
end

"""
    run_verify_fixture(full_data_root, fixture_root, case_id)

Implements the `verify-fixture` subcommand. Returns `true` if every selected
case passed, `false` otherwise (including the case where `case_id` does not
name a known case).
"""
function run_verify_fixture(full_data_root::AbstractString, fixture_root::AbstractString, case_id::Union{Nothing,AbstractString})
    if case_id === nothing
        cases = PIPELINE_REGRESSION_CASES
    else
        cases = filter(c -> c.id == case_id, PIPELINE_REGRESSION_CASES)
        if isempty(cases)
            known = join((c.id for c in PIPELINE_REGRESSION_CASES), ", ")
            println(stderr, "error: unknown case id `$case_id`. Known cases: $known")
            return false
        end
    end

    original_cwd = pwd()
    n_total = length(cases)
    n_pass = 0

    for (i, case) in enumerate(cases)
        println("[$i/$n_total] case `$(case.id)` — $(case.purpose)")

        println("  running against --full-data-root ($full_data_root) ...")
        tables_full = run_case_isolated(case, full_data_root, original_cwd)

        println("  running against --fixture-root ($fixture_root) ...")
        tables_fixture = run_case_isolated(case, fixture_root, original_cwd)

        ok, msg = compare_case_tables(tables_full, tables_fixture)
        if ok
            println("  PASS")
            n_pass += 1
        else
            println("  FAIL")
            for line in split(msg, "\n")
                println("    ", line)
            end
        end
    end

    println()
    println("summary: $n_pass/$n_total case(s) passed")

    return n_pass == n_total
end

"""
    is_lfs_pointer(path)

Return `true` if the file at `path` looks like an unresolved Git LFS pointer
(a small text stub starting with the LFS spec header) rather than materialised
binary content.
"""
function is_lfs_pointer(path::AbstractString)
    open(path, "r") do io
        line = readline(io)
        return startswith(line, "version https://git-lfs.github.com/spec")
    end
end

"""
    sha256_file(path)

Return the lowercase hex SHA-256 digest of the file at `path`.
"""
sha256_file(path::AbstractString) = bytes2hex(open(sha256, path))

"""
    load_baseline_case(case_id, baseline_root)

Read `baseline_root/<case_id>/baseline.toml` plus its 19 Arrow tables. Fails
clearly (via `error`) on a missing baseline directory, a missing or corrupt
table file, an unresolved Git LFS pointer, or a checksum mismatch against the
recorded `sha256`, before ever comparing values. Returns
`(authority::Dict, tables::Dict{String,DataFrames.DataFrame})`, with every
Arrow-backed column materialised into a plain `Vector` so downstream
diagnostics never report a storage-wrapper type as the expected Julia type.
"""
function load_baseline_case(case_id::AbstractString, baseline_root::AbstractString)
    case_dir = joinpath(baseline_root, case_id)
    baseline_path = joinpath(case_dir, "baseline.toml")
    isfile(baseline_path) || error("missing baseline.toml for case `$case_id` at $baseline_path")

    manifest = TOML.parsefile(baseline_path)
    haskey(manifest, "tables") || error("baseline.toml for case `$case_id` has no [tables] section")
    haskey(manifest, "authority") || error("baseline.toml for case `$case_id` has no [authority] section")

    tables = Dict{String,DataFrames.DataFrame}()
    for (name, record) in manifest["tables"]
        arrow_path = joinpath(case_dir, "tables", "$name.arrow")
        isfile(arrow_path) || error("missing baseline table file for case `$case_id`, table `$name`: $arrow_path")

        if is_lfs_pointer(arrow_path)
            error("baseline table `$name` for case `$case_id` is an unresolved Git LFS pointer, not real content: " *
                  "$arrow_path — run `git lfs pull` and retry.")
        end

        actual_sha = sha256_file(arrow_path)
        expected_sha = record["sha256"]
        actual_sha == expected_sha || error(
            "baseline table `$name` for case `$case_id` failed checksum verification " *
            "(possible corruption or unpulled LFS content): expected sha256 $expected_sha, got $actual_sha at $arrow_path"
        )

        df = DataFrames.DataFrame(Arrow.Table(arrow_path))
        tables[name] = DataFrames.mapcols(collect, df)
    end

    return manifest["authority"], tables
end

"""
    run_check(fixture_root, baseline_root, case_id)

Implements the `check` subcommand: for every selected case, loads its
committed baseline (verifying every Arrow file's checksum and rejecting
unresolved LFS pointers first), runs the current candidate `ParseISP`
against `fixture_root`, and compares the 19 resulting tables against the
loaded baseline exactly. Never writes, updates, or promotes a baseline.
Returns `true` if every selected case passed.
"""
function run_check(fixture_root::AbstractString, baseline_root::AbstractString, case_id::Union{Nothing,AbstractString})
    if case_id === nothing
        cases = PIPELINE_REGRESSION_CASES
    else
        cases = filter(c -> c.id == case_id, PIPELINE_REGRESSION_CASES)
        if isempty(cases)
            known = join((c.id for c in PIPELINE_REGRESSION_CASES), ", ")
            println(stderr, "error: unknown case id `$case_id`. Known cases: $known")
            return false
        end
    end

    candidate_commit = "unknown"
    try
        candidate_commit = strip(read(`git -C $(Base.pkgdir(ParseISP)) rev-parse HEAD`, String))
    catch
    end
    println("checking candidate ParseISP at commit $candidate_commit against $(length(cases)) case(s)")
    println("  fixture root:  $fixture_root")
    println("  baseline root: $baseline_root")

    original_cwd = pwd()
    n_total = length(cases)
    n_pass = 0

    for (i, case) in enumerate(cases)
        println("[$i/$n_total] case `$(case.id)` — $(case.purpose)")

        local authority, baseline_tables
        try
            authority, baseline_tables = load_baseline_case(case.id, baseline_root)
        catch e
            println("  FAIL: could not load baseline: ", sprint(showerror, e))
            continue
        end

        tag = get(authority, "tag", "")
        println("  baseline authority: $(authority["package"]) at $(authority["commit"])" *
                (isempty(tag) ? "" : " (tag $tag)"))

        candidate_tables = run_case_isolated(case, fixture_root, original_cwd)

        ok, msg = compare_case_tables(candidate_tables, baseline_tables)
        if ok
            println("  PASS")
            n_pass += 1
        else
            println("  FAIL")
            for line in split(msg, "\n")
                println("    ", line)
            end
        end
    end

    println()
    println("summary: $n_pass/$n_total case(s) passed")

    return n_pass == n_total
end

function main(args::Vector{String}=ARGS)
    local parsed
    try
        parsed = parse_args(args)
    catch e
        println(stderr, "error: ", sprint(showerror, e))
        println(stderr)
        println(stderr, usage())
        return 1
    end

    if parsed.help
        println(usage())
        return 0
    end

    if parsed.subcommand === nothing
        println(stderr, "error: missing subcommand")
        println(stderr)
        println(stderr, usage())
        return 1
    end

    if parsed.subcommand == "verify-fixture"
        if parsed.full_data_root === nothing || parsed.fixture_root === nothing
            println(stderr, "error: --full-data-root and --fixture-root are both required for verify-fixture")
            println(stderr)
            println(stderr, usage())
            return 1
        end

        full_data_root = abspath(parsed.full_data_root)
        fixture_root = abspath(parsed.fixture_root)

        isdir(full_data_root) || (println(stderr, "error: --full-data-root does not exist or is not a directory: $full_data_root"); return 1)
        isdir(fixture_root) || (println(stderr, "error: --fixture-root does not exist or is not a directory: $fixture_root"); return 1)

        full_data_root = realpath(full_data_root)
        fixture_root = realpath(fixture_root)

        ok = run_verify_fixture(full_data_root, fixture_root, parsed.case_id)
        return ok ? 0 : 1
    elseif parsed.subcommand == "check"
        fixture_root = abspath(parsed.fixture_root === nothing ? DEFAULT_FIXTURE_ROOT : parsed.fixture_root)
        baseline_root = abspath(parsed.baseline_root === nothing ? DEFAULT_BASELINE_ROOT : parsed.baseline_root)

        isdir(fixture_root) || (println(stderr, "error: fixture root does not exist or is not a directory: $fixture_root"); return 1)
        isdir(baseline_root) || (println(stderr, "error: baseline root does not exist or is not a directory: $baseline_root"); return 1)

        fixture_root = realpath(fixture_root)
        baseline_root = realpath(baseline_root)

        ok = run_check(fixture_root, baseline_root, parsed.case_id)
        return ok ? 0 : 1
    else
        println(stderr, "error: unknown subcommand `$(parsed.subcommand)`")
        println(stderr)
        println(stderr, usage())
        return 1
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main(ARGS))
end
