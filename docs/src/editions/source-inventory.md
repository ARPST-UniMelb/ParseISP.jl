# Source-to-dataset processing

ParseISP keeps reports, workbooks, model archives, parsed tables, and generated datasets as separate layers.
This separation makes each parser decision traceable to a named source selection.

| Stage | Description |
| --- | --- |
| Source acquisition | Obtain the reports, workbooks, model archives, outlooks, and trace archives required by the ISP 2024 workflow. |
| Archive extraction | Expand packaged workbooks, scenario models, and trace folders. |
| Source map | Record the file, worksheet or folder selection, keys, fields, and units. |
| Parsing and reconciliation | Read the source structures and align identifiers, categories, and fields. |
| Dataset build | Write the static and schedule tables used downstream. |
| Output contract | Define filenames, schemas, identifiers, units, and join relationships. |
| Validation and analysis | Check the source and output structures and interpret the resulting data. |

The ISP 2024 track follows these stages through [`ParseISP.build_ISP24_datasets`](../generated/isp2024/tutorials/building-problem-table.md) and the documented static and schedule outputs.

For the ISP 2024 workflow, consult [source data](../generated/isp2024/reference/source-data.md), [workbook and trace structure](../generated/isp2024/validation/workbook-and-trace-structure.md), and [output tables](../generated/isp2024/reference/output-tables.md).
