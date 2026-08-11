include("scrappers/ParseISP-scrapper-utils.jl")
include("scrappers/ParseISP-scrapper-2024traces.jl")
include("scrappers/ParseISP-scrapper-2024files.jl")
include("scrappers/ParseISP-scrapper-report-core.jl")
include("scrappers/ParseISP-scrapper-2024reports.jl")
include("scrappers/ParseISP-scrapper-2026reports.jl")
include("scrappers/ParseISP-scrapper-2026files.jl")
include("scrappers/ParseISP-scrapper-2026-preparation.jl")
include("scrappers/ParseISP-scrapper-build.jl")
using .ISPdatabuilder: build_pipeline
using .ISP2024ReportDownloader: download_reports as download_ISP24_reports
using .ISP2026ReportDownloader: download_reports as download_ISP26_reports
using .ISP2026FileDownloader: download_isp2026_files as download_isp2026_assets
using .ISP2026InputPreparation: prepare_isp2026_inputs

"""
    prepare_isp_inputs(edition, root; overwrite)

Prepare on-disk inputs for one supported ISP edition. The dispatch boundary is
shared while each edition retains its own acquisition and extraction algorithm.
"""
function prepare_isp_inputs(edition::Integer, root::AbstractString;
                            overwrite::Bool = edition == 2024)
    edition isa Bool && throw(ArgumentError(
        "Unsupported ISP edition $(repr(edition)); supported editions: 2024, 2026.",
    ))
    if edition == 2024
        return ISPdatabuilder.extract_downloads(
            data_root = root,
            overwrite = overwrite,
        )
    elseif edition == 2026
        return prepare_isp2026_inputs(root; overwrite = overwrite)
    end
    throw(ArgumentError(
        "Unsupported ISP edition $(repr(edition)); supported editions: 2024, 2026.",
    ))
end

export build_pipeline,
    download_ISP24_reports,
    download_ISP26_reports,
    download_isp2026_assets
