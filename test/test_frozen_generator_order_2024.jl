# Catches drift between the frozen id_gen orders and their source dicts —
# a new bus or retirement would otherwise be silently skipped.

using Test

@testset "frozen generator order matches its source (2024)" begin
    @test Set(ParseISP.LARGE_SOLAR_BUS_ORDER) == setdiff(Set(keys(ParseISP.NEMBUSNAME)), Set(["GG", "SNW"]))
    @test Set(ParseISP.LARGE_WIND_BUS_ORDER) == setdiff(Set(keys(ParseISP.NEMBUSNAME)), Set(["GG"]))

    for scid in keys(ParseISP.ID2SCE)
        @test Set(ParseISP.RETIREMENT_ORDER_2024) == Set(keys(ParseISP.Retirements2024[scid]))
    end
end
