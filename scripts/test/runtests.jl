# Tests for scripts/ tooling itself (not `src/`). Not run by `Pkg.test()` —
# invoke directly, mirroring docs/test/runtests.jl:
#
#   julia --project=. scripts/test/runtests.jl

using Test

include(joinpath(@__DIR__, "test_pipeline_regression_helpers.jl"))
