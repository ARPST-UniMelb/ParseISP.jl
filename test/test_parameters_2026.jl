using ParseISP
using Test

const EXPECTED_ISP2026_SCENARIOS = (
    (id = 1, label = "Slower Growth"),
    (id = 2, label = "Step Change"),
    (id = 3, label = "Accelerated Transition"),
)

function assert_isp2026_argument_error(call, rejected, supported)
    caught = try
        call()
        nothing
    catch error
        error
    end

    @test caught isa ArgumentError
    caught isa ArgumentError || return
    message = sprint(showerror, caught)
    @test occursin(string(rejected), message)
    for supported_value in supported
        @test occursin(string(supported_value), message)
    end
end

@testset "ISP 2026 scenario parameters" begin
    @test isfile(joinpath(dirname(@__DIR__), "src", "parameters", "scenarios2026ISP.jl"))
    @test !isfile(joinpath(dirname(@__DIR__), "src", "parameters", "isp2026.jl"))
    scenarios = ParseISP.isp2026_scenarios()

    @test scenarios === ParseISP.ISP2026_SCENARIOS
    @test scenarios == EXPECTED_ISP2026_SCENARIOS
    @test scenarios isa Tuple
    @test all(scenario isa NamedTuple for scenario in scenarios)

    for scenario in scenarios
        @test ParseISP.isp2026_scenario_label(scenario.id) == scenario.label
        @test ParseISP.isp2026_scenario_id(scenario.label) == scenario.id
    end

    for name in (
        :ISP2026_SCENARIOS,
        :isp2026_scenarios,
        :isp2026_scenario_label,
        :isp2026_scenario_id,
    )
        @test name ∉ names(ParseISP)
    end

    for id in (0, 4, -1, true, false)
        assert_isp2026_argument_error(
            () -> ParseISP.isp2026_scenario_label(id),
            id,
            (1, 2, 3),
        )
    end

    for label in (
        "Progressive Change",
        "Green Energy Exports",
        "slower growth",
        "Step change",
        " Slower Growth",
        "Slower Growth ",
        "Unknown",
    )
        assert_isp2026_argument_error(
            () -> ParseISP.isp2026_scenario_id(label),
            label,
            ("Slower Growth", "Step Change", "Accelerated Transition"),
        )
    end
end
