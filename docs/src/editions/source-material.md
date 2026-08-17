# AEMO ISP source material

The public documentation describes the reports, workbooks, model archives, outlooks, and traces used by the ISP 2024 ParseISP workflow.

The documentation follows the lifecycle:

```text
AEMO source data -> ParseISP transformation -> ParseISP datasets
```

## ISP 2024 source collections

| Source material | Role in the documented workflow |
| --- | --- |
| Report PDFs | Provide release context, model instructions, methodology, and assumptions used to interpret source data. |
| Inputs and assumptions workbook | Supplies generation, storage, reliability, retirement, network, REZ, hydro, DSP, and related assumptions. |
| EV workbook | Supplies vehicle numbers, charging shares, and profiles used by the 2024 workflow. |
| Model archive | Contains scenario models and model-side trace folders used by the package. |
| Generation and storage outlook | Provides capacity, storage, REZ, and sensitivity tables used by preprocessing. |
| Solar and wind traces | Provide technology-, project-, and reference-year time series. |
| `Auxiliary` material | ParseISP-generated preprocessing intermediates used by the 2024 build. |
| Generated ParseISP datasets | `ParseISP.build_ISP24_datasets` writes the documented static and schedule outputs. |

The [ISP 2024 source-data reference](../generated/isp2024/reference/source-data.md) lists supported files, workbook selections, keys, fields, and units.
The [workbook and trace structure](../generated/isp2024/validation/workbook-and-trace-structure.md) documents workbook selections, model folders, trace patterns, keys, fields, and units.
The [trace coverage](trace-coverage.md) page explains the trace conventions used by the 2024 workflow.

Similar names across source files do not by themselves establish equivalent schema, keys, units, coverage, or modelling role.
