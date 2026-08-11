using Test
using DataFrames
using Dates
using TOML
import ParseISP

const TEST_DOCS_DIR = normpath(joinpath(@__DIR__, ".."))

include(joinpath(TEST_DOCS_DIR, "render_literate.jl"))
include(joinpath(TEST_DOCS_DIR, "utils", "navigation.jl"))
include(joinpath(TEST_DOCS_DIR, "utils", "source_links.jl"))
include(joinpath(@__DIR__, "doc_invariants.jl"))

@testset "Documentation utility layout" begin
    expected_root_entries = sort([
        ".gitignore",
        "Project.toml",
        "README.md",
        "build_all.jl",
        "config",
        "doctests.jl",
        "literate",
        "make.jl",
        "render_changed.jl",
        "render_literate.jl",
        "src",
        "test",
        "utils",
    ])
    root_entries = filter(readdir(TEST_DOCS_DIR)) do name
        name in ("build", ".documenter-source", "Manifest.toml", ".DS_Store") && return false
        startswith(name, ".literate-staging-") && return false
        return true
    end
    @test sort(root_entries) == expected_root_entries

    utils_dir = joinpath(TEST_DOCS_DIR, "utils")
    facade_path = joinpath(utils_dir, "ParseISPDocUtils.jl")
    facade = read(facade_path, String)
    @test length(collect(eachmatch(r"(?m)^\s*module\s+ParseISPDocUtils\s*$", facade))) == 1

    utility_sources = String[]
    module_declarations = String[]
    for (directory, _, files) in walkdir(utils_dir)
        for filename in files
            endswith(filename, ".jl") || continue
            source = read(joinpath(directory, filename), String)
            push!(utility_sources, source)
            append!(
                module_declarations,
                [strip(match.match) for match in eachmatch(r"(?m)^\s*module\s+\w+\s*$", source)],
            )
        end
    end
    @test module_declarations == ["module ParseISPDocUtils"]
    @test !occursin(r"(?m)^\s*(export|public)\b", join(utility_sources, "\n"))

    for filename in (
        "page-registry.toml",
        "source-links.toml",
        "source-material-coverage.toml",
    )
        @test isfile(joinpath(TEST_DOCS_DIR, "config", filename))
    end

    literate_root = joinpath(TEST_DOCS_DIR, "literate")
    for (directory, _, files) in walkdir(literate_root)
        for filename in files
            endswith(filename, ".jl") || continue
            source = read(joinpath(directory, filename), String)
            occursin("ParseISPDocUtils.", source) || continue
            @test occursin("import .ParseISPDocUtils", source)
            @test !occursin("using .ParseISPDocUtils", source)
        end
    end
end

@testset "Markdown table rendering" begin
    rendered = ParseISPDocUtils.markdown_table(DataFrame(Label=["alpha", "beta"], Value=[1.0, 2.0]))
    separator_cells = strip.(split(split(chomp(rendered.text), '\n')[2], '|'; keepempty=false))

    @test length(separator_cells) == 2
    @test !endswith(separator_cells[1], ":")
    @test endswith(separator_cells[2], ":")
    @test occursin("alpha", rendered.text)

    currency = ParseISPDocUtils.markdown_table(DataFrame(Label=["Cost (\$/MW)"], Value=[2.0]))
    @test occursin(raw"\$", currency.text)

    missing_numeric = ParseISPDocUtils.markdown_table(
        DataFrame(Label=["alpha", "beta"], Value=Union{Missing,Float64}[1.0, missing]),
    )
    missing_separator = strip.(split(split(chomp(missing_numeric.text), '\n')[2], '|'; keepempty=false))
    @test endswith(missing_separator[2], ":")

    empty_typed = ParseISPDocUtils.markdown_table(DataFrame(Label=String[], Value=Float64[]))
    empty_separator = strip.(split(split(chomp(empty_typed.text), '\n')[2], '|'; keepempty=false))
    @test !endswith(empty_separator[1], ":")
    @test endswith(empty_separator[2], ":")

    mixed_any = ParseISPDocUtils.markdown_table(DataFrame(Mixed=Any[1, "two"], Value=Any[1, 2]))
    mixed_separator = strip.(split(split(chomp(mixed_any.text), '\n')[2], '|'; keepempty=false))
    @test !endswith(mixed_separator[1], ":")
    @test endswith(mixed_separator[2], ":")

    overridden = ParseISPDocUtils.markdown_table(
        DataFrame(Label=["alpha"], Value=[1.0]);
        alignment=[:r, :l],
    )
    overridden_separator = strip.(split(split(chomp(overridden.text), '\n')[2], '|'; keepempty=false))
    @test endswith(overridden_separator[1], ":")
    @test !endswith(overridden_separator[2], ":")

    multiline = ParseISPDocUtils.markdown_table(DataFrame(Label=["alpha\nbeta"], Value=[1]))
    @test occursin("alpha beta", multiline.text)
    @test !occursin("alpha\nbeta", multiline.text)

    metrics = ParseISPDocUtils.metric_value_table(["Rows" => 12, "Coverage (%)" => 98.5])
    @test occursin("Metric", metrics.text)
    @test occursin("Coverage (%)", metrics.text)

    table_interface = ParseISPDocUtils.markdown_table((Label=["alpha"], Value=[1.0]))
    @test occursin("alpha", table_interface.text)

    manual = ParseISPDocUtils.markdown_table(
        ["Name", "Value"],
        [Any["alpha|beta", nothing], Any["line\nbreak", 2]];
        alignment = [:left, :right],
        nothing_text = "—",
    )
    @test occursin("alpha\\|beta", manual.text)
    @test occursin("line break", manual.text)
    @test occursin("| — |", manual.text)
    @test occursin("---:", manual.text)

    raw = ParseISPDocUtils.RawMarkdown("**unescaped Markdown**")
    @test sprint(show, MIME"text/markdown"(), raw) == "**unescaped Markdown**"
    @test ParseISPDocUtils.markdown_items(["a|b", "c"]) == "`a\\|b`, `c`"
end

@testset "Shared documentation transformations" begin
    @test ParseISPDocUtils.TABLE_ROOT == normpath(joinpath(TEST_DOCS_DIR, "src", "tables"))
    @test ParseISPDocUtils.FIGURE_ROOT == normpath(joinpath(TEST_DOCS_DIR, "src", "figures"))

    matrix = Any[1 missing missing; missing missing missing; 2 missing missing]
    trimmed = ParseISPDocUtils.trim_sheet(matrix)
    @test size(trimmed) == (3, 1)
    @test isequal(trimmed[:, 1], Any[1, missing, 2])
    @test size(ParseISPDocUtils.trim_sheet(fill(missing, 2, 2))) == (0, 0)

    frame = DataFrame(Year=[2024, 2024], Month=[1, 1], Day=[1, 2], a=[1.0, 3.0], b=[3.0, 5.0])
    @test ParseISPDocUtils.add_datetime!(frame) === frame
    @test frame.datetime == [Date(2024, 1, 1), Date(2024, 1, 2)]
    @test ParseISPDocUtils.row_mean(frame, [:a, :b]) == [2.0, 4.0]
    @test isequal(ParseISPDocUtils.rolling_mean([1.0, 2.0, 3.0], 2), [missing, 1.5, 2.5])

end

@testset "Report availability catalogue parity" begin
    catalogue_cases = (
        ("2024", ParseISP.ISP2024ReportDownloader.report_targets(), 27),
        ("2026", ParseISP.ISP2026ReportDownloader.report_targets(), 19),
    )

    for (edition, targets, expected_count) in catalogue_cases
        report_requirements = filter(
            requirement -> requirement.class == :report,
            ParseISPDocUtils.edition_requirements(edition),
        )
        @test [requirement.relative_path for requirement in report_requirements] ==
            [target.filename for target in targets]
        @test length(report_requirements) == expected_count
    end
