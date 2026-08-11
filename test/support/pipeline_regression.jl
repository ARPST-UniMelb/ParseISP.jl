"""
Shared case matrix and in-memory table selector for the `fast` pipeline-value
regression facility. Consumed by the fixture builder, the regression runner,
and `Pkg.test()`'s synthetic helper tests.
"""

using Dates

struct PipelineRegressionCase
    id::String
    refyear::Int64
    poe::Int64
    skip_traces::Bool
    scenarios::Vector{Int64}
    dstart::DateTime
    dend::DateTime
    purpose::String
end

const PIPELINE_REGRESSION_CASES = PipelineRegressionCase[
    PipelineRegressionCase("default_fy_splice", 4006, 10, false, [1, 2, 3],
        DateTime(2025, 6, 30, 0, 0, 0), DateTime(2025, 7, 1, 23, 0, 0),
        "default settings, all scenarios, 48 hours, internal financial-year/weather-year splice"),
    PipelineRegressionCase("default_seasonal", 4006, 10, false, [1, 2, 3],
        DateTime(2024, 9, 30, 0, 0, 0), DateTime(2024, 10, 1, 23, 0, 0),
        "default settings, all scenarios, 48 hours, September-October boundary"),
    PipelineRegressionCase("ref4006_start_branch", 4006, 10, false, [2],
        DateTime(2024, 7, 1, 0, 0, 0), DateTime(2024, 7, 1, 23, 0, 0),
        "exercises the dstart <= 2024-07-01 solar/wind branch with valid source data"),
    PipelineRegressionCase("alternate_poe50", 4006, 50, false, [2],
        DateTime(2024, 9, 30, 0, 0, 0), DateTime(2024, 10, 1, 23, 0, 0),
        "alternate demand POE branch"),
    PipelineRegressionCase("alternate_refyear2011", 2011, 10, false, [2],
        DateTime(2024, 9, 30, 0, 0, 0), DateTime(2024, 10, 1, 23, 0, 0),
        "alternate prepared reference-year branch"),
    PipelineRegressionCase("traces_disabled", 4006, 10, true, [2],
        DateTime(2024, 9, 30, 0, 0, 0), DateTime(2024, 10, 1, 23, 0, 0),
        "skip_traces branch while retaining light schedules and static side effects"),
]

"""
    pipeline_regression_tables(tc, ts, tv)

Pure selector returning the 19 final public `DataFrame` fields captured by the
`fast` regression oracle, by reference. Performs no sorting, copying,
coercion, normalisation, or derived calculation.
"""
function pipeline_regression_tables(tc, ts, tv)
    return (
        config__problem      = tc.problem,
        static__bus          = ts.bus,
        static__dem          = ts.dem,
        static__ess          = ts.ess,
        static__gen          = ts.gen,
        static__line         = ts.line,
        static__der          = ts.der,
        varying__dem_load    = tv.dem_load,
        varying__ess_emax    = tv.ess_emax,
        varying__ess_lmax    = tv.ess_lmax,
        varying__ess_n       = tv.ess_n,
        varying__ess_pmax    = tv.ess_pmax,
        varying__ess_inflow  = tv.ess_inflow,
        varying__gen_n       = tv.gen_n,
        varying__gen_pmax    = tv.gen_pmax,
        varying__gen_inflow  = tv.gen_inflow,
        varying__line_fwcap  = tv.line_fwcap,
        varying__line_rvcap  = tv.line_rvcap,
        varying__der_pred    = tv.der_pred,
    )
end

"""
    run_case(ParseISP, case, download_root)

Run one [`PipelineRegressionCase`](@ref) against a `pisp-downloads`-shaped
`download_root` (either the maintainer's complete local collection or the
`fast` fixture) and return the 19 named tables in memory. Caller is
responsible for running this inside a fresh temporary working directory, so
that the parser's `.tmp/*.xlsx` intermediates never touch the repository
root or the source tree.
"""
function run_case(ParseISP, case::PipelineRegressionCase, download_root::AbstractString)
    paths = ParseISP.default_data_paths(filepath = download_root)
    tc, ts, tv = ParseISP.initialise_time_structures()
    ParseISP.fill_problem_table_drange(tc, case.dstart, case.dend; sce = case.scenarios)
    static_artifacts = ParseISP.populate_time_static!(
        ts, tv, paths;
        refyear = case.refyear,
        poe = case.poe,
    )
    ParseISP.populate_time_varying!(
        tc, ts, tv, paths, static_artifacts;
        refyear = case.refyear,
        poe = case.poe,
        skip_traces = case.skip_traces,
    )
    return pipeline_regression_tables(tc, ts, tv)
end
