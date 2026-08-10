#!/usr/bin/env julia
#
# Fast pipeline-value regression baseline capturer.
#
# Implements exactly one subcommand, `capture`, which runs the fixed
# `PIPELINE_REGRESSION_CASES` matrix against a `pisp-downloads`-shaped
# fixture directory using whichever package the caller's `--project=` flag
# has active, and writes each case's 19 tables to Arrow files plus a
# `baseline.toml` recording that package's git commit/tag and per-table
# shape/hash. Writes only to `--output-root`; promotion into a committed
# baseline tree is a separate, explicit step (see `scripts/README.md`).
#
# Usage:
#   julia --project=<target> scripts/capture_pipeline_regression_baseline.jl capture \
#       --fixture-root <path> --output-root <path> [--case <case-id>]

using Pkg
using Dates
using Arrow
using SHA
using TOML

include(joinpath(@__DIR__, "..", "test", "support", "pipeline_regression.jl"))

"""
    parse_args(args)

Small manual parser for this script's flags. Returns a NamedTuple with
`subcommand`, `fixture_root`, `output_root`, `case_id`, and `help`. Raises an
`ErrorException` with a human-readable message on malformed input.
"""
function parse_args(args::Vector{String})
    subcommand = nothing
    fixture_root = nothing
    output_root = nothing
    case_id = nothing
    help = false

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "-h" || a == "--help"
            help = true
            i += 1
        elseif a == "capture"
            subcommand === nothing || error("subcommand already given (`$subcommand`); unexpected extra `$a`")
            subcommand = a
            i += 1
        elseif a == "--fixture-root"
            i < length(args) || error("--fixture-root requires a value")
            fixture_root = args[i+1]
            i += 2
        elseif a == "--output-root"
            i < length(args) || error("--output-root requires a value")
            output_root = args[i+1]
            i += 2
        elseif a == "--case"
            i < length(args) || error("--case requires a value")
            case_id = args[i+1]
            i += 2
        else
            error("unrecognised argument: $a")
        end
    end

    return (subcommand=subcommand, fixture_root=fixture_root, output_root=output_root, case_id=case_id, help=help)
end

function usage()
    known_cases = join(("  - " * c.id for c in PIPELINE_REGRESSION_CASES), "\n")
    return """
    Usage:
      julia --project=<target> scripts/capture_pipeline_regression_baseline.jl capture --fixture-root <path> --output-root <path> [--case <case-id>]

    The active `--project=<target>` determines which package is captured
    (its `Project.toml` name is loaded and used for every case). Point it at
    a plain checkout to capture the current candidate, or at a separate
    worktree pinned to a specific commit/tag to capture a trusted authority.

    capture runs each case in PIPELINE_REGRESSION_CASES (or only the single
    case named by --case) against --fixture-root, then writes
    --output-root/<case-id>/baseline.toml plus
    --output-root/<case-id>/tables/<table>.arrow for each of the 19 tables.
    --output-root is created if missing; existing files under it for the
    same case id are overwritten.

    Known case ids:
    $known_cases
    """
end

"""
    target_module()

Return the `Module` for whichever package is active in the current Julia
project, identified by that project's `Project.toml` `name` field. Lets this
script capture from any checkout (current candidate or a trusted worktree)
purely by which `--project=` the caller activated, with no source change.
"""
function target_module()
    name = Pkg.project().name
    name === nothing && error("the active project has no `name` field in its Project.toml")
    return Base.require(Main, Symbol(name))
end

"""
    sha256_file(path)

Return the lowercase hex SHA-256 digest of the file at `path`.
"""
sha256_file(path::AbstractString) = bytes2hex(open(sha256, path))

"""
    target_authority(mod)

Best-effort git provenance for the source directory of `mod` (the package
loaded by [`target_module`](@ref)): commit SHA, an exact tag if `HEAD` has
one, and dirty-worktree status. Falls back to `"unknown"`/`missing` fields
if the source directory is not inside a git repository or `git` is
unavailable, rather than failing the capture.
"""
function target_authority(mod::Module)
    src_dir = Base.pkgdir(mod)
    commit = "unknown"
    tag = nothing
    dirty = nothing
    try
        commit = strip(read(`git -C $src_dir rev-parse HEAD`, String))
        tag_result = read(`git -C $src_dir describe --tags --exact-match`, String)
        tag = strip(tag_result)
    catch
        # not a git repo, no exact tag at HEAD, or git unavailable — leave defaults
    end
    try
        status = read(`git -C $src_dir status --porcelain`, String)
        dirty = !isempty(strip(status))
    catch
    end
    return Dict(
        "package" => string(nameof(mod)),
        "source_dir" => src_dir,
        "commit" => commit,
        "tag" => tag === nothing ? "" : tag,
        "worktree_dirty" => dirty === nothing ? "unknown" : dirty,
        "julia_version" => string(VERSION),
    )
