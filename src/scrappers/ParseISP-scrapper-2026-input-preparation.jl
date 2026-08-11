module ISP2026InputPreparation

using ..ISP2026FileDownloader
using ..ParseISPScrapperUtils: extract_zip

export prepare_isp2026_inputs

"""
    prepare_isp2026_inputs(root::AbstractString; overwrite::Bool = false)

Extract the four downloader-owned ISP 2026 archives into their expected locations
beneath `root`. Existing files are retained unless `overwrite = true`.
"""
function prepare_isp2026_inputs(root::AbstractString; overwrite::Bool = false)
    normalized_root = abspath(normpath(root))
    targets = Dict(target.key => target for target in ISP2026FileDownloader.isp_file_targets())
    archive_destinations = (
        (:isp26_outlook, normalized_root),
        (:isp26_model, normalized_root),
        (:isp26_solar_traces, joinpath(normalized_root, "Traces")),
        (:isp26_wind_traces, joinpath(normalized_root, "Traces")),
    )

    for (key, destination) in archive_destinations
        target = targets[key]
        archive = joinpath(normalized_root, target.subdir, target.filename)
        extract_zip(archive, destination; overwrite = overwrite)
    end

    return normalized_root
end

end
