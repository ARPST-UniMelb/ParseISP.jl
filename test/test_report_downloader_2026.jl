# ISP 2026 report downloader: target catalogue plus download / skip-existing /
# overwrite / failure handling (mocked download function, no network).

@testset "ISP 2026 report downloader" begin
    core = ParseISP.ISPReportDownloader
    report_downloader = ParseISP.ISP2026ReportDownloader
    targets = report_downloader.report_targets()
    expected_targets = [
        (:integrated_system_plan, "2026 Integrated System Plan", "2026-integrated-system-plan.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/2026-integrated-system-plan-isp.pdf?rev=7f5dfd18aa1b4a3aab704c424f75afd3&sc_lang=en"),
        (:plexos_model_instructions, "2026 ISP PLEXOS Model Instructions", "2026-isp-plexos-model-instructions.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/isp-model/2026-isp-plexos-model-instructions.pdf?la=en"),
        (:iasr_2025, "2025 Inputs, Assumptions and Scenarios Report", "2025-inputs-assumptions-and-scenarios-report.pdf", "https://www.aemo.com.au/-/media/files/stakeholder_consultation/consultations/nem-consultations/2024/2025-iasr-scenarios/final-docs/2025-inputs-assumptions-and-scenarios-report.pdf?rev=63268acd3f044adb9f5f3a32b6880c27&sc_lang=en"),
        (:iasr_2025_addendum, "Addendum to the 2025 Inputs, Assumptions and Scenarios Report", "addendum-to-2025-inputs-assumptions-and-scenarios-report.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/draft-2026/addendum-to-the-2025-inputs-assumptions-and-scenarios-report.pdf"),
        (:isp_methodology_2025, "ISP Methodology (June 2025)", "2025-isp-methodology.pdf", "https://www.aemo.com.au/-/media/files/stakeholder_consultation/consultations/nem-consultations/2024/2026-isp-methodology/isp-methodology-june-2025.pdf"),
        (:appendix_a2_generation_storage, "A2 ISP Development Opportunities", "a2-isp-development-opportunities.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/appendices/a2-isp-development-opportunities.pdf?rev=d81062e7cdcf4af8a04fbccdfc3c9fb4&sc_lang=en"),
        (:appendix_a3_rez, "A3 Renewable Energy Zones", "a3-renewable-energy-zones.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/appendices/a3-renewable-energy-zones.pdf?la=en"),
        (:appendix_a4_operability, "A4 System Operability", "a4-system-operability.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/appendices/a4-system-operability.pdf?la=en"),
        (:appendix_a6_cost_benefit, "A6 Cost Benefit Analysis", "a6-cost-benefit-analysis.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/appendices/a6-cost-benefit-analysis.pdf?la=en"),
        (:appendix_a7_security, "A7 System Security", "a7-system-security.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/appendices/a7-system-security.pdf?la=en"),
        (:integrated_system_plan_explainer, "2026 Integrated System Plan - Explainer", "2026-isp-explainer.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/aemo-2026-isp-explainer.pdf?rev=a1aa113a81194508a1aced90d26b1dd9&sc_lang=en"),
        (:integrated_system_plan_infographic, "2026 Integrated System Plan - Infographic", "2026-isp-infographic.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/2026-integrated-system-plan-infographic.pdf?rev=6568e9e8a4f34f5cb5f28a702d7fb453&sc_lang=en"),
        (:publication_webinar_presentation, "2026 ISP Publication Webinar Presentation", "2026-isp-publication-webinar-presentation.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/2026-isp-publication-webinar-presentation.pdf?rev=5d4743f20aff47699588354c1bfd76cc&sc_lang=en"),
        (:appendix_a1_stakeholder_engagement, "A1 Stakeholder Engagement", "a1-stakeholder-engagement.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/appendices/a1-stakeholder-engagement.pdf?rev=fb67d2dee69042f3885d5f8a649267d6&sc_lang=en"),
        (:appendix_a5_network_investments, "A5 Network Investments", "a5-network-investments.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/appendices/a5-network-investments.pdf?rev=a351f6c817484d79bc34f9a8e817f077&sc_lang=en"),
        (:appendix_a8_social_licence, "A8 Social Licence", "a8-social-licence.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/appendices/a8-social-licence.pdf?rev=035a91c449f44bfc82a888a6770d9f90&sc_lang=en"),
        (:appendix_a9_demand_side_factors, "A9 Demand Side Factors Statement", "a9-demand-side-factors-statement.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/appendices/a9-demand-side-factors-statement.pdf?rev=cfadf873c9934b46aecd670fdcd8995f&sc_lang=en"),
        (:appendix_a10_gas_development, "A10 Gas Development Projections", "a10-gas-development-projections.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/appendices/a10-gas-development-projections.pdf?rev=e204886dac1c4f01a471e239723fb054&sc_lang=en"),
        (:consultation_summary, "2026 ISP Consultation Summary Report", "2026-isp-consultation-summary-report.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2026/supporting-materials/2026-isp-consultation-summary-report.pdf?rev=7982dc7041d4477d988d9f75485846d3&sc_lang=en"),
    ]

    @test isdefined(ParseISP, :download_ISP26_reports)
    @test ParseISP.download_ISP26_reports === report_downloader.download_reports
    @test !isdefined(ParseISP, :download_isp_reports)
    @test !isdefined(ParseISP, :download_isp2026_reports)
    @test targets isa Tuple
    @test [(target.key, target.title, target.filename, target.url) for target in targets] == expected_targets

    mktempdir() do outdir
        for target in targets
            write(joinpath(outdir, target.filename), "%PDF-1.7\nexisting")
        end

        @test ParseISP.download_ISP26_reports(outdir=outdir) === nothing
    end

    mktempdir() do outdir
        target = targets[1]
        destination = joinpath(outdir, target.filename)
        mkpath(outdir)
        write(destination, "%PDF-1.7\nexisting")
        calls = Ref(0)

        result = core.download_report_targets([target];
            outdir=outdir,
            download_function=function (url, path; headers)
                calls[] += 1
                error("a valid existing PDF should be skipped")
            end)

        @test result.paths == [destination]
        @test isempty(result.failures)
        @test calls[] == 0
    end

    mktempdir() do outdir
        target = targets[2]
        destination = joinpath(outdir, target.filename)
        mkpath(outdir)
        write(destination, "not a PDF")
        calls = Ref(0)

        result = core.download_report_targets([target];
            outdir=outdir,
            download_function=function (url, path; headers)
                calls[] += 1
                write(path, "%PDF-1.7\nreplacement")
                return path
            end)

        @test result.paths == [destination]
        @test isempty(result.failures)
        @test calls[] == 1
        @test read(destination, String) == "%PDF-1.7\nreplacement"
    end

    mktempdir() do outdir
        target = targets[3]
        destination = joinpath(outdir, target.filename)
        mkpath(outdir)
        existing = "%PDF-1.7\nexisting"
        write(destination, existing)

        result = @test_logs (:warn, "Failed to download ISP report; continuing with later targets") core.download_report_targets([target];
            outdir=outdir,
            overwrite=true,
            download_function=(url, path; headers) -> write(path, "not a PDF"))
        @test isempty(result.paths)
        @test length(result.failures) == 1
        @test read(destination, String) == existing
    end

    mktempdir() do outdir
        target = targets[4]

        result = @test_logs (:warn, "Failed to download ISP report; continuing with later targets") core.download_report_targets([target];
            outdir=outdir,
            download_function=(url, path; headers) -> error("request failed"))
        @test isempty(result.paths)
        @test length(result.failures) == 1
        @test isempty(readdir(outdir))
    end

    mktempdir() do outdir
        target = targets[5]
        destination = joinpath(outdir, target.filename)
        mkpath(outdir)
        write(destination, "%PDF-1.7\nexisting")
        calls = Ref(0)

        result = core.download_report_targets([target];
            outdir=outdir,
            overwrite=true,
            download_function=function (url, path; headers)
                calls[] += 1
                write(path, "%PDF-1.7\nrefreshed")
                return path
            end)

        @test result.paths == [destination]
        @test isempty(result.failures)
        @test calls[] == 1
        @test read(destination, String) == "%PDF-1.7\nrefreshed"
    end

    mktempdir() do outdir
        failed_target, successful_target = targets[1], targets[2]
        successful_destination = joinpath(outdir, successful_target.filename)

        result = @test_logs (:warn, "Failed to download ISP report; continuing with later targets") core.download_report_targets([failed_target, successful_target];
            outdir=outdir,
            download_function=function (url, path; headers)
                url == failed_target.url && error("temporary upstream failure")
                write(path, "%PDF-1.7\nlater target")
                return path
            end)

        @test result.paths == [successful_destination]
        @test length(result.failures) == 1
        @test result.failures[1].target === failed_target
        @test occursin("temporary upstream failure", result.failures[1].error)
        @test read(successful_destination, String) == "%PDF-1.7\nlater target"
    end
end