end

@testset "Report catalogue registry parity" begin
    registry = load_registry(joinpath(TEST_DOCS_DIR, "config", "source-links.toml"))
    targets = vcat(
        [(edition = "2024", target = target) for target in ParseISP.ISP2024ReportDownloader.report_targets()],
        [(edition = "2026", target = target) for target in ParseISP.ISP2026ReportDownloader.report_targets()],
    )
    expected = Dict(
        "data/$(item.edition)/pisp-reports/$(item.target.filename)" =>
            (item.target.title, item.target.url)
        for item in targets
    )

    @test length(registry) == 46
    @test Dict(entry.local_path => (entry.title, entry.public_url) for entry in registry) == expected
    @test all(entry -> entry.publisher == "Australian Energy Market Operator", registry)
    @test all(entry -> entry.public_origin == "official", registry)
end

@testset "Report counterpart map" begin
    expected_pairs = [
        :plexos_model_instructions => :plexos_model_instructions,
        :integrated_system_plan => :integrated_system_plan,
        :iasr_2023 => :iasr_2025,
        :iasr_2023_addendum => :iasr_2025_addendum,
        :isp_methodology_2023 => :isp_methodology_2025,
        :appendix_a2_generation_storage => :appendix_a2_generation_storage,
        :appendix_a3_rez => :appendix_a3_rez,
        :appendix_a4_operability => :appendix_a4_operability,
        :appendix_a6_cost_benefit => :appendix_a6_cost_benefit,
        :appendix_a7_security => :appendix_a7_security,
        :publication_webinar_presentation => :publication_webinar_presentation,
        :appendix_a1_stakeholder_engagement => :appendix_a1_stakeholder_engagement,
        :appendix_a5_network_investments => :appendix_a5_network_investments,
        :appendix_a8_social_licence => :appendix_a8_social_licence,
        :consultation_summary => :consultation_summary,
    ]

    @test isdefined(ParseISPDocUtils, :report_counterpart_key_map)
    if isdefined(ParseISPDocUtils, :report_counterpart_key_map)
        pairs = ParseISPDocUtils.report_counterpart_key_map()
        keys_2024 = Set(target.key for target in ParseISP.ISP2024ReportDownloader.report_targets())
        keys_2026 = Set(target.key for target in ParseISP.ISP2026ReportDownloader.report_targets())
        mapped_2024 = first.(pairs)
        mapped_2026 = last.(pairs)

        @test pairs == expected_pairs
        @test length(pairs) == 15
        @test length(unique(mapped_2024)) == length(pairs)
        @test length(unique(mapped_2026)) == length(pairs)
        @test Set(mapped_2024) ⊆ keys_2024
        @test Set(mapped_2026) ⊆ keys_2026
        @test length(setdiff(keys_2024, Set(mapped_2024))) == 12
        @test length(setdiff(keys_2026, Set(mapped_2026))) == 4
    end
end

function generated_table_rows(markdown, heading)
    lines = split(markdown, '\n'; keepempty = true)
    heading_index = findfirst(==(heading), lines)
    heading_index === nothing && return Vector{Vector{String}}()
    table_start = findfirst(index -> startswith(lines[index], "| "), (heading_index + 1):length(lines))
    table_start === nothing && return Vector{Vector{String}}()
    absolute_start = heading_index + table_start
    rows = Vector{Vector{String}}()
    for line in lines[(absolute_start + 2):end]
        startswith(line, "| ") || break
        match_result = match(r"^\| (.*?) \| (.*?) \|$", line)
        match_result === nothing || push!(rows, String[match_result.captures...])
    end
    return rows
end

@testset "Report catalogue generated inventories" begin
    page_registry = TOML.parsefile(joinpath(TEST_DOCS_DIR, "config", "page-registry.toml"))
    catalogue_pages = filter(page -> page["id"] == "comparison-report-catalogue", page_registry["page"])
    @test length(catalogue_pages) == 1
    if length(catalogue_pages) == 1
        catalogue_page = only(catalogue_pages)
        @test catalogue_page["source"] == "literate/comparison/reference/report_catalogue.jl"
        @test catalogue_page["output"] == "generated/comparison/references/report-catalogue.md"
        @test catalogue_page["track"] == "comparison"
        @test catalogue_page["editions"] == ["2024", "2026"]
    end

    generated_path = joinpath(
        TEST_DOCS_DIR,
        "src",
        "generated",
        "comparison",
        "references",
        "report-catalogue.md",
    )
    @test isfile(generated_path)

    if isfile(generated_path)
        generated = read(generated_path, String)
        targets_by_edition = Dict(
            "2024" => collect(ParseISP.ISP2024ReportDownloader.report_targets()),
            "2026" => collect(ParseISP.ISP2026ReportDownloader.report_targets()),
        )
        for (edition, heading) in (
            "2024" => "## ISP 2024 report inventory",
            "2026" => "## ISP 2026 report inventory",
        )
            rows = generated_table_rows(generated, heading)
            targets = targets_by_edition[edition]
            @test length(rows) == length(targets)
            if length(rows) == length(targets)
                @test [row[1] for row in rows] == [target.title for target in targets]
                for (row, target) in zip(rows, targets)
                    local_link = "[$(target.filename)](../../../../../data/$(edition)/pisp-reports/$(target.filename)#page=1)"
                    official_link = "[AEMO]($(target.url))"
                    @test row[2] == "$(local_link) · $(official_link)"
                end
            end
        end

        counterpart_rows = generated_table_rows(generated, "## Explicit counterparts")
        @test length(counterpart_rows) == 15
        if length(counterpart_rows) == 15
            targets_2024 = Dict(target.key => target for target in ParseISP.ISP2024ReportDownloader.report_targets())
            targets_2026 = Dict(target.key => target for target in ParseISP.ISP2026ReportDownloader.report_targets())
            for (row, (key_2024, key_2026)) in zip(counterpart_rows, ParseISPDocUtils.report_counterpart_key_map())
                for (cell, edition, target) in (
                    (row[1], "2024", targets_2024[key_2024]),
                    (row[2], "2026", targets_2026[key_2026]),
                )
                    local_link = "[$(target.filename)](../../../../../data/$(edition)/pisp-reports/$(target.filename)#page=1)"
                    official_link = "[AEMO]($(target.url))"
                    @test cell == "$(target.title) — $(local_link) · $(official_link)"
                end
            end
        end
        @test occursin("Report title", generated)
        @test occursin("Filename", generated)
    end
end

@testset "Documentation source-reading boundaries" begin
    utils_dir = joinpath(TEST_DOCS_DIR, "utils")
    source_material_path = joinpath(utils_dir, "source_material.jl")
    source_material = read(source_material_path, String)

    @test !isfile(joinpath(utils_dir, "source_material_specs.jl"))
    @test !occursin("XLSX.readdata", source_material)

    literate_root = joinpath(TEST_DOCS_DIR, "literate")
    literate_sources = String[]
    for (directory, _, files) in walkdir(literate_root)
        for filename in files
            endswith(filename, ".jl") || continue
            push!(literate_sources, read(joinpath(directory, filename), String))
        end
    end
    literate_source = join(literate_sources, "\n")

    @test !occursin("validate_columns", literate_source)

    spec_driven_2024_pages = [
        "demand_and_distributed_resources.jl",
        "demand_side_participation.jl",
        "electric_vehicles.jl",
        "existing_generation_and_storage.jl",
        "generation_and_storage_outlook.jl",
        "generator_operation.jl",
        "generator_reliability_and_retirement.jl",
        "hydro_inflows_and_energy_constraints.jl",
        "network_and_transmission.jl",
        "renewable_energy_zones.jl",
    ]
    shared_source_root = joinpath(literate_root, "shared", "source_material")
    for filename in spec_driven_2024_pages
        source = read(joinpath(shared_source_root, filename), String)
        @test occursin("ParseISP.source_spec(", source)
        @test occursin("ParseISP.source_path(", source)
        @test occursin(r"ParseISP\.read_(xlsx_rows|csv_source)\(", source)
        @test occursin("XLSX.readdata(", source)
    end
