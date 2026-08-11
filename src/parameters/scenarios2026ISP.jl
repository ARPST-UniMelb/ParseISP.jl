const ISP2026_SCENARIOS = (
    (id = 1, label = "Slower Growth"),
    (id = 2, label = "Step Change"),
    (id = 3, label = "Accelerated Transition"),
)

isp2026_scenarios() = ISP2026_SCENARIOS

function isp2026_scenario_label(id::Integer)
    if id isa Bool
        throw(ArgumentError(
            "Unsupported ISP 2026 scenario ID $(repr(id)); supported IDs: 1, 2, 3.",
        ))
    end

    for scenario in ISP2026_SCENARIOS
        scenario.id == id && return scenario.label
    end

    throw(ArgumentError(
        "Unsupported ISP 2026 scenario ID $(repr(id)); supported IDs: 1, 2, 3.",
    ))
end

function isp2026_scenario_id(label::AbstractString)
    for scenario in ISP2026_SCENARIOS
        scenario.label == label && return scenario.id
    end

    throw(ArgumentError(
        "Unsupported ISP 2026 scenario label $(repr(label)); " *
        "supported labels: \"Slower Growth\", \"Step Change\", " *
        "\"Accelerated Transition\".",
    ))
end
