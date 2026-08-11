# Synthetic, in-memory-only tests for the `fast` regression facility's shared
# comparator (`compare_table`/`compare_case_tables`), Git LFS pointer
# detector (`is_lfs_pointer`), and baseline loader (`load_baseline_case`)
# from ../audit_pipeline_regression.jl. This tests script-level tooling, not
# `src/`, so it lives here rather than under `test/` (see scripts/README.md).
# None of these need the committed LFS fixture, the maintainer's local data,
# or network access — every input here is built fresh in a `mktempdir()`.

using Test
using DataFrames
using Arrow
using SHA
using TOML

if !isdefined(@__MODULE__, :compare_table)
    include(joinpath(@__DIR__, "..", "audit_pipeline_regression.jl"))
end

@testset "pipeline regression helpers (synthetic, no fixture/network required)" begin
    @testset "compare_table" begin
        a = DataFrame(id=[1, 2], value=[1.0, -0.0])
        b = DataFrame(id=[1, 2], value=[1.0, -0.0])
        ok, msg = compare_table("t", a, b)
        @test ok
        @test msg == ""

        # signed zero must not be treated as equal to positive zero
        c = DataFrame(id=[1, 2], value=[1.0, 0.0])
        ok, msg = compare_table("t", a, c)
        @test !ok
        @test occursin("mismatch", msg)

        # missing must compare distinctly from a present value
        d = DataFrame(id=[1, 2], value=Union{Float64,Missing}[1.0, missing])
        e = DataFrame(id=[1, 2], value=Union{Float64,Missing}[1.0, 2.0])
        ok, msg = compare_table("t", d, e)
        @test !ok

        # column name/order mismatch
        f = DataFrame(value=[1.0, -0.0], id=[1, 2])
        ok, msg = compare_table("t", a, f)
        @test !ok
        @test occursin("column names/order differ", msg)

        # row count mismatch
        g = DataFrame(id=[1], value=[1.0])
        ok, msg = compare_table("t", a, g)
        @test !ok
        @test occursin("row count differs", msg)

        # NaN must compare equal to NaN under isequal (unlike ==)
        h = DataFrame(id=[1], value=[NaN])
        k = DataFrame(id=[1], value=[NaN])
        ok, msg = compare_table("t", h, k)
        @test ok
    end

    @testset "compare_case_tables" begin
        t1 = DataFrame(id=[1], value=[1.0])
        t2 = DataFrame(id=[2], value=[2.0])

        named_a = (foo=t1, bar=t2)
        named_b = (foo=copy(t1), bar=copy(t2))
        ok, msg = compare_case_tables(named_a, named_b)
        @test ok

        # NamedTuple candidate vs Dict baseline — the exact shape `check` compares
        dict_b = Dict("foo" => copy(t1), "bar" => copy(t2))
        ok, msg = compare_case_tables(named_a, dict_b)
        @test ok

        # missing key on one side
        dict_missing = Dict("foo" => copy(t1))
        ok, msg = compare_case_tables(named_a, dict_missing)
        @test !ok
        @test occursin("table keys differ", msg)

        # a real mismatch inside one table propagates through with its name
        dict_wrong = Dict("foo" => copy(t1), "bar" => DataFrame(id=[1], value=[1.0]))
        ok, msg = compare_case_tables(named_a, dict_wrong)
        @test !ok
        @test occursin("table `bar`", msg)
    end

    @testset "is_lfs_pointer" begin
        mktempdir() do dir
            pointer_path = joinpath(dir, "pointer.arrow")
            write(pointer_path, "version https://git-lfs.github.com/spec/v1\noid sha256:deadbeef\nsize 123\n")
            @test is_lfs_pointer(pointer_path)

            real_path = joinpath(dir, "real.txt")
            write(real_path, "not an lfs pointer, just ordinary content\n")
            @test !is_lfs_pointer(real_path)
        end
    end

    @testset "sha256_file" begin
        mktempdir() do dir
            path = joinpath(dir, "content.txt")
            write(path, "hello")
            @test sha256_file(path) == bytes2hex(sha256("hello"))
        end
    end

    @testset "load_baseline_case" begin
        table = DataFrame(id=[1, 2], value=[10.0, 20.0])

        function write_synthetic_case(case_dir; corrupt=false, drop_table_file=false, lfs_pointer=false)
            tables_dir = joinpath(case_dir, "tables")
            mkpath(tables_dir)
            arrow_path = joinpath(tables_dir, "only_table.arrow")
            if lfs_pointer
                write(arrow_path, "version https://git-lfs.github.com/spec/v1\noid sha256:deadbeef\nsize 1\n")
            else
                Arrow.write(arrow_path, table)
            end
            recorded_sha = corrupt ? "0"^64 : sha256_file(arrow_path)
            manifest = Dict(
                "authority" => Dict(
                    "package" => "PISP", "commit" => "deadbeef", "tag" => "test",
                    "julia_version" => string(VERSION), "worktree_dirty" => false,
                ),
                "case" => Dict("id" => "synthetic"),
                "tables" => Dict(
                    "only_table" => Dict(
                        "rows" => 2, "columns" => 2,
                        "column_names" => ["id", "value"], "sha256" => recorded_sha,
                    ),
                ),
            )
            drop_table_file && rm(arrow_path)
            open(joinpath(case_dir, "baseline.toml"), "w") do io
                TOML.print(io, manifest)
            end
        end

        mktempdir() do baseline_root
            good_dir = joinpath(baseline_root, "good_case")
            mkpath(good_dir)
            write_synthetic_case(good_dir)
            authority, tables = load_baseline_case("good_case", baseline_root)
            @test authority["commit"] == "deadbeef"
            @test isequal(tables["only_table"], table)
            # materialised columns must be plain Vectors, not Arrow-wrapped types
            @test typeof(tables["only_table"].id) <: Vector

            @test_throws ErrorException load_baseline_case("no_such_case", baseline_root)

            corrupt_dir = joinpath(baseline_root, "corrupt_case")
            mkpath(corrupt_dir)
            write_synthetic_case(corrupt_dir; corrupt=true)
            @test_throws ErrorException load_baseline_case("corrupt_case", baseline_root)

            missing_table_dir = joinpath(baseline_root, "missing_table_case")
            mkpath(missing_table_dir)
            write_synthetic_case(missing_table_dir; drop_table_file=true)
            @test_throws ErrorException load_baseline_case("missing_table_case", baseline_root)

            lfs_dir = joinpath(baseline_root, "lfs_case")
            mkpath(lfs_dir)
            write_synthetic_case(lfs_dir; lfs_pointer=true)
            err = nothing
            try
                load_baseline_case("lfs_case", baseline_root)
            catch e
                err = e
            end
            @test err !== nothing
            @test occursin("git lfs pull", sprint(showerror, err))
        end
    end
end