end

@testset "Raw and processed data-selection tutorials" begin
    registry = TOML.parsefile(joinpath(TEST_DOCS_DIR, "config", "page-registry.toml"))
    raw_pages = filter(page -> page["id"] == "shared-selecting-raw-isp-material", registry["page"])
    @test length(raw_pages) == 1
    if length(raw_pages) == 1
        raw_page = only(raw_pages)
        @test raw_page["kind"] == "tutorial"
        @test raw_page["track"] == "shared"
        @test raw_page["editions"] == ["2024", "2026"]
        @test raw_page["data_layer"] == "source-data"
        @test raw_page["source"] == "literate/shared/tutorials/selecting_raw_isp_material.jl"
        @test raw_page["output"] == "generated/shared/tutorials/selecting-raw-isp-material.md"
        @test raw_page["nav_order"] == 140
    end

    raw_source_path = joinpath(
        TEST_DOCS_DIR,
        "literate",
        "shared",
        "tutorials",
        "selecting_raw_isp_material.jl",
    )
    @test isfile(raw_source_path)
    raw_source = isfile(raw_source_path) ? read(raw_source_path, String) : ""
    for required in (
        "ParseISP.source_spec(:operational_demand_trace, 2024)",
        "ParseISP.source_path(",
        "ParseISPDocUtils.edition_profile(REPO_ROOT, \"2026\")",
        "ParseISP_DOCS_RAW_REFTRACE",
        "ParseISP_DOCS_RAW_POE",
        "RefYear5000",
    )
        @test occursin(required, raw_source)
    end

    processed_source = read(
        joinpath(
            TEST_DOCS_DIR,
            "literate",
            "isp2024",
            "tutorials",
            "working_with_pisp_outputs.jl",
        ),
        String,
    )
    for required in (
        "ParseISP_DOCS_ISP2024_REFTRACE",
        "ParseISP_DOCS_ISP2024_POE",
        "ParseISP_DOCS_ISP2024_YEAR",
        "out-ref\$(REFTRACE)-poe\$(POE)",
        "schedule-\$(PLANNING_YEAR)",
        "available_builds",
        "available_schedule_years",
    )
        @test occursin(required, processed_source)
    end
end

@testset "ISP 2026 docs-first source specification" begin
    inventory_path = joinpath(TEST_DOCS_DIR, "config", "isp2026-source-specs.toml")
    inventory = TOML.parsefile(inventory_path)
    @test inventory["schema_version"] == 2
    @test inventory["edition"] == "2026"

    lineage_ids = reduce(vcat, values(inventory["lineage"]))
    @test length(lineage_ids) == 80
    @test length(unique(lineage_ids)) == 80

    sources = inventory["source"]
    @test length(sources) == 39
    @test length(unique(source["id"] for source in sources)) == 39
    registered_2024_ids = Set(string(spec.id) for spec in ParseISP.source_specs(2024))
    @test isempty(intersect(Set(source["id"] for source in sources), registered_2024_ids))
    source_lineage_ids = reduce(vcat, [source["lineage_2024"] for source in sources])
    @test length(source_lineage_ids) == length(unique(source_lineage_ids))
    @test Set(source_lineage_ids) == Set(lineage_ids)
    required_fields = Set([
        "id",
        "group",
        "status",
        "format",
        "path",
        "selection",
        "keys",
        "fields_units",
        "lineage_2024",
    ])
    @test all(source -> required_fields ⊆ Set(keys(source)), sources)
    @test all(sources) do source
        !isempty(source["lineage_2024"]) || get(source, "basis", "") == "2026-only"
    end
    @test Set(source["status"] for source in sources) == Set([
        "observed",
        "changed",
        "relocated",
        "unresolved",
        "not-observed",
        "generated-by-pisp",
        "user-supplied",
        "legacy-supplement",
    ])

    registry = TOML.parsefile(joinpath(TEST_DOCS_DIR, "config", "page-registry.toml"))
    pages = registry["page"]
    isp2026_reference_or_validation = filter(
        page -> page["track"] == "isp2026" && page["kind"] in ("reference", "validation"),
        pages,
    )
    @test Set(page["id"] for page in isp2026_reference_or_validation) == Set([
        "isp2026-source-data",
        "isp2026-workbook-and-trace-structure",
    ])
    @test all(page -> page["status"] == "published", isp2026_reference_or_validation)

    raw_page_pairs = [
        ("isp2024-source-data", "isp2026-source-data"),
        ("isp2024-workbook-and-trace-structure", "isp2026-workbook-and-trace-structure"),
    ]
    pages_by_id = Dict(page["id"] => page for page in pages)
    for (isp2024_id, isp2026_id) in raw_page_pairs
        isp2024_page = pages_by_id[isp2024_id]
        isp2026_page = pages_by_id[isp2026_id]
        @test basename(isp2024_page["source"]) == basename(isp2026_page["source"])
        @test basename(isp2024_page["output"]) == basename(isp2026_page["output"])
        @test replace(isp2024_page["title"], "2024" => "<edition>") ==
            replace(isp2026_page["title"], "2026" => "<edition>")
        @test isp2024_page["kind"] == isp2026_page["kind"]
        @test isp2024_page["data_layer"] == "source-data"
        @test isp2026_page["data_layer"] == "source-data"
        @test isp2024_page["nav_order"] == 10
        @test isp2026_page["nav_order"] == 10
    end

    source_spec_path = joinpath(
        TEST_DOCS_DIR,
        "literate",
        "isp2026",
        "reference",
        "source_data.jl",
    )
    validation_path = joinpath(
        TEST_DOCS_DIR,
        "literate",
        "isp2026",
        "validation",
        "workbook_and_trace_structure.jl",
    )
    source_spec_output = joinpath(
        TEST_DOCS_DIR,
        "src",
        "generated",
        "isp2026",
        "reference",
        "source-data.md",
    )
    validation_output = joinpath(
        TEST_DOCS_DIR,
        "src",
        "generated",
        "isp2026",
        "validation",
        "workbook-and-trace-structure.md",
    )
    @test all(isfile, (source_spec_path, validation_path, source_spec_output, validation_output))

    source_spec = read(source_spec_path, String)
    @test occursin("# # ISP 2026: Source data", source_spec)
    @test occursin("# ## Inputs and assumptions workbook", source_spec)
    @test occursin("# ## Electric-vehicle workbook", source_spec)
    @test occursin("# ## Generation and storage outlook", source_spec)
    @test occursin("# ## Model and trace files", source_spec)
    @test occursin("Fields and units", source_spec)
    @test !occursin("pipeline_role", source_spec)
    @test !occursin("Candidate ParseISP consumer", source_spec)
    @test !occursin("Observed trace files by scenario", source_spec)

    source_validation = read(validation_path, String)
    @test occursin("# # ISP 2026: Workbook and trace structure", source_validation)
    @test occursin("required_source_fields", source_validation)
    @test occursin("# ## Workbook structure", source_validation)
    @test occursin("# ## Model archive structure", source_validation)
    @test occursin("# ## Trace schema", source_validation)
    @test occursin("# ## Compare editions", source_validation)
    for diagnostic_text in (
        "Availability state in configured roots",
        "Demand CSV traces observed",
        "PoE labels observed in local filenames",
        "Snapshot scope",
        "does not claim",
        "before package integration",
        "under review",
        "not yet integrated",
        "readiness",
        "provenance",
    )
        @test !occursin(diagnostic_text, source_validation)
    end

    for generated_path in (source_spec_output, validation_output)
        generated = lowercase(read(generated_path, String))
        for reader_term in ("local checkout", "locally available", "provenance", "readiness", "under review", "not yet integrated")
            @test !occursin(reader_term, generated)
        end
    end

    @test Set(
        page["id"] for page in pages
        if page["track"] == "isp2024" && page["kind"] == "reference"
    ) == Set([
        "isp2024-source-data",
        "isp2024-output-tables",
        "isp2024-parameters-and-mappings",
        "isp2024-buildout-defaults",
        "isp2024-hydro-parameters-and-constants",
    ])
    @test Set(
        page["id"] for page in pages
        if page["track"] == "isp2024" && page["kind"] == "validation"
    ) == Set([
        "isp2024-workbook-and-trace-structure",
        "isp2024-temperature-data-coverage",
        "isp2024-generated-output-consistency",
    ])

    source_data_2024 = read(
        joinpath(TEST_DOCS_DIR, "literate", "isp2024", "reference", "source_data.jl"),
        String,
    )
    source_data_2026 = source_spec
    for heading in (
        "# ## How to read the tables",
        "# ## Inputs and assumptions workbook",
        "# ## Electric-vehicle workbook",
        "# ## Generation and storage outlook",
        "# ## Model and trace files",
        "# ## Compare editions",
    )
        @test occursin(heading, source_data_2024)
        @test occursin(heading, source_data_2026)
    end
    @test occursin("column_labels = [\"Source\", \"File and selection\", \"Keys\", \"Fields and units\"]", source_data_2024)
    @test occursin("column_labels = [\"Source\", \"File and selection\", \"Keys\", \"Fields and units\"]", source_data_2026)
    @test !occursin("Build input contract", source_data_2024)
    @test !occursin("Source contribution by output table", source_data_2024)

    structure_2024 = read(
        joinpath(TEST_DOCS_DIR, "literate", "isp2024", "validation", "workbook_and_trace_structure.jl"),
        String,
    )
    structure_2026 = source_validation
    for heading in (
        "# ## Workbook structure",
        "# ## Model archive structure",
        "# ## Trace schema",
        "# ## Compare editions",
    )
        @test occursin(heading, structure_2024)
        @test occursin(heading, structure_2026)
    end
    for labels in (
        "column_labels = [\"Source collection\", \"Files\", \"Selections\"]",
        "column_labels = [\"Trace family\", \"File or pattern\", \"Keys\", \"Fields and units\"]",
    )
        @test occursin(labels, structure_2024)
        @test occursin(labels, structure_2026)
    end

    isp2024 = reader_text(read(joinpath(TEST_DOCS_DIR, "src", "editions", "isp2024.md"), String))
    isp2026 = reader_text(read(joinpath(TEST_DOCS_DIR, "src", "editions", "isp2026.md"), String))
    for heading in ("## Raw source data", "## Compare editions")
        @test occursin(heading, isp2024)
        @test occursin(heading, isp2026)
    end
    @test occursin("generated/isp2024/reference/source-data.md", isp2024)
    @test occursin("generated/isp2024/validation/workbook-and-trace-structure.md", isp2024)

    for required in (
        "generated/comparison/references/report-catalogue.md",
        "generated/isp2026/reference/source-data.md",
        "generated/isp2026/validation/workbook-and-trace-structure.md",
        "generated/comparison/analyses/raw-source-comparison.md",
        "generated/comparison/analyses/model-archive-comparison.md",
        "source-material.md",
        "trace-coverage.md",
    )
        @test occursin(required, isp2026)
    end

    trace_coverage = reader_text(read(joinpath(TEST_DOCS_DIR, "src", "editions", "trace-coverage.md"), String))
    @test occursin("2025-inputs-assumptions-and-scenarios-report.pdf#page=234", trace_coverage)
    @test occursin("2025-isp-methodology.pdf#page=40", trace_coverage)
