# Trace coverage

The ISP 2024 model release uses trace files for demand, renewable generation, hydro, distributed resources, and seasonal time slices.

| Trace aspect | ISP 2024 |
| --- | --- |
| Trace families | Demand, hydro, load-subtractor, solar, timeslice, and wind folders. |
| Scenario layout | Demand and model-side traces use the 2024 scenario and source naming conventions. |
| Renewable traces | Solar and wind files are organised by technology, project, and reference year. |
| Half-hourly schema | Solar and wind samples use `Year`, `Month`, `Day`, and columns `01` to `48`. Demand uses a separate per-node file family. |
| Daily schema | Hydro inflow and annual-energy files use release-specific daily structures. |
| Reference years | The Model Instructions describe 14 historical reference years and the package also uses the composite `4006` convention. |
| Demand POE | The 2024 demand filenames use `POE10` and `POE50`, selected through the package `poe` argument. |

Within the ISP 2024 demand folders, `*_OPSO_MODELLING_PVLITE.csv` supplies operational demand net of PV-lite profiles, while `*_PV_TOT.csv` supplies distributed or rooftop-PV schedules.

The [2024 ISP PLEXOS Model Instructions, p. 7](../../../data/2024/pisp-reports/2024-isp-plexos-model-instructions.pdf#page=7) describe demand, hydro, load-subtractor, solar, timeslice, and wind trace folders. The report describes 14 historical reference years on [p. 5](../../../data/2024/pisp-reports/2024-isp-plexos-model-instructions.pdf#page=5).

The [2023 Inputs, Assumptions and Scenarios Report, p. 172](../../../data/2024/pisp-reports/2023-inputs-assumptions-and-scenarios-report.pdf#page=172) defines POE as probability of exceedance. The [2023 ISP Methodology, p. 39](../../../data/2024/pisp-reports/2023-isp-methodology.pdf#page=39) describes 10%, 50%, and sometimes 90% POE simulations and uses 10% POE demand profiles for capacity-outlook modelling.

[Domain concepts](../concepts.md) explains the ISP 2024 `reftrace` and `poe` selectors. The [ISP 2024 workbook and trace structure](../generated/isp2024/validation/workbook-and-trace-structure.md) page gives the 2024 workbook selections, model folders, trace patterns, keys, fields, and units.
