# `fast`-profile pipeline-value regression smoke test.
#
# Runs the shared six-case matrix (test/support/pipeline_regression.jl)
# against the committed, Git-LFS-tracked ISP 2024 fixture at
# test/data/isp2024/pisp-downloads/, instead of the maintainer's
# full local ~66GB collection. Unlike test_pipeline_integration_2024.jl, this
# test does not require local-only data — the fixture ships in the
# repository (via LFS) — but it does honour ParseISP_SKIP_SLOW_TESTS=1, and
# it skips cleanly whenever the fixture is absent or its files are
# unresolved Git LFS pointers.
#
# This asserts structural well-formedness — the 19 named tables are present
# under their expected keys, every table is a DataFrame with at least one
# column, row counts are non-zero except where `skip_traces` deliberately
# empties trace-dependent tables, and the two tables the parser replaces
# wholesale (`static__gen`, `static__ess`) have the expected column schema —
# rather than pinned baseline values or full column/dtype coverage for every
# table. Exact-value regression assertions and full-schema checks for every
# table require a maintainer-designated trusted pre-refactor SHA, which has
# not happened yet; bounds/shape invariants (e.g. row counts implied by each
# case's scenario count and date range) are a further known gap, not
# silently accepted.

using DataFrames
using TOML

include(joinpath(@__DIR__, "support", "pipeline_regression.jl"))

const FIXTURE_ROOT = normpath(joinpath(@__DIR__, "data", "isp2024"))
const FIXTURE_DOWNLOAD_ROOT = joinpath(FIXTURE_ROOT, "pisp-downloads")
const FIXTURE_MANIFEST_PATH = joinpath(FIXTURE_ROOT, "fixture-manifest.toml")

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

preflight_status, preflight_message = fixture_preflight()
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
            end
        end
    end
end
