include("scrappers/ParseISP-scrapper-utils.jl")
include("scrappers/ParseISP-scrapper-2024traces.jl")
include("scrappers/ParseISP-scrapper-2024files.jl")
include("scrappers/ParseISP-scrapper-report-core.jl")
include("scrappers/ParseISP-scrapper-2024reports.jl")
include("scrappers/ParseISP-scrapper-2026reports.jl")
include("scrappers/ParseISP-scrapper-2026files.jl")
include("scrappers/ParseISP-scrapper-2026-input-preparation.jl")
include("scrappers/ParseISP-scrapper-build.jl")
using .ISPdatabuilder: build_pipeline
using .ISP2024ReportDownloader: download_reports as download_ISP24_reports
using .ISP2026ReportDownloader: download_reports as download_ISP26_reports
using .ISP2026FileDownloader: download_isp2026_files as download_isp2026_assets
using .ISP2026InputPreparation: prepare_isp2026_inputs

export build_pipeline,
    download_ISP24_reports,
    download_ISP26_reports,
    download_isp2026_assets
