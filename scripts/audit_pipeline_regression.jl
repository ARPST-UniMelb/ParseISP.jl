#!/usr/bin/env julia
#
# Fast pipeline-value regression auditor.
#
# Implements exactly one subcommand, `verify-fixture`, which proves that a
# reduced fixture directory is value-preserving for the fixed
# `PIPELINE_REGRESSION_CASES` matrix: every case is run once against a
# complete local `pisp-downloads`-shaped directory and once against the
# candidate fixture directory, and the resulting 19 in-memory tables are
# compared exactly. Both roots are treated as read-only.
#
# `capture` and `check` (trusted-baseline capture/promotion) are not
# implemented.
#
# Usage:
#   julia --project=. scripts/audit_pipeline_regression.jl verify-fixture \
#       --full-data-root <path> --fixture-root <path> [--case <case-id>]

using ParseISP
using DataFrames

include(joinpath(@__DIR__, "..", "test", "support", "pipeline_regression.jl"))

"""
    parse_args(args)

Small manual parser for this script's flags. Returns a NamedTuple with
`subcommand`, `full_data_root`, `fixture_root`, `case_id`, and `help`.
Raises an `ErrorException` with a human-readable message on malformed input.
"""
function parse_args(args::Vector{String})
    subcommand = nothing
    full_data_root = nothing
    fixture_root = nothing
    case_id = nothing
    help = false

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "-h" || a == "--help"
            help = true
            i += 1
        elseif a == "verify-fixture"
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
        elseif a == "--case"
            i < length(args) || error("--case requires a value")
            case_id = args[i+1]
            i += 2
        else
            error("unrecognised argument: $a")
        end
    end

    return (subcommand=subcommand, full_data_root=full_data_root, fixture_root=fixture_root, case_id=case_id, help=help)
end

function usage()
    known_cases = join(("  - " * c.id for c in PIPELINE_REGRESSION_CASES), "\n")
    return """
    Usage:
      julia --project=. scripts/audit_pipeline_regression.jl verify-fixture --full-data-root <path> --fixture-root <path> [--case <case-id>]

    verify-fixture runs each case in PIPELINE_REGRESSION_CASES (or only the
    single case named by --case) once against --full-data-root and once
    against --fixture-root, then compares the 19 resulting in-memory tables
    exactly (isequal on every cell, including missing/NaN/signed-zero
    distinctions). Both roots are read-only; nothing is written to either.

    Known case ids:
    $known_cases

    Not implemented: `capture` and `check` (baseline capture/promotion).
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
                       "    full-data-root columns: $cols_a\n" *
                       "    fixture-root columns:   $cols_b")
    end

    if nrow(a) != nrow(b)
        return (false, "table `$name`: row count differs " *
                       "(full-data-root has $(nrow(a)) rows, fixture-root has $(nrow(b)) rows)")
    end

    for i in 1:nrow(a)
        for col in cols_a
            va = a[i, col]
            vb = b[i, col]
            if !isequal(va, vb)
                return (false, "table `$name`: mismatch at row $i, column `$col`\n" *
                               "    full-data-root value: $(repr(va)) ($(typeof(va)))\n" *
                               "    fixture-root value:   $(repr(vb)) ($(typeof(vb)))")
            end
        end
    end

    return (true, "")
end

"""
    compare_case_tables(tables_a, tables_b)

Compare two 19-table `NamedTuple`s (as returned by `pipeline_regression_tables`)
key-by-key, in order: (1) same keys present, (2) each table via
[`compare_table`](@ref). Returns `(true, "")` or `(false, message)` for the
first mismatching table.
"""
function compare_case_tables(tables_a::NamedTuple, tables_b::NamedTuple)
    keys_a = keys(tables_a)
    keys_b = keys(tables_b)
    if Set(keys_a) != Set(keys_b)
        return (false, "table keys differ: full-data-root has $keys_a, fixture-root has $keys_b")
    end

    for key in keys_a
        ok, msg = compare_table(String(key), tables_a[key], tables_b[key])
        ok || return (false, msg)
    end

    return (true, "")
end

"""
    run_case_isolated(case, download_root, original_cwd)

Run [`run_case`](@ref) for `case` against `download_root` inside a fresh
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

    if parsed.subcommand != "verify-fixture"
        println(stderr, "error: unknown subcommand `$(parsed.subcommand)`")
        println(stderr)
        println(stderr, usage())
        return 1
    end

    if parsed.full_data_root === nothing || parsed.fixture_root === nothing
        println(stderr, "error: --full-data-root and --fixture-root are both required")
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
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main(ARGS))
end