end

@testset "Human-use documentation invariants" begin
    function read_doc(path...)
        text = reader_text(read(joinpath(TEST_DOCS_DIR, "src", path...), String))
        warn_on_prose_candidates(joinpath(path...), text)
        return text
    end

    concepts = read_doc("concepts.md")
    for required in (
        "Demand.id_bus",
        "Generator.id_bus",
        "ESS.id_bus",
        "DER.id_dem",
        "Line.id_bus_from",
        "Line.id_bus_to",
        "Generator.tech",
        "schedule-<year>",
        "1 July",
        "4006",
        "candidate development path (CDP)",
        "optimal development path (ODP)",
        "`CDP14`",
        "`CDP 4`",
        "ParseISP currently filters relevant ISP 2024 generation and storage outlook reads",
        "a6-cost-benefit-analysis.pdf#page=16",
        "a6-cost-benefit-analysis.pdf#page=124",
        "a6-cost-benefit-analysis.pdf#page=162",
        "a6-cost-benefit-analysis.pdf#page=165",
        "a6-cost-benefit-analysis.pdf#page=166",
        "## ISP 2024 reference-weather traces",
        "## ISP 2024 demand probability of exceedance",
        "`reftrace = 2017`",
        "does not select a candidate or optimal development path",
        "10% chance that the year's peak demand exceeds",
        "generated/shared/tutorials/selecting-raw-isp-material.md",
        "generated/isp2024/tutorials/working-with-pisp-outputs.md",
    )
        @test occursin(required, concepts)
    end
    @test occursin("rooftop PV is represented in `Generator`", concepts)
    @test occursin("storage is represented in `ESS`", concepts)

    assumptions = read_doc("assumptions.md")
    for required in (
        "problem_type = \"UC\"",
        "seasonal or year-by-year outage-rate schedules",
        "Rooftop PV",
        "write_traces",
        "check_exist_trace",
        "checksums",
    )
        @test occursin(required, assumptions)
    end

    isp2026 = read_doc("editions", "isp2026.md")
    @test occursin("https://github.com/airampg/ParseISP.jl", isp2026)

    source_material = read_doc("editions", "source-material.md")
    for required in (
        "AEMO source data -> ParseISP transformation -> ParseISP datasets",
        "A2, A3, A4, A6, and A7",
        "2023 IASR EV workbook",
        "2025 IASR EV workbook",
        "`Auxiliary`",
        "coverage-and-ownership.md",
        "raw-source-comparison.md",
        "Hydro inflows and energy constraints",
    )
        @test occursin(required, source_material)
    end

    source_coverage = read_doc(
        "generated",
        "shared",
        "source-material",
        "coverage-and-ownership.md",
    )
    for required in (
        "# AEMO ISP source coverage and ownership",
        "Source-read classifications",
        "ParseISP-generated intermediates",
        "Parameter-file ownership",
        "Mapping-family ownership",
    )
        @test occursin(required, source_coverage)
    end
    @test occursin("docs/config/source-material-coverage.toml", source_coverage)
    @test !occursin("docs/source-material-coverage.toml", source_coverage)

    mappings = read_doc("editions", "parameters-and-mappings.md")
    @test occursin("$(length(ParseISP.NEMBUSNAME)) package bus aliases", mappings)
    for required in (
        "`1`, `2`, and `3`",
        "ParseISP.ISPdatabuilder.DATE_RANGES_REFYEARS",
        "problem-table and build-out paths",
        "source coverage and ownership",
        "Report-defined mappings",
        "Workbook-derived values",
        "Package-defined defaults",
        "ISP 2024 build-out defaults",
        "ISP 2024 hydro parameters and constants",
    )
        @test occursin(required, mappings)
    end

    generated_mappings = read_doc(
        "generated",
        "isp2024",
        "reference",
        "parameters-and-mappings.md",
    )
    @test occursin("2024 ISP PLEXOS Model Instructions, p. 6", generated_mappings)
    @test occursin("ending year", generated_mappings)
    @test occursin("2024-isp-plexos-model-instructions.pdf#page=5", generated_mappings)
    @test occursin("2024-isp-plexos-model-instructions.pdf#page=6", generated_mappings)
    @test occursin("4006 demand builder", generated_mappings)
    @test occursin("`ParseISPparameters.jl` includes six parameter files", generated_mappings)
    @test !occursin("second handwritten copy", generated_mappings)
    @test occursin("Reference Year and VRE Reference Year", generated_mappings)
    @test occursin("ParseISP.ISPdatabuilder.DATE_RANGES_REFYEARS", generated_mappings)
    @test !occursin("ParseISP.WEATHER_YEARS_ISP", generated_mappings)

    renewable_energy_zones = read_doc(
        "generated",
        "shared",
        "source-material",
        "renewable-energy-zones.md",
    )

    generated_4006_mapping = read_doc(
        "generated",
        "isp2024",
        "analyses",
        "reference-trace-4006-composite-mapping.md",
    )
    @test occursin("ParseISP.ISPdatabuilder.DATE_RANGES_REFYEARS", generated_4006_mapping)
    @test !occursin("ParseISP.WEATHER_YEARS_ISP", generated_4006_mapping)

    hydro_parameters = read_doc(
        "generated",
        "isp2024",
        "reference",
        "hydro-parameters-and-constants.md",
    )
    for required in (
        "# ISP 2024: Hydro parameters and constants",
        "HYDRO2FILE",
        "HYDRO2CNS",
        "WEATHER_YEARS",
        "DAM_SHARES",
        "HYDRO_DAMS_GENS",
        "SNOWY_HYDRO_GROUPS",
        "HYDRO_DAMS_STORAGE",
        "HYDRO_STORAGE_GEN",
        "2023-inputs-assumptions-and-scenarios-report.pdf#page=97",
        "2023-inputs-assumptions-and-scenarios-report.pdf#page=98",
        "2023-inputs-assumptions-and-scenarios-report.pdf#page=99",
        "Hydro inflow variability across reference weather years – Snowy Hydro",
        "generator and storage inflow schedules",
    )
        @test occursin(required, hydro_parameters)
    end

    comparison = read_doc("editions", "comparison.md")
    for required in (
        "raw-source comparison",
        "non-trace inputs and assumptions workbooks",
        "model archive comparison",
        "scenario directories",
    )
        @test occursin(required, comparison)
    end
    @test occursin("trace-coverage.md", comparison)
    @test occursin("parameters-and-mappings.md", comparison)


    raw_source_comparison = read_doc(
        "generated",
        "comparison",
        "analyses",
        "raw-source-comparison.md",
    )
    for required in (
        "# ISP 2024 and ISP 2026 raw-source comparison",
        "Publication scale",
        "Worksheet presence",
        "Declared worksheet dimensions",
        "Semantic source-family changes",
    )
        @test occursin(required, raw_source_comparison)
    end

    model_archive_comparison = read_doc(
        "generated",
        "comparison",
        "analyses",
        "model-archive-comparison.md",
    )
    for required in (
        "Progressive Change",
        "Slower Growth",
        "Green Energy Exports",
        "Accelerated Transition",
        "PLEXOS solver parameters",
        "345",
        "DNSP",
        "Rooftop PV",
        "2025-inputs-assumptions-and-scenarios-report.pdf#page=20",
        "wind, solar, and timeslice",
        "CSV schemas",
        "model-XML references",
    )
        @test occursin(required, model_archive_comparison)
    end

    trace_coverage = read_doc("editions", "trace-coverage.md")
    for required in ("14 historical reference years", "16 for 2026", "DNSP", "probability of exceedance")
        @test occursin(required, trace_coverage)
    end

    download_layout = read_doc("generated", "shared", "reference", "pisp-downloads-layout.md")
    for required in (
        "Core/ or Core scenarios/",
        "ParseISP-generated intermediates",
        "Extracted outlook directories",
        "2024-isp-generation-and-storage-outlook.zip",
        "2026-isp-generation-and-storage-outlook.zip",
    )
        @test occursin(required, download_layout)
    end

    supported_editions = read_doc("editions", "supported-editions.md")
    for required in (
        "ParseISP.download_ISP26_reports",
        "ParseISP.download_isp2026_assets",
        "ParseISP.ISPdatabuilder.extract_downloads",
        "ParseISP.jl",
        "ParseISP.build_ISP24_datasets",
        "| Report and source download |",
        "| Archive extraction |",
        "| Parser development |",
        "| ParseISP.jl parser integration |",
        "| Build a ParseISP dataset |",
        "| Generated-output contract |",
        "| Published validation evidence |",
        "| Published analysis or EDA evidence |",
        "Not yet integrated",
        "Not yet established",
        "Under review",
    )
        @test occursin(required, supported_editions)
    end
