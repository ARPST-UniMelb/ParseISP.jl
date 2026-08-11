using ParseISP
using Test

@testset "ISP 2026 scenario parameters" begin
    scenarios = ParseISP.isp2026_scenarios()

    @test scenarios == (
        (id = 1, label = "Slower Growth"),
        (id = 2, label = "Step Change"),
        (id = 3, label = "Accelerated Transition"),
    )

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

    @test_throws ArgumentError ParseISP.isp2026_scenario_label(4)
    @test_throws ArgumentError ParseISP.isp2026_scenario_id("Progressive Change")
    @test_throws ArgumentError ParseISP.isp2026_scenario_id("slower growth")
end