end

"""
    run_case_isolated(mod, case, fixture_root)

Run [`run_case`](@ref) for `case` against `fixture_root` using `mod` inside a
fresh `mktempdir()`, so the parser's `.tmp/*.xlsx` intermediates never touch
the repository root or the fixture tree.
"""
function run_case_isolated(mod::Module, case::PipelineRegressionCase, fixture_root::AbstractString)
    return cd(mktempdir()) do
        run_case(mod, case, fixture_root)
    end
end

"""
    capture_case!(mod, case, fixture_root, output_root, authority)

Run one case, write its 19 tables to `output_root/<case-id>/tables/*.arrow`,
and write `output_root/<case-id>/baseline.toml` recording `authority`, the
case parameters, and per-table row/column counts, column names, and Arrow
file SHA-256.
"""
function capture_case!(mod::Module, case::PipelineRegressionCase, fixture_root::AbstractString, output_root::AbstractString, authority::Dict)
    println("[capture] case `$(case.id)` — $(case.purpose)")
    tables = run_case_isolated(mod, case, fixture_root)

    case_dir = joinpath(output_root, case.id)
    tables_dir = joinpath(case_dir, "tables")
    mkpath(tables_dir)

    table_records = Dict{String,Any}()
    for (name, table) in pairs(tables)
        arrow_path = joinpath(tables_dir, "$(name).arrow")
        Arrow.write(arrow_path, table)
        table_records[String(name)] = Dict(
            "rows" => size(table, 1),
            "columns" => size(table, 2),
            "column_names" => names(table),
            "sha256" => sha256_file(arrow_path),
        )
    end

    manifest = Dict(
        "authority" => authority,
        "case" => Dict(
            "id" => case.id,
            "refyear" => case.refyear,
            "poe" => case.poe,
            "skip_traces" => case.skip_traces,
            "scenarios" => case.scenarios,
            "dstart" => string(case.dstart),
            "dend" => string(case.dend),
        ),
        "tables" => table_records,
    )

    open(joinpath(case_dir, "baseline.toml"), "w") do io
        TOML.print(io, manifest)
    end

    println("  wrote $(length(table_records)) table(s) to $case_dir")
end

function run_capture(fixture_root::AbstractString, output_root::AbstractString, case_id::Union{Nothing,AbstractString})
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

    mod = target_module()
    authority = target_authority(mod)
    println("capturing from package `$(authority["package"])` at commit $(authority["commit"])" *
            (isempty(authority["tag"]) ? "" : " (tag $(authority["tag"]))") *
            (authority["worktree_dirty"] == true ? " [DIRTY WORKTREE]" : ""))

    mkpath(output_root)
    for case in cases
        # `mod` is resolved at runtime by `target_module()` (`Base.require`),
        # so everything downstream that touches its types/methods (including
        # Arrow's Tables.jl dispatch on the returned DataFrames) needs to run
        # at the current world via `invokelatest` (world-age boundary).
        Base.invokelatest(capture_case!, mod, case, fixture_root, output_root, authority)
    end

    println()
    println("summary: captured $(length(cases)) case(s) to $output_root")
    return true
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

    if parsed.subcommand != "capture"
        println(stderr, "error: unknown subcommand `$(parsed.subcommand)`")
        println(stderr)
        println(stderr, usage())
        return 1
    end

    if parsed.fixture_root === nothing || parsed.output_root === nothing
        println(stderr, "error: --fixture-root and --output-root are both required")
        println(stderr)
        println(stderr, usage())
        return 1
    end

    fixture_root = abspath(parsed.fixture_root)
    isdir(fixture_root) || (println(stderr, "error: --fixture-root does not exist or is not a directory: $fixture_root"); return 1)
    fixture_root = realpath(fixture_root)

    output_root = abspath(parsed.output_root)

    ok = run_capture(fixture_root, output_root, parsed.case_id)
    return ok ? 0 : 1
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main(ARGS))
end