end

@testset "Literate executable narrative structure" begin
    read_literate(path...) = read(joinpath(TEST_DOCS_DIR, "literate", path...), String)
    function position(needle, source)
        match = findfirst(needle, source)
        match === nothing && error("missing source marker: $needle")
        return first(match)
    end

    layout = read_literate("shared", "reference", "pisp_downloads_layout.jl")
    source_contract_validation = read_literate(
        "isp2026",
        "validation",
        "workbook_and_trace_structure.jl",
    )
    archive_comparison = read_literate("comparison", "analysis", "model_archive_comparison.jl")

    for source in (layout, source_contract_validation, archive_comparison)
        hidden_lines = filter(line -> occursin("#hide", line), split(source, '\n'))
        @test !isempty(hidden_lines)
        @test all(line -> strip(line) == "nothing #hide", hidden_lines)
    end

    @test position("download_layouts =", layout) >
        position("# ## Observed outlook directories and source archives", layout)
    @test position("workbook_structure = DataFrame", source_contract_validation) >
        position("# ## Workbook structure", source_contract_validation)
    @test position("model_structure = DataFrame", source_contract_validation) >
        position("# ## Model archive structure", source_contract_validation)

    @test !occursin("const RECORDS", archive_comparison)
    for (selection, heading) in (
        ("archive_records =", "# ## Archive overview"),
        ("scenario_records_2024 =", "# ## Scenario continuity"),
        ("xml_records =", "# ## XML packaging"),
        ("trace_records_2024 =", "# ## Trace families inside the model ZIPs"),
        ("filename_records =", "# ## Representative filenames"),
        ("verification_records =", "# ## Verification"),
    )
        @test position(selection, archive_comparison) > position(heading, archive_comparison)
    end
end

