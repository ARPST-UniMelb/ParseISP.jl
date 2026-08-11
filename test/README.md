# Tests

## Test `src/`

Tests for `src/`. Run with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

| File | What it tests | Needs real local data? |
| --- | --- | --- |
| `test_source_availability.jl` | Whether the maintainer's local ISP 2024/2026 data is present. Other files skip their real-data checks when it isn't. | No |
| `test_zip_extraction.jl` | Unpacking zip archives, ignoring macOS AppleDouble sidecar files. Uses its own synthetic zip. | No |
| `test_report_downloader_2024.jl` | ISP 2024 report download catalogue and skip-existing/overwrite/failure handling. Mocked, no network. | No |
| `test_report_downloader_2026.jl` | Same, for ISP 2026 reports. | No |
| `test_source_downloader_2026.jl` | Same, for ISP 2026 source archives. | No |
| `test_buildout_defaults_documentation_2024.jl` | Build-out default injection logic, against a synthetic in-memory table. | No |
| `test_source_specs.jl` | Raw workbook/CSV reads (schema and sample values) via the same reader functions the parser uses. | Yes — skips if absent |
| `test_pipeline_integration_2024.jl` | Full population (`populate_time_static!`/`populate_time_varying!`) against real local data, one scenario, one day. | Yes — skips if absent |
| `test_pipeline_regression_fixture_2024.jl` | The same population path, all six regression cases, against the small committed fixture instead of real local data. Checks structure (tables present, non-empty, expected columns) and exact values against the committed baseline. | No — uses the committed fixture and baseline |

`support/pipeline_regression.jl` isn't a test — it's the shared six-case matrix and table selector used by `test_pipeline_regression_fixture_2024.jl` above and by the scripts under `../scripts/`.

For running a specific test file mimic this example,

```sh
julia --project=. -e '
using ParseISP, Test, Dates

include("test/test_report_downloader_2024.jl")
include("test/test_report_downloader_2026.jl")
'
```

## Other test

Tests for `scripts/` and `docs/` live at at their respective directory.
