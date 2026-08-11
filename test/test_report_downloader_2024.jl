# ISP 2024 report downloader: target catalogue plus download / skip-existing /
# overwrite / failure handling (mocked download function, no network).

@testset "ISP 2024 report downloader" begin
    core = ParseISP.ISPReportDownloader
    report_downloader = ParseISP.ISP2024ReportDownloader
    targets = report_downloader.report_targets()
    expected_targets = [
        (:plexos_model_instructions, "2024 ISP PLEXOS Model Instructions", "2024-isp-plexos-model-instructions.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/supporting-materials/2024-isp-plexos-model-instructions.pdf?la=en"),
        (:integrated_system_plan, "2024 Integrated System Plan", "2024-integrated-system-plan.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/2024-integrated-system-plan-isp.pdf?la=en"),
        (:iasr_2023, "2023 Inputs, Assumptions and Scenarios Report", "2023-inputs-assumptions-and-scenarios-report.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2023/2023-inputs-assumptions-and-scenarios-report.pdf?la=en"),
        (:iasr_2023_addendum, "Addendum to the 2023 Inputs Assumptions and Scenarios Report", "addendum-to-2023-inputs-assumptions-and-scenarios-report.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2023/addendum-to-2023-inputs-assumptions-and-scenarios-report.pdf?la=en"),
        (:isp_methodology_2023, "ISP Methodology (30 June 2023)", "2023-isp-methodology.pdf", "https://www.aemo.com.au/-/media/files/stakeholder_consultation/consultations/nem-consultations/2023/isp-methodology-2023/isp-methodology_june-2023.pdf?la=en"),
        (:appendix_a2_generation_storage, "A2 Generation and Storage Development Opportunities", "a2-generation-and-storage-development-opportunities.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/appendices/a2-generation-and-storage-development-opportunities.pdf?la=en"),
        (:appendix_a3_rez, "A3 Renewable Energy Zones", "a3-renewable-energy-zones.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/appendices/a3-renewable-energy-zones.pdf?rev=12a046694eac41dc99031c43bbce35e0&sc_lang=en"),
        (:appendix_a4_operability, "A4 System Operability", "a4-system-operability.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/appendices/a4-system-operability.pdf?la=en"),
        (:appendix_a6_cost_benefit, "A6 Cost Benefit Analysis", "a6-cost-benefit-analysis.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/appendices/a6-cost-benefit-analysis.pdf?la=en"),
        (:appendix_a7_security, "A7 System Security", "a7-system-security.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/appendices/a7-system-security.pdf?la=en"),
        (:integrated_system_plan_overview, "2024 Integrated System Plan - Overview", "2024-integrated-system-plan-overview.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/2024-integrated-system-plan-overview.pdf?rev=ac883f3706bc449ca4cd64da6cb25175&sc_lang=en"),
        (:publication_webinar_presentation, "2024 ISP Publication Webinar Presentation", "2024-isp-publication-webinar-presentation.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/2024-isp-publication-webinar-presentation.pdf?rev=392d12bc130f48fab67051f86977e939&sc_lang=en"),
        (:appendix_a1_stakeholder_engagement, "A1 Stakeholder Engagement", "a1-stakeholder-engagement.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/appendices/a1-stakeholder-engagement.pdf?rev=21f03a266f854bccb1faa82485de094f&sc_lang=en"),
        (:appendix_a5_network_investments, "A5 Network Investments", "a5-network-investments.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/appendices/a5-network-investments.pdf?rev=330abdf826cd4310a05f16fdeafd98d3&sc_lang=en"),
        (:appendix_a8_social_licence, "A8 Social Licence", "a8-social-licence.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/appendices/a8-social-licence.pdf?rev=ab35f15c9fcf4303a43a3ec4acbb3dca&sc_lang=en"),
        (:consultation_summary, "2024 ISP Consultation Summary Report", "2024-isp-consultation-summary-report.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/supporting-materials/2024-isp-consultation-summary-report.pdf?rev=9e901f2b861843ccbd8673ebb6e7819b&sc_lang=en"),
        (:consumer_risk_preferences_summary, "Summary of Consumer Risk Preferences Project", "summary-of-consumer-risk-preferences-project.pdf", "https://www.aemo.com.au/-/media/files/stakeholder_consultation/consultations/nem-consultations/2023/draft-2024-isp-consultation/supporting-materials/summary-of-consumer-risk-preferences-project.pdf?rev=573eb60f837c4c58bdef452f425da215&sc_lang=en"),
        (:consumer_risk_preferences_deloitte, "Attachment 1 Deloitte Report - Consumer Risk Preferences", "attachment-1-deloitte-report-consumer-risk-preferences.pdf", "https://www.aemo.com.au/-/media/files/stakeholder_consultation/consultations/nem-consultations/2023/draft-2024-isp-consultation/supporting-materials/attachment-1-deloitte-report-consumer-risk-preferences.pdf?rev=ac0acb36290d439cbf3d6c4690ac39f2&sc_lang=en"),
        (:consumer_risk_preferences_antenna, "Attachment 2 Antenna Report - Consumer Risk Preferences", "attachment-2-antenna-report-consumer-risk-preferences.pdf", "https://www.aemo.com.au/-/media/files/stakeholder_consultation/consultations/nem-consultations/2023/draft-2024-isp-consultation/supporting-materials/attachment-2-antenna-report-consumer-risk-preferences.pdf?rev=67c875994d514ff295a22188b07ec078&sc_lang=en"),
        (:delphi_panel_overview, "2024 ISP Delphi Panel - Overview", "2024-isp-delphi-panel-overview.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2023/2024-isp-delphi-panel---overview.pdf?rev=299bd33e7faf43f1b1e5654aadbbe423&sc_lang=en"),
        (:workforce_projections_nem, "The Australian Electricity Workforce for the 2024 ISP: Projections to 2050", "2024-isp-workforce-projections-nem.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/electricity-sector-workforce-projections/nem-2024-workforce_final.pdf?rev=5640af2eadd448cba44f1fb3a61bc9e3&sc_lang=en"),
        (:workforce_projections_nsw, "Electricity Workforce Projections for the 2024 ISP: New South Wales", "2024-isp-workforce-projections-nsw.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/electricity-sector-workforce-projections/focus-on-nsw_2024.pdf?rev=de6545e01db84720b6645356b4dd0053&sc_lang=en"),
        (:workforce_projections_qld, "Electricity Workforce Projections for the 2024 ISP: Queensland", "2024-isp-workforce-projections-qld.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/electricity-sector-workforce-projections/focus-on-qld-2024_final.pdf?rev=7414890c9a684c5db75f64790ff76afb&sc_lang=en"),
        (:workforce_projections_sa, "Electricity Workforce Projections for the 2024 ISP: South Australia", "2024-isp-workforce-projections-sa.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/electricity-sector-workforce-projections/focus-on-sa-2024_final.pdf?rev=4db5b7bfc983460b9c658680693ccb56&sc_lang=en"),
        (:workforce_projections_tas, "Electricity Workforce Projections for the 2024 ISP: Tasmania", "2024-isp-workforce-projections-tas.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/electricity-sector-workforce-projections/focus-on-tas-2024_final.pdf?rev=252f6df93f6a43a79c3df0dff145874d&sc_lang=en"),
        (:workforce_projections_vic, "Electricity Workforce Projections for the 2024 ISP: Victoria", "2024-isp-workforce-projections-vic.pdf", "https://www.aemo.com.au/-/media/files/major-publications/isp/2024/electricity-sector-workforce-projections/focus-on-vic-2024_final.pdf?rev=7f4f554dc25c4dff91e05d896bc76288&sc_lang=en"),
        (:aurecon_2022_cost_and_technical_parameter_review, "Aurecon 2022 Costs and Technical Parameters Review", "aurecon-2022-cost-and-technical-parameter-review.pdf", "https://www.aemo.com.au/-/media/files/stakeholder_consultation/consultations/nem-consultations/2022/2023-inputs-assumptions-and-scenarios-consultation/supporting-materials-for-2023/aurecon-2022-cost-and-technical-parameter-review.pdf"),
    ]

    @test isdefined(ParseISP, :download_ISP24_reports)
    @test ParseISP.download_ISP24_reports === report_downloader.download_reports
    @test !isdefined(ParseISP, :download_isp_reports)
    @test !isdefined(ParseISP, :download_isp2026_reports)
    @test targets isa Tuple
    @test [(target.key, target.title, target.filename, target.url) for target in targets] == expected_targets
    @test all(target -> endswith(lowercase(target.filename), ".pdf"), targets)
    @test all(target -> startswith(target.url, "https://www.aemo.com.au/"), targets)

    mktempdir() do outdir
        for target in targets
            write(joinpath(outdir, target.filename), "%PDF-1.7\nexisting")
        end

        @test ParseISP.download_ISP24_reports(outdir=outdir) === nothing
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
        @test readdir(outdir) == [target.filename]
    end

    mktempdir() do outdir
        target = targets[2]
        destination = joinpath(outdir, target.filename)
        mkpath(outdir)
        write(destination, "not a PDF")
        calls = Ref(0)
        received_headers = Ref{Any}(nothing)

        result = core.download_report_targets([target];
            outdir=outdir,
            download_function=function (url, path; headers)
                calls[] += 1
                received_headers[] = headers
                write(path, "%PDF-1.7\nreplacement")
                return path
            end)

        @test result.paths == [destination]
        @test isempty(result.failures)
        @test calls[] == 1
        @test received_headers[] == ParseISP.ParseISPScrapperUtils.DEFAULT_FILE_HEADERS
        @test read(destination, String) == "%PDF-1.7\nreplacement"
        @test readdir(outdir) == [target.filename]
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
        @test result.failures[1].target === target
        @test occursin("not a non-empty PDF", result.failures[1].error)
        @test read(destination, String) == existing
        @test readdir(outdir) == [target.filename]
    end

    mktempdir() do outdir
        target = targets[4]
        result = @test_logs (:warn, "Failed to download ISP report; continuing with later targets") core.download_report_targets([target];
            outdir=outdir,
            download_function=(url, path; headers) -> error("request failed"))

        @test isempty(result.paths)
        @test length(result.failures) == 1
        @test result.failures[1].target === target
        @test occursin("request failed", result.failures[1].error)
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
        @test readdir(outdir) == [target.filename]
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
