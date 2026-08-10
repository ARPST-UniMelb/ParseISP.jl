using ParseISP
using Test
using Dates

include(joinpath(@__DIR__, "..", "docs", "utils", "ParseISPDocUtils.jl"))
import .ParseISPDocUtils

# The suite is partitioned into one file per topic.
# The source-availability checks run at top level (matching the original layout).
# The package-behaviour tests run under the "ParseISP.jl" test set.
include("test_source_availability.jl")

@testset "ParseISP.jl" begin
    include("test_zip_extraction.jl")
    include("test_report_downloader_2024.jl")
    include("test_report_downloader_2026.jl")
    include("test_source_downloader_2026.jl")
    include("test_buildout_defaults_documentation_2024.jl")
    include("test_source_specs.jl")
    include("test_pipeline_integration_2024.jl")
    include("test_pipeline_regression_fixture_2024.jl")
end