@testset "Downloaded source layout filtering" begin
    mktempdir() do root
        for directory in (
            "Core",
            "Sensitivities",
            "Auxiliary",
            "Traces",
            "2024 ISP Model",
            "manifests",
            "zip",
            "__MACOSX",
        )
            mkpath(joinpath(root, directory))
        end
        write(joinpath(root, "zip", "2024-isp-model.zip"), "model")
        write(joinpath(root, "zip", "2024-isp-generation-and-storage-outlook.zip"), "outlook")
        mkpath(joinpath(root, "zip", "Traces"))
        write(joinpath(root, "zip", "Traces", "2024-isp-solar-traces.zip"), "trace")

        @test ParseISPDocUtils.outlook_directories(root) == ["Core", "Sensitivities"]
        @test ParseISPDocUtils.source_archives(root) == [
            "2024-isp-generation-and-storage-outlook.zip",
            "2024-isp-model.zip",
        ]
    end
end

function fixture_page(
    ;
    id,
    title="Fixture $(id)",
    kind="reference",
    track="isp2024",
    editions=["2024"],
    data_layer="source-data",
    source="literate/fixture/$(id).jl",
    output="generated/fixture/$(id).md",
    status="published",
    nav_order=10,
    snapshot=false,
    data_requirements=nothing,
    extra_fields="",
)
    edition_values = join(repr.(editions), ", ")
    requirement_line = data_requirements === nothing ? "" : "\ndata_requirements = $(data_requirements)"
    block = """
    [[page]]
    id = "$(id)"
    title = "$(title)"
    kind = "$(kind)"
    track = "$(track)"
    editions = [$(edition_values)]
    data_layer = "$(data_layer)"
    source = "$(source)"
    output = "$(output)"
    status = "$(status)"
    nav_order = $(nav_order)
    snapshot = $(snapshot)$(requirement_line)$(extra_fields)
    """
    return (; id, source, output, status, block)
end

function with_registry_fixture(callback::Function, pages; generated_outputs=String[])
    mktempdir() do repo_root
        docs_dir = joinpath(repo_root, "docs")
        registry_path = joinpath(docs_dir, "config", "page-registry.toml")

        for page in pages
            source_path = joinpath(docs_dir, page.source)
            mkpath(dirname(source_path))
            write(source_path, "# fixture Literate source\n")
        end

        for output in generated_outputs
            output_path = joinpath(docs_dir, "src", output)
            mkpath(dirname(output_path))
            write(output_path, "# fixture generated output\n")
        end

        mkpath(dirname(registry_path))
        write(registry_path, join((page.block for page in pages), "\n"))
        return callback(registry_path, repo_root)
    end
end

function preflight_page(requirements)
    return PageSpec(
        id="preflight-page",
        title="Preflight fixture",
        kind="reference",
        track="isp2024",
        editions=["2024"],
        data_layer="source-data",
        source="literate/fixture/preflight.jl",
        output="generated/fixture/preflight.md",
        status="published",
        nav_order=10,
        snapshot=false,
        data_requirements=requirements,
    )
end

function renderer_page(
    ;
    id,
    track,
    editions,
    status,
    kind="reference",
    data_layer="source-data",
    nav_order=10,
)
    return PageSpec(
        id=id,
        title="Renderer $(id)",
        kind=kind,
        track=track,
        editions=editions,
        data_layer=data_layer,
        source="literate/fixture/$(id).jl",
        output="generated/fixture/$(id).md",
        status=status,
        nav_order=nav_order,
        snapshot=false,
    )
end

function with_environment(callback::Function, overrides::Pair...)
    keys = String[first(override) for override in overrides]
    previous = Dict(key => get(ENV, key, nothing) for key in keys)

    try
        for override in overrides
            key, value = override
            if value === nothing
                haskey(ENV, key) && delete!(ENV, key)
            else
                ENV[key] = value
            end
        end
        return callback()
    finally
        for key in keys
            value = previous[key]
            if value === nothing
                haskey(ENV, key) && delete!(ENV, key)
            else
                ENV[key] = value
            end
        end
    end
end

