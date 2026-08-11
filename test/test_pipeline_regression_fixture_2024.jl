# `fast`-profile pipeline-value regression test.
#
# Runs the shared six-case matrix (test/support/pipeline_regression.jl)
# against the committed, Git-LFS-tracked ISP 2024 fixture at
# test/data/isp2024/pisp-downloads/, instead of the maintainer's
# full local ~66GB collection. Unlike test_pipeline_integration_2024.jl, this
# test does not require local-only data — the fixture ships in the
# repository (via LFS) — but it does honour ParseISP_SKIP_SLOW_TESTS=1, and
# it skips cleanly whenever the fixture or the baseline is absent or its
# files are unresolved Git LFS pointers.
#
# Two layers of assertion, per case:
#
# 1. Structural well-formedness — the 19 named tables are present under
#    their expected keys, every table is a DataFrame with at least one
#    column, row counts are non-zero except where `skip_traces`
#    deliberately empties trace-dependent tables, and the two tables the
#    parser replaces wholesale (`static__gen`, `static__ess`) have the
#    expected column schema.
# 2. Exact values — every table compared, column-by-column, `isequal`
#    against the committed test/data/isp2024/pisp-baselines/ snapshot
#    (captured from the maintainer-designated trusted pre-refactor commit,
#    `pre-0.1.0`). This is the same comparison scripts/audit_pipeline_regression.jl
#    check performs; here it runs automatically as part of Pkg.test() so a
#    value regression fails the ordinary test suite, not just a manually-run
#    script.
#
# Bounds/shape invariants (e.g. row counts implied by each case's scenario
# count and date range) beyond exact-value equality are a further known gap,
# not silently accepted.

using Arrow
using DataFrames
using TOML

if !isdefined(@__MODULE__, :PipelineRegressionCase)
    include(joinpath(@__DIR__, "support", "pipeline_regression.jl"))
end

const FIXTURE_ROOT = normpath(joinpath(@__DIR__, "data", "isp2024"))
const FIXTURE_DOWNLOAD_ROOT = joinpath(FIXTURE_ROOT, "pisp-downloads")
const FIXTURE_MANIFEST_PATH = joinpath(FIXTURE_ROOT, "fixture-manifest.toml")
const BASELINE_ROOT = joinpath(FIXTURE_ROOT, "pisp-baselines")

const EXPECTED_TABLE_KEYS = (
    :config__problem, :static__bus, :static__dem, :static__ess, :static__gen,
    :static__line, :static__der, :varying__dem_load, :varying__ess_emax,
    :varying__ess_lmax, :varying__ess_n, :varying__ess_pmax, :varying__ess_inflow,
    :varying__gen_n, :varying__gen_pmax, :varying__gen_inflow, :varying__line_fwcap,
    :varying__line_rvcap, :varying__der_pred,
)

# Tables that `populate_time_varying!` leaves at zero rows when
# `skip_traces=true` (verified empirically against this fixture: the other
# 12 tables — including varying__gen_pmax, populated from committed/retirement
# rows rather than traces — stay non-empty regardless of skip_traces).
const SKIP_TRACES_EMPTY_TABLES = (
    :varying__dem_load, :varying__ess_emax, :varying__ess_lmax,
    :varying__ess_pmax, :varying__ess_inflow, :varying__gen_inflow,
    :varying__der_pred,
)

const EXPECTED_GEN_COLUMNS = [
    "id_gen", "name", "alias", "fuel", "tech", "type", "capacity", "forate",
    "fullout", "partialout", "derate", "mttrfull", "mttrpart", "id_bus", "pmin",
    "pmax", "rup", "rdw", "investment", "active", "cvar", "cfuel", "cvom",
    "cfom", "co2", "slope", "hrate", "pfrmax", "g", "inertia", "ffr", "pfr",
    "res2", "res3", "powerfactor", "latitude", "longitude", "n", "contingency",
    "down_time", "up_time", "last_state", "last_state_period",
    "last_state_output", "start_up_cost", "shut_down_cost", "start_up_time",
    "shut_down_time",
]

const EXPECTED_ESS_COLUMNS = [
    "id_ess", "name", "alias", "tech", "type", "capacity", "investment",
    "active", "id_bus", "ch_eff", "dch_eff", "eini", "emin", "emax", "pmin",
    "pmax", "lmin", "lmax", "fullout", "partialout", "mttrfull", "mttrpart",
    "inertia", "powerfactor", "ffr", "pfr", "res2", "res3", "fr_db", "fr_ad",
    "fr_dt", "fr_frt", "fr_fr", "longitude", "latitude", "n", "contingency",
]

"""
    unresolved_lfs_pointer(path)

Return `true` if `path` is an unresolved Git LFS pointer stub (text
beginning with the LFS pointer spec header) rather than real fetched
content. Lets this test fail with an actionable message instead of a
confusing XLSX/CSV parse error when `git lfs pull` hasn't been run.
"""
function unresolved_lfs_pointer(path::AbstractString)
    isfile(path) || return false
    filesize(path) > 1024 && return false
    open(path, "r") do io
        header = String(read(io, min(64, filesize(path))))
        return startswith(header, "version https://git-lfs.github.com/spec/v1")
    end
end

"""
    fixture_preflight()

Parse the committed `fixture-manifest.toml` and verify every listed file
exists at its recorded size and is not an unresolved Git LFS pointer,
before any parser case starts. Returns `(:ok, "")`, `(:absent, message)`
when the fixture directory itself is missing, or `(:error, message)` for
any other manifest/inventory mismatch — this is a stat/read-only pass
over ~892 small headers, not a full checksum, so it stays effectively
free relative to running even one case.
"""
function fixture_preflight()
    isdir(FIXTURE_DOWNLOAD_ROOT) ||
        return (:absent, "test/data/isp2024/pisp-downloads is absent")
    isfile(FIXTURE_MANIFEST_PATH) &&
        return _check_manifest_entries()
    return (:error, "test/data/isp2024/fixture-manifest.toml is missing")
