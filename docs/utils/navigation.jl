const KIND_LABELS = Dict(
    "isp2024" => [
        "reference" => "Reference and inputs",
        "tutorial" => "Tutorials",
        "validation" => "Data validation",
        "analysis" => "Analyses and case studies",
    ],
)

function track_sections(registry_pages, track)
    sections = Any[]
    for (kind, label) in KIND_LABELS[track]
        pages = sort(
            filter(page -> is_published(page) && page.track == track && page.kind == kind, registry_pages);
            by = page -> (page.nav_order, page.id),
        )
        isempty(pages) || push!(sections, label => Any[page.title => page.output for page in pages])
    end
    return sections
end

function track_navigation(registry_pages, track, overview_title, overview_path)
    navigation = Any[overview_title => overview_path]
    append!(navigation, track_sections(registry_pages, track))
    return navigation
end

function lifecycle_navigation()
    return Any[
        "ISP source data" => Any[
            "ISP 2024 source material" => "editions/source-material.md",
            "Trace families and source meaning" => "editions/trace-coverage.md",
        ],
        "ParseISP transformation" => Any[
            "Supported ISP edition" => "editions/supported-editions.md",
            "Source-to-dataset processing" => "editions/source-inventory.md",
            "Parameters, mappings, and constants" => "editions/parameters-and-mappings.md",
        ],
        "ParseISP datasets" => Any[
            "Assets, relationships, and schedules" => "concepts.md",
            "Output tables, fields, and units" => "editions/output-data-model.md",
            "Dataset interpretation and study bounds" => "assumptions.md",
        ],
    ]
end

function registry_navigation(registry_pages)
    navigation = Any[
        "Home" => "index.md",
        "Quickstart" => "quickstart.md",
        "Understand ParseISP and ISP data" => lifecycle_navigation(),
    ]
    isp2024_navigation = track_navigation(registry_pages, "isp2024", "Overview", "editions/isp2024.md")
    insert!(isp2024_navigation, 2, "Preprocessing workflow" => "editions/isp2024-preprocessing.md")
    push!(navigation, "ISP 2024" => isp2024_navigation)
    push!(navigation, "Contributing" => "contributing.md")
    push!(navigation, "API Reference" => "api.md")
    return navigation
end