@testset "ParseISP documentation page registry" begin
    @testset "status semantics and published generated outputs" begin
        published = fixture_page(id="published", nav_order=10)
        draft = fixture_page(id="draft", status="draft", nav_order=20)
        archived = fixture_page(id="archived", status="archived", nav_order=10)
        pages = [published, draft, archived]

        with_registry_fixture(pages; generated_outputs=[published.output]) do registry_path, _
            loaded = load_page_registry(registry_path; require_published_outputs=true)
            by_id = Dict(page.id => page for page in loaded)

            @test is_published(by_id["published"])
            @test !is_draft(by_id["published"])
            @test is_renderable(by_id["published"])
            @test is_draft(by_id["draft"])
            @test !is_published(by_id["draft"])
            @test is_renderable(by_id["draft"])
            @test !is_renderable(by_id["archived"])
        end

        with_registry_fixture([published]) do registry_path, _
            @test_throws ErrorException load_page_registry(
                registry_path;
                require_published_outputs=true,
            )
        end

        with_registry_fixture([draft]) do registry_path, _
            loaded = load_page_registry(registry_path; require_published_outputs=true)
            @test only(loaded).status == "draft"
        end
    end

    @testset "track and edition rules" begin
        shared = fixture_page(id="shared", track="shared", editions=String[])
        isp2024 = fixture_page(id="isp2024", track="isp2024", editions=["2024"])
        isp2026 = fixture_page(id="isp2026", track="isp2026", editions=["2026"])
        comparison = fixture_page(
            id="comparison",
            track="comparison",
            editions=["2024", "2026"],
        )
        valid_pages = [shared, isp2024, isp2026, comparison]

        with_registry_fixture(valid_pages; generated_outputs=[page.output for page in valid_pages]) do registry_path, _
            loaded = load_page_registry(registry_path; require_published_outputs=true)
            @test length(loaded) == 4
        end

        invalid_pages = [
            fixture_page(id="unknown-track", track="unsupported", editions=String[]),
            fixture_page(id="wrong-2024", track="isp2024", editions=["2026"]),
            fixture_page(id="wrong-2026", track="isp2026", editions=["2024"]),
            fixture_page(id="one-edition-comparison", track="comparison", editions=["2024"]),
            fixture_page(id="unknown-edition", track="shared", editions=["2030"]),
            fixture_page(
                id="duplicate-editions",
                track="comparison",
                editions=["2024", "2024"],
            ),
        ]

        for invalid_page in invalid_pages
            with_registry_fixture([invalid_page]) do registry_path, _
                @test_throws ErrorException load_page_registry(registry_path)
            end
        end
    end

    @testset "unsupported page fields are rejected" begin
        page = fixture_page(
            id="unsupported-field",
            extra_fields="\nexternal_step = \"script.jl\"",
        )
        with_registry_fixture([page]) do registry_path, _
            @test_throws ErrorException load_page_registry(registry_path)
        end
    end

    @testset "navigation positions are scoped to track and kind" begin
        first_page = fixture_page(id="first", nav_order=10)
        duplicate_page = fixture_page(id="duplicate", nav_order=10)
        with_registry_fixture([first_page, duplicate_page]) do registry_path, _
            @test_throws ErrorException load_page_registry(registry_path)
        end

        isp2024 = fixture_page(id="isp2024-position", track="isp2024", editions=["2024"])
        isp2026 = fixture_page(id="isp2026-position", track="isp2026", editions=["2026"])
        with_registry_fixture([isp2024, isp2026]) do registry_path, _
            loaded = load_page_registry(registry_path)
            @test length(loaded) == 2
        end
    end

    @testset "typed data requirement parsing" begin
        valid_repo_requirement = fixture_page(
            id="valid-repo-requirement",
            data_requirements="[{ root = \"repo\", path = \"README.md\", type = \"file\" }]",
        )
        with_registry_fixture([valid_repo_requirement]) do registry_path, _
            loaded = load_page_registry(registry_path)
            requirement = only(only(loaded).data_requirements)
            @test requirement.root == "repo"
            @test requirement.edition === nothing
            @test requirement.type == "file"
        end

        invalid_requirements = [
            "[{ root = \"unknown\", edition = \"2024\", path = \"file.txt\", type = \"file\" }]",
            "[{ root = \"download\", edition = \"2024\", path = \"file.txt\", type = \"unknown\" }]",
            "[{ root = \"download\", edition = \"2030\", path = \"file.txt\", type = \"file\" }]",
            "[{ root = \"download\", edition = \"2026\", path = \"file.txt\", type = \"file\" }]",
            "[{ root = \"repo\", edition = \"2024\", path = \"file.txt\", type = \"file\" }]",
            "[{ root = \"download\", path = \"file.txt\", type = \"file\" }]",
            "[{ root = \"repo\", path = \"../outside.txt\", type = \"file\" }]",
            "[{ root = \"repo\", path = \"/tmp/outside.txt\", type = \"file\" }]",
        ]

        for (index, requirement) in enumerate(invalid_requirements)
            page = fixture_page(id="invalid-requirement-$(index)", data_requirements=requirement)
            with_registry_fixture([page]) do registry_path, _
                @test_throws ErrorException load_page_registry(registry_path)
            end
        end
    end

    @testset "data requirement preflight types and roots" begin
        fixture = fixture_page(
            id="preflight-registry-page",
            data_requirements="""
          [
              { root = \"repo\", path = \"repo-file.txt\", type = \"file\" },
              { root = \"repo\", path = \"repo-directory\", type = \"directory\" },
              { root = \"repo\", path = \"repo-file.txt\", type = \"path\" },
              { root = \"download\", edition = \"2024\", path = \"download-file.txt\", type = \"file\" },
              { root = \"download\", edition = \"2024\", path = \"download-directory\", type = \"directory\" },
              { root = \"output\", edition = \"2024\", path = \"output-file.txt\", type = \"path\" },
              { root = \"output\", edition = \"2024\", path = \"output-directory\", type = \"path\" },
          ]
          """,
        )

        with_registry_fixture([fixture]) do registry_path, repo_root
            download_root = joinpath(repo_root, "download")
            output_root = joinpath(repo_root, "output")
            mkpath(joinpath(repo_root, "repo-directory"))
            mkpath(joinpath(download_root, "download-directory"))
            mkpath(joinpath(output_root, "output-directory"))
            write(joinpath(repo_root, "repo-file.txt"), "fixture\n")
            write(joinpath(download_root, "download-file.txt"), "fixture\n")
            write(joinpath(output_root, "output-file.txt"), "fixture\n")

            page = only(load_page_registry(registry_path))
            profiles = Dict("2024" => (; download_root, output_root))
            resolved = validate_data_requirements(
                page;
                repo_root,
                profile_for=edition -> profiles[edition],
            )
            @test length(resolved) == 7
            @test all(ispath, resolved)

            missing_download = preflight_page([
                DataRequirement("download", "2024", "missing.txt", "file"),
            ])
            @test_throws ErrorException validate_data_requirements(
                missing_download;
                repo_root,
                profile_for=edition -> profiles[edition],
            )

            missing_download_root = Dict(
                "2024" => (; download_root=joinpath(repo_root, "missing-download"), output_root),
            )
            download_requirement = preflight_page([
                DataRequirement("download", "2024", "download-file.txt", "file"),
            ])
            @test_throws ErrorException validate_data_requirements(
                download_requirement;
                repo_root,
                profile_for=edition -> missing_download_root[edition],
            )

            no_output_root = Dict("2024" => (; download_root, output_root=nothing))
            output_requirement = preflight_page([
                DataRequirement("output", "2024", "output-file.txt", "file"),
            ])
            @test_throws ErrorException validate_data_requirements(
                output_requirement;
                repo_root,
                profile_for=edition -> no_output_root[edition],
            )

            wrong_directory_type = preflight_page([
                DataRequirement("download", "2024", "download-file.txt", "directory"),
            ])
            @test_throws ErrorException validate_data_requirements(
                wrong_directory_type;
                repo_root,
                profile_for=edition -> profiles[edition],
            )

            wrong_file_type = preflight_page([
                DataRequirement("download", "2024", "download-directory", "file"),
            ])
            @test_throws ErrorException validate_data_requirements(
                wrong_file_type;
                repo_root,
                profile_for=edition -> profiles[edition],
            )
        end
    end

    @testset "renderer selection respects status and track" begin
        pages = [
            renderer_page(
                id="shared-published",
                track="shared",
                editions=String[],
                status="published",
            ),
            renderer_page(
                id="isp2024-published",
                track="isp2024",
                editions=["2024"],
                status="published",
            ),
            renderer_page(
                id="isp2024-draft",
                track="isp2024",
                editions=["2024"],
                status="draft",
                nav_order=20,
            ),
            renderer_page(
                id="isp2024-archived",
                track="isp2024",
                editions=["2024"],
                status="archived",
                nav_order=30,
            ),
        ]

        with_environment(
            "ParseISP_LITERATE_PAGES" => nothing,
            "ParseISP_LITERATE_SET" => nothing,
            "ParseISP_DOCS_TRACK" => nothing,
        ) do
            @test [page.id for page in select_pages(pages)] == [
                "shared-published",
                "isp2024-published",
            ]
        end

        with_environment(
            "ParseISP_LITERATE_PAGES" => nothing,
            "ParseISP_LITERATE_SET" => "published",
            "ParseISP_DOCS_TRACK" => "isp2024",
        ) do
            @test [page.id for page in select_pages(pages)] == ["isp2024-published"]
        end

        with_environment(
            "ParseISP_LITERATE_PAGES" => nothing,
            "ParseISP_LITERATE_SET" => "draft",
            "ParseISP_DOCS_TRACK" => "isp2024",
        ) do
            @test [page.id for page in select_pages(pages)] == ["isp2024-draft"]
        end

        with_environment(
            "ParseISP_LITERATE_PAGES" => "isp2024-archived",
            "ParseISP_LITERATE_SET" => nothing,
            "ParseISP_DOCS_TRACK" => nothing,
        ) do
            @test_throws ErrorException select_pages(pages)
        end

        with_environment(
            "ParseISP_LITERATE_PAGES" => "isp2024-published",
            "ParseISP_LITERATE_SET" => "all",
            "ParseISP_DOCS_TRACK" => nothing,
        ) do
            @test_throws ErrorException select_pages(pages)
        end

        with_environment(
            "ParseISP_LITERATE_PAGES" => "isp2024-published",
            "ParseISP_LITERATE_SET" => nothing,
            "ParseISP_DOCS_TRACK" => "isp2024",
        ) do
            @test_throws ErrorException select_pages(pages)
        end
    end

    @testset "edition navigation from published registry pages" begin
        pages = [
            renderer_page(
                id="shared-source-first",
                track="shared",
                editions=["2024", "2026"],
                status="published",
                nav_order=10,
            ),
            renderer_page(
                id="shared-source-later",
                track="shared",
                editions=["2024", "2026"],
                status="published",
                nav_order=20,
            ),
            renderer_page(
                id="shared-source-draft",
                track="shared",
                editions=["2024", "2026"],
                status="draft",
                nav_order=30,
            ),
            renderer_page(
                id="isp2024-reference-later",
                track="isp2024",
                editions=["2024"],
                status="published",
                nav_order=20,
            ),
            renderer_page(
                id="isp2024-reference-first",
                track="isp2024",
                editions=["2024"],
                status="published",
                nav_order=10,
            ),
            renderer_page(
                id="isp2024-tutorial",
                track="isp2024",
                editions=["2024"],
                status="published",
                kind="tutorial",
            ),
            renderer_page(
                id="isp2024-validation",
                track="isp2024",
                editions=["2024"],
                status="published",
                kind="validation",
            ),
            renderer_page(
                id="isp2024-analysis",
                track="isp2024",
                editions=["2024"],
                status="published",
                kind="analysis",
            ),
            renderer_page(
                id="isp2024-draft",
                track="isp2024",
                editions=["2024"],
                status="draft",
                nav_order=30,
            ),
            renderer_page(
                id="isp2024-archived",
                track="isp2024",
                editions=["2024"],
                status="archived",
                nav_order=40,
            ),
            renderer_page(
                id="comparison-source-data",
                track="comparison",
                editions=["2024", "2026"],
                status="published",
                kind="analysis",
                data_layer="source-data",
                nav_order=20,
            ),
            renderer_page(
                id="comparison-pisp-dataset",
                track="comparison",
                editions=["2024", "2026"],
                status="published",
                kind="reference",
                data_layer="pisp-dataset",
                nav_order=10,
            ),
            renderer_page(
                id="comparison-package-workflow-draft",
                track="comparison",
                editions=["2024", "2026"],
                status="draft",
                data_layer="package-workflow",
                nav_order=10,
            ),
            renderer_page(
                id="comparison-cross-layer-archived",
                track="comparison",
                editions=["2024", "2026"],
                status="archived",
                data_layer="cross-layer",
                nav_order=10,
            ),
        ]
        navigation = registry_navigation(pages)

        @test first.(navigation) == [
            "Home",
            "Quickstart",
            "Understand ParseISP and ISP data",
            "ISP 2024",
            "ISP 2026",
            "Compare ISP 2024 and ISP 2026",
            "Contributing",
            "API Reference",
        ]

        navigation_by_title = Dict(first(entry) => last(entry) for entry in navigation)
        @test navigation_by_title["Contributing"] == "contributing.md"

        shared_material = navigation_by_title["Understand ParseISP and ISP data"]
        @test first.(shared_material) == [
            "ISP source data",
            "ParseISP transformation",
            "ParseISP datasets",
        ]
        @test first.(last(shared_material[1])) == [
            "Source material by edition",
            "Renderer shared-source-first",
            "Renderer shared-source-later",
            "Trace families and source meaning",
        ]
        @test last.(last(shared_material[1])) == [
            "editions/source-material.md",
            "generated/fixture/shared-source-first.md",
            "generated/fixture/shared-source-later.md",
            "editions/trace-coverage.md",
        ]
        @test !occursin("shared-source-draft", repr(shared_material))
        @test first.(last(shared_material[2])) == [
            "Workflow support by edition",
            "Source-to-dataset processing",
            "Parameters, mappings, and constants",
        ]
        @test last.(last(shared_material[2])) == [
            "editions/supported-editions.md",
            "editions/source-inventory.md",
            "editions/parameters-and-mappings.md",
        ]
        @test first.(last(shared_material[3])) == [
            "Assets, relationships, and schedules",
            "Output tables, fields, and units",
            "Dataset interpretation and study bounds",
        ]
        @test last.(last(shared_material[3])) == [
            "concepts.md",
            "editions/output-data-model.md",
            "assumptions.md",
        ]

        isp2024_navigation = navigation_by_title["ISP 2024"]
        @test first.(isp2024_navigation) == [
            "Overview",
            "Preprocessing workflow",
            "Reference and inputs",
            "Tutorials",
            "Data validation",
            "Analyses and case studies",
        ]
        @test last(isp2024_navigation[1]) == "editions/isp2024.md"
        @test last(isp2024_navigation[2]) == "editions/isp2024-preprocessing.md"
        @test first.(last(isp2024_navigation[3])) == [
            "Renderer isp2024-reference-first",
            "Renderer isp2024-reference-later",
        ]
        @test last.(last(isp2024_navigation[3])) == [
            "generated/fixture/isp2024-reference-first.md",
            "generated/fixture/isp2024-reference-later.md",
        ]
        @test first.(last(isp2024_navigation[4])) == ["Renderer isp2024-tutorial"]
        @test first.(last(isp2024_navigation[5])) == ["Renderer isp2024-validation"]
        @test first.(last(isp2024_navigation[6])) == ["Renderer isp2024-analysis"]
        @test !occursin("draft", repr(isp2024_navigation))
        @test !occursin("archived", repr(isp2024_navigation))

        isp2026_navigation = navigation_by_title["ISP 2026"]
        @test isp2026_navigation == Any["Overview"=>"editions/isp2026.md"]

        comparison_navigation = navigation_by_title["Compare ISP 2024 and ISP 2026"]
        @test comparison_navigation == Any[
            "Overview and comparison rules"=>"editions/comparison.md",
            "ISP source data"=>Any[
                "Renderer comparison-source-data"=>
                    "generated/fixture/comparison-source-data.md",
            ],
            "ParseISP datasets"=>Any[
                "Renderer comparison-pisp-dataset"=>
                    "generated/fixture/comparison-pisp-dataset.md",
            ],
        ]
        @test !occursin("package-workflow-draft", repr(comparison_navigation))
        @test !occursin("cross-layer-archived", repr(comparison_navigation))
    end

    @testset "every published page is nav-reachable" begin
        function flatten_nav_outputs(navigation)
            outputs = String[]
            for (_, value) in navigation
                if value isa AbstractString
                    push!(outputs, value)
                else
                    append!(outputs, flatten_nav_outputs(value))
                end
            end
            return outputs
        end

        # Sanity-check the assertion mechanism itself: a published page whose
        # kind has no entry in its track's KIND_LABELS is never selected by
        # track_sections, so it must be detected as unreachable.
        reachable_pages = [
            renderer_page(id="covered-page", track="isp2024", editions=["2024"], status="published"),
        ]
        reachable_outputs = Set(flatten_nav_outputs(registry_navigation(reachable_pages)))
        @test reachable_pages[1].output in reachable_outputs

        orphan_pages = [
            renderer_page(
                id="orphan-page",
                track="isp2024",
                editions=["2024"],
                status="published",
                kind="unregistered-kind",
            ),
        ]
        orphan_outputs = Set(flatten_nav_outputs(registry_navigation(orphan_pages)))
        @test !(orphan_pages[1].output in orphan_outputs)

        # Shared source-data pages are placed dynamically in registry order.
        shared_track_pages = [
            renderer_page(
                id="future-shared-page",
                track="shared",
                editions=["2024", "2026"],
                status="published",
                kind="reference",
            ),
        ]
        shared_track_outputs = Set(flatten_nav_outputs(registry_navigation(shared_track_pages)))
        @test shared_track_pages[1].output in shared_track_outputs

        # The real registry: every published page's output must appear
        # somewhere in the rendered navigation tree.
        real_pages = load_page_registry(
            joinpath(TEST_DOCS_DIR, "config", "page-registry.toml");
            require_published_outputs=true,
            check_generated_outputs=true,
        )
        real_outputs = Set(flatten_nav_outputs(registry_navigation(real_pages)))
        for page in real_pages
            is_published(page) || continue
            @test page.output in real_outputs
        end
    end
end

include(joinpath(@__DIR__, "test_source_links.jl"))

@testset "Generated documentation does not leak stray auto-displayed values" begin
    generated_root = joinpath(TEST_DOCS_DIR, "src", "generated")
    home = homedir()
    for (directory, _, files) in walkdir(generated_root)
        for filename in files
            endswith(filename, ".md") || continue
            path = joinpath(directory, filename)
            content = read(path, String)
            @test !occursin(home, content)
            @test !occursin(r"\n````\n(true|false)\n````", content)
        end
    end
end
