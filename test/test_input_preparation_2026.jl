using ParseISP
using Test

function isp2026_target_path(root::AbstractString, key::Symbol)
    target = only(filter(
        target -> target.key == key,
        ParseISP.ISP2026FileDownloader.isp_file_targets(),
    ))
    return joinpath(root, target.subdir, target.filename)
end

function write_isp2026_test_zip(zip_command::AbstractString, path::AbstractString, entries)
    mktempdir() do staging
        for (name, content) in entries
            destination = joinpath(staging, split(name, '/')...)
            mkpath(dirname(destination))
            write(destination, content)
        end
        mkpath(dirname(path))
        cd(staging) do
            run(`$(zip_command) -q -r $(abspath(path)) .`)
        end
    end
    return path
end

function setup_isp2026_archives(zip_command::AbstractString, root::AbstractString)
    archives = (
        :isp26_outlook => [
            "Core scenarios/2026 ISP - Step Change - Core.xlsx" => "outlook",
        ],
        :isp26_model => [
            "2026 ISP Model/2026 ISP Step Change/2026 ISP Step Change Model.xml" =>
                "<model/>",
        ],
        :isp26_solar_traces => [
            "2026 ISP Solar traces/solar/sample.csv" => "solar",
        ],
        :isp26_wind_traces => [
            "2026 ISP Wind traces/wind/sample.csv" => "wind",
        ],
    )
    for (key, entries) in archives
        write_isp2026_test_zip(zip_command, isp2026_target_path(root, key), entries)
    end
end

@testset "ISP 2026 input preparation" begin
    @test isdefined(ParseISP, :prepare_isp2026_inputs)
    @test :prepare_isp2026_inputs ∉ names(ParseISP)

    zip_command = Sys.which("zip")
    unzip_command = Sys.which("unzip")
    if zip_command === nothing || unzip_command === nothing
        @test_skip "zip/unzip not available in test environment"
    else
        mktempdir() do root
            setup_isp2026_archives(zip_command, root)
            sentinel = joinpath(root, "unrelated.txt")
            write(sentinel, "keep")

            @test ParseISP.prepare_isp2026_inputs(root) == abspath(normpath(root))
            @test read(joinpath(
                root,
                "Core scenarios",
                "2026 ISP - Step Change - Core.xlsx",
            ), String) == "outlook"
            @test isfile(joinpath(
                root,
                "2026 ISP Model",
                "2026 ISP Step Change",
                "2026 ISP Step Change Model.xml",
            ))
            @test read(joinpath(
                root,
                "Traces",
                "2026 ISP Solar traces",
                "solar",
                "sample.csv",
            ), String) == "solar"
            @test read(joinpath(
                root,
                "Traces",
                "2026 ISP Wind traces",
                "wind",
                "sample.csv",
            ), String) == "wind"
            @test read(sentinel, String) == "keep"

            outlook = joinpath(
                root,
                "Core scenarios",
                "2026 ISP - Step Change - Core.xlsx",
            )
            write(outlook, "local")
            ParseISP.prepare_isp2026_inputs(root)
            @test read(outlook, String) == "local"
            ParseISP.prepare_isp2026_inputs(root; overwrite = true)
            @test read(outlook, String) == "outlook"
        end

        mktempdir() do root
            setup_isp2026_archives(zip_command, root)
            missing = isp2026_target_path(root, :isp26_model)
            rm(missing)
            error = try
                ParseISP.prepare_isp2026_inputs(root)
                nothing
            catch caught
                caught
            end
            @test error isa ErrorException
            @test occursin(missing, sprint(showerror, error))
        end
    end
end