end

function _check_manifest_entries()
    manifest = TOML.parsefile(FIXTURE_MANIFEST_PATH)
    entries = get(manifest, "files", [])
    isempty(entries) && return (:error, "fixture-manifest.toml lists no files")

    for entry in entries
        relpath = entry["path"]
        path = joinpath(FIXTURE_DOWNLOAD_ROOT, relpath)
        isfile(path) || return (:error, "fixture file missing: $relpath")
        unresolved_lfs_pointer(path) &&
            return (:error, "fixture file is an unresolved Git LFS pointer: $relpath (run `git lfs pull`)")
        actual = filesize(path)
        expected = entry["size_bytes"]
        actual == expected ||
            return (:error, "fixture file size mismatch for $relpath: expected $expected bytes, found $actual")
    end
    return (:ok, "")
end

"""
    baseline_preflight()

Verify the committed `pisp-baselines/` tree (captured from the maintainer-
designated trusted commit, `pre-0.1.0`) has a `baseline.toml` and all 19
Arrow table files, none of them unresolved Git LFS pointers, for every case
in `PIPELINE_REGRESSION_CASES`. Returns `(:ok, "")`, `(:absent, message)`
when the baseline directory itself is missing, or `(:error, message)` for
any other inventory mismatch.
"""
function baseline_preflight()
    isdir(BASELINE_ROOT) || return (:absent, "test/data/isp2024/pisp-baselines is absent")
    for case in PIPELINE_REGRESSION_CASES
        case_dir = joinpath(BASELINE_ROOT, case.id)
        isfile(joinpath(case_dir, "baseline.toml")) ||
            return (:error, "missing baseline.toml for case `$(case.id)`")
        for name in EXPECTED_TABLE_KEYS
            arrow_path = joinpath(case_dir, "tables", "$(name).arrow")
            isfile(arrow_path) ||
                return (:error, "missing baseline table for case `$(case.id)`, table `$name`")
            unresolved_lfs_pointer(arrow_path) &&
                return (:error, "baseline table is an unresolved Git LFS pointer for case `$(case.id)`, table `$name` (run `git lfs pull`)")
        end
    end
    return (:ok, "")
end

"""
    load_baseline_tables(case_id)

Read `pisp-baselines/<case_id>/tables/*.arrow` for every table in
[`EXPECTED_TABLE_KEYS`](@ref), materialising every Arrow-backed column into
a plain `Vector` so a mismatch never reports a storage-wrapper type as the
expected Julia type. Returns a `Dict{Symbol,DataFrames.DataFrame}`.
"""
function load_baseline_tables(case_id::AbstractString)
    tables_dir = joinpath(BASELINE_ROOT, case_id, "tables")
    return Dict(
        name => DataFrames.mapcols(collect, DataFrames.DataFrame(Arrow.Table(joinpath(tables_dir, "$(name).arrow"))))
        for name in EXPECTED_TABLE_KEYS
    )
end

"""
    tables_isequal(a, b)

`true` if two `DataFrame`s have the same column names/order, the same row
count, and every column is `isequal` element-wise — so `missing`, `NaN`,
and signed-zero distinctions all count as mismatches.
"""
function tables_isequal(a::DataFrames.DataFrame, b::DataFrames.DataFrame)
    names(a) == names(b) || return false
    nrow(a) == nrow(b) || return false
    return all(isequal(a[!, col], b[!, col]) for col in names(a))
end

preflight_status, preflight_message = fixture_preflight()
baseline_status, baseline_message = baseline_preflight()
skip_slow = get(ENV, "ParseISP_SKIP_SLOW_TESTS", "") == "1"

@testset "pipeline regression fixture (2024, fast profile, six-case matrix)" begin
    if skip_slow
        @test_skip "ParseISP_SKIP_SLOW_TESTS=1; skipping the fixture-backed pipeline regression test"
    elseif preflight_status !== :ok
        @test_skip preflight_message
    else
        for case in PIPELINE_REGRESSION_CASES
            @testset "$(case.id)" begin
                tmp = mktempdir()
                tables = try
                    cd(tmp) do
                        run_case(ParseISP, case, FIXTURE_DOWNLOAD_ROOT)
                    end
                finally
                    rm(tmp; recursive=true, force=true)
                end

                @test keys(tables) == EXPECTED_TABLE_KEYS
                for name in EXPECTED_TABLE_KEYS
                    table = tables[name]
                    @testset "$(name)" begin
                        @test table isa DataFrames.DataFrame
                        @test size(table, 2) > 0
                        if case.skip_traces && name in SKIP_TRACES_EMPTY_TABLES
                            @test size(table, 1) == 0
                        else
                            @test size(table, 1) > 0
                        end
                    end
                end

                @test names(tables.static__gen) == EXPECTED_GEN_COLUMNS
                @test names(tables.static__ess) == EXPECTED_ESS_COLUMNS

                @testset "exact values vs pre-0.1.0 baseline" begin
                    if baseline_status !== :ok
                        @test_skip baseline_message
                    else
                        baseline_tables = load_baseline_tables(case.id)
                        for name in EXPECTED_TABLE_KEYS
                            @test tables_isequal(tables[name], baseline_tables[name])
                        end
                    end
                end
            end
        end
    end
end
