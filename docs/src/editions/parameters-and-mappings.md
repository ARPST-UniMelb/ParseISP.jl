# Parameters and mappings

ParseISP uses edition-specific mappings, constants, classifications, and source-field relationships to turn AEMO source data into package identifiers and output tables.

## Where values come from

- **Report-defined mappings** encode a relationship stated in an AEMO report.
- **Workbook-derived values** are read from named workbook sheets, ranges, or build-out columns by the parser.
- **Package-defined defaults** come from ParseISP parameter dictionaries and are applied when the workbook does not provide a complete output row.

| Mapping or parameter layer | ISP 2024 |
| --- | --- |
| Scenario identifiers | IDs `1`, `2`, and `3` identify Progressive Change, Step Change, and Green Energy Exports, and the problem-table and build-out paths use those IDs. |
| Areas and bus aliases | 12 package bus aliases map to the five model areas QLD, NSW, VIC, TAS, and SA. |
| REZ mapping | The parser links REZ IDs and names to ISP subregions and renewable capacity records. |
| Weather years and traces | `ParseISP.ISPdatabuilder.DATE_RANGES_REFYEARS` maps planning-year intervals to historical weather years and supports composite trace `4006`. |
| Technology and asset classifications | Parameter files classify generation, hydro, storage, and build-out inputs. |
| Source-sheet dependencies | Package readers consume named 2024 workbook sheets and trace patterns. |
| Defaults and aliases | Package constants reconcile source names with output identifiers and fill required fields. |

## Detailed references

The [ISP 2024 parameters and mappings](../generated/isp2024/reference/parameters-and-mappings.md) page provides the scenario, bus, area, weather-year, reliability-field, and source-sheet tables used by the package.
The [ISP 2024 build-out defaults](../generated/isp2024/reference/buildout-defaults.md) page describes workbook fields, generated identities, calculations, and package template values for optional generator and storage additions.
The [ISP 2024 hydro parameters and constants](../generated/isp2024/reference/hydro-parameters-and-constants.md) page lists the values used to assign hydro traces, annual energy limits, hydrological years, and Snowy inflows.
