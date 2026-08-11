# States
ST = ["QLD","NSW","VIC","TAS","SA"]
# States ID
STID = Dict("QLD"   =>  1, 
            "NSW"   =>  2, 
            "VIC"   =>  3, 
            "TAS"   =>  4, 
            "SA"    =>  5)

STSOL = ["QLD", "NSW", "VIC", "SA"]
# Bus names
NEMBUSNAME = OrderedDict(
                        "NQ"    => "Northern Queensland",
                        "CQ"    => "Central Queensland",
                        "GG"    =>  "Gladstone Grid", 
                        "SQ"    =>  "Southern Queensland", 
                        "NNSW"  =>  "Northern New South Wales", 
                        "CNSW"  =>  "Central New South Wales", 
                        "SNW"   =>  "Sydney, Newcastle & Wollongong", 
                        "SNSW"  =>  "Southern New South Wales", 
                        "VIC"   =>  "Victoria", 
                        "TAS"   =>  "Tasmania", 
                        "CSA"   =>  "Central South Australia",
                        "SESA"  => "South East South Australia")
# Frozen bus order for solar/wind id_gen assignment.
# NOTE:
#   This is due to bug caused by inconsistent order across Julia versions.
#   This is currently only impact `LSPV_`, `WIND_`, and retired generators.
LARGE_SOLAR_BUS_ORDER = ["CQ","VIC","NNSW","SQ","CSA","NQ","SNSW","CNSW","TAS","SESA"]
LARGE_WIND_BUS_ORDER  = ["CQ","VIC","NNSW","SQ","CSA","NQ","SNSW","CNSW","TAS","SESA","SNW"]
# Buses locations
NEMBUSES = OrderedDict(        "NQ"    => [-17.79385, 145.5635],       #1
                        "CQ"    =>  [-22.82420, 149.40361],     #2
                        "GG"    =>  [-23.842948, 151.248803],   #3
                        "SQ"    =>  [-27.476625,153.029934],    #4
                        "NNSW"  =>  [-30.504711, 151.652465],   #5
                        "CNSW"  =>  [-33.483300, 150.157717],   #6
                        "SNW"   =>  [-33.865,151.209444],       #7
                        "SNSW"  =>  [-35.110980,147.359907],    #8
                        "VIC"   =>  [-37.766053,144.943397],    #9 
                        "TAS"   =>  [-42.880556,147.325],       #10
                        "CSA"   =>  [-34.80268, 138.52164],     #11
                        "SESA"  =>  [-37.60470, 140.8373])      #12
# Areas (market model)
NEMAREAS = OrderedDict(        "QLD"   =>  "Queensland",
                        "NSW"   =>  "New South Wales",
                        "VIC"   =>  "Victoria",
                        "TAS"   =>  "Tasmania",
                        "SA"    =>  "South Australia")
# Relation between areas and buses
BUS2AREA = OrderedDict(        "NQ"    =>  "QLD",
                        "CQ"    =>  "QLD",
                        "GG"    =>  "QLD",
                        "SQ"    =>  "QLD",
                        "NNSW"  =>  "NSW",
                        "CNSW"  =>  "NSW",
                        "SNW"   =>  "NSW",
                        "SNSW"  =>  "NSW",
                        "VIC"   =>  "VIC",
                        "TAS"   =>  "TAS",
                        "CSA"   =>  "SA",
                        "SESA"  => "SA")

#IDs of scenarios
ID2SCE = OrderedDict(
                1 => "Progressive Change", 
                2 => "Step Change", 
                3 => "Green Energy Exports")
# Scenarios
SCE = OrderedDict(
            "Progressive Change"        => 1, 
            "Step Change"               => 2, 
            "Green Energy Exports"      => 3)

SCE2 = OrderedDict(
            "Progressive"   => 1, 
            "Step"          => 2, 
            "Green"         => 3)

ID2SCE2 = Dict(1 => "Progressive Change", 2 => "Step Change", 3 => "Hydrogen Export")

# Hydro inflow files mapping
HYDROSCE = OrderedDict(
                "Progressive Change"    => "NetZero2050",
                "Step Change"           => "StepChange",
                "Green Energy Exports"  => "HydrogenSuperpower")

DEMSCE = OrderedDict(
                "Progressive Change"    => "PROGRESSIVE_CHANGE",
                "Step Change"           => "STEP_CHANGE",
                "Green Energy Exports"  => "HYDROGEN_EXPORT")

# Weather years mapping for ISP 2024 trace 4006 (Optimal development path). 
# Date mapping based on https://aemo.com.au/-/media/files/major-publications/isp/2024/supporting-materials/2024-isp-plexos-model-instructions.pdf?la=en
WEATHER_YEARS_ISP = Dict(
    ("2024-07-01", "2025-06-30") => "2019",
    ("2025-07-01", "2026-06-30") => "2020",
    ("2026-07-01", "2027-06-30") => "2021",
    ("2027-07-01", "2028-06-30") => "2022",
    ("2028-07-01", "2029-06-30") => "2023",
    ("2029-07-01", "2030-06-30") => "2015",
    ("2030-07-01", "2031-06-30") => "2011",
    ("2031-07-01", "2032-06-30") => "2012",
    ("2032-07-01", "2033-06-30") => "2013",
    ("2033-07-01", "2034-06-30") => "2014",
    ("2034-07-01", "2035-06-30") => "2015",
    ("2035-07-01", "2036-06-30") => "2016",
    ("2036-07-01", "2037-06-30") => "2017",
    ("2037-07-01", "2038-06-30") => "2018",
    ("2038-07-01", "2039-06-30") => "2019",
    ("2039-07-01", "2040-06-30") => "2020",
    ("2040-07-01", "2041-06-30") => "2021",
    ("2041-07-01", "2042-06-30") => "2022",
    ("2042-07-01", "2043-06-30") => "2023",
    ("2043-07-01", "2044-06-30") => "2015",
    ("2044-07-01", "2045-06-30") => "2011",
    ("2045-07-01", "2046-06-30") => "2012",
    ("2046-07-01", "2047-06-30") => "2013",
    ("2047-07-01", "2048-06-30") => "2014",
    ("2048-07-01", "2049-06-30") => "2015",
    ("2049-07-01", "2050-06-30") => "2016",
    ("2050-07-01", "2051-06-30") => "2017",
    ("2051-07-01", "2052-06-30") => "2018",
)