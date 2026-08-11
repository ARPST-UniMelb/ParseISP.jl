const ISP2026_SCENARIOS = (
    (id = 1, label = "Slower Growth"),
    (id = 2, label = "Step Change"),
    (id = 3, label = "Accelerated Transition"),
)

isp2026_scenarios() = ISP2026_SCENARIOS

function isp2026_scenario_label(id::Integer)
    for scenario in ISP2026_SCENARIOS
        scenario.id == id && return scenario.label
    end

    throw(ArgumentError("Unknown ISP 2026 scenario ID: $(repr(id))"))
end

function isp2026_scenario_id(label::AbstractString)
    for scenario in ISP2026_SCENARIOS
        scenario.label == label && return scenario.id
    end

    throw(ArgumentError("Unknown ISP 2026 scenario label: $(repr(label))"))
end
