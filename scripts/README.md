# Scripts

Maintainer-facing tooling for ParseISP.jl.
These are not part of the package API and are not run by `Pkg.test()`.
Run them manually from the repo root.

| Script | Purpose |
| --- | --- |
| [`build_pipeline_regression_data_2024.jl`](#build_pipeline_regression_data_2024jl) | Build (or verify) the small, committed regression fixture under `test/data/isp2024/` from a full local ISP 2024 data collection. |
| [`audit_pipeline_regression.jl`](#audit_pipeline_regressionjl) | Prove the fixture is value-preserving by running the pipeline against both the full data and the fixture, and diffing the resulting tables exactly. |
| [`audit_source_spec_equivalence.jl`](#audit_source_spec_equivalencejl) | Prove that `ParseISP`'s declarative `source_spec`-based reads return the same data as literal, hardcoded workbook/sheet/range reads. |
| [`test_coverage.sh`](#test_coveragesh) | Run the test suite with coverage instrumentation and print/write a coverage report. |
| [`clean_cov.sh`](#clean_covsh) | Delete stray `*.cov` files left behind by coverage runs. |

All Julia scripts expect to be run with the package environment active:

```sh
julia --project=. scripts/<script>.jl ...
```

## `build_pipeline_regression_data_2024.jl`

Builds the reduced, `pisp-downloads`-shaped fixture tree that lives at `test/data/isp2024/pisp-downloads/` (committed via Git LFS), so routine tests never need the maintainer's full ~66GB local ISP 2024 collection. It only builds/checks the fixture files themselves — it does not touch Git LFS wiring, `.gitattributes`/`.gitignore`, or run the pipeline comparison (see `audit_pipeline_regression.jl` for that).

What it keeps, per file group:

- **3 root workbooks** (`2019-input-and-assumptions-workbook-v1-3-dec-19.xlsx`, `2023-iasr-ev-workbook.xlsx`, `2024-isp-inputs-and-assumptions-workbook.xlsx`) and **6 `Auxiliary/*.xlsx` workbooks** — copied byte-for-byte.
- **Solar/wind trace CSVs** and **demand trace CSVs** — cropped to 5 fixed dates (`REQUIRED_DATES`) that exercise the financial-year/weather-year splice, a seasonal boundary, and a date-branch condition.
- **Hydro `MonthlyNaturalInflow_*` CSVs** — cropped the same way, by date.
- **Hydro `MaxEnergyYear_*` CSVs** — cropped to 2 fixed years (`REQUIRED_YEARS`).

Demand subregions and scenario filename codes are *derived* from the source tree at build time (never hardcoded), so the script fails loudly if the source layout doesn't match expectations rather than silently building a wrong fixture.

```sh
# Build a fresh fixture from a full local pisp-downloads collection into an
# empty output directory (refuses to overwrite a non-empty one):
julia --project=. scripts/build_pipeline_regression_data_2024.jl build \
  --source-root /path/to/full/pisp-downloads \
  --output-root /path/to/empty/output-dir

# Read-only check: rebuilds into a fresh temp dir from --source-root and
# diffs every file (including the manifest) byte-for-byte against an
# existing fixture directory. Never writes into --fixture-root.
julia --project=. scripts/build_pipeline_regression_data_2024.jl check \
  --source-root /path/to/full/pisp-downloads \
  --fixture-root test/data/isp2024/pisp-downloads
```

Both modes write/expect a `fixture-manifest.toml` (schema version, plus one record per file: path, mode `copy`/`crop`, source/fixture SHA-256, size, and row counts for cropped files) at the root of the fixture tree.

Example:

```sh
julia --project=. scripts/build_pipeline_regression_data_2024.jl build \
  --source-root data/2024/pisp-downloads \
  --output-root test/data/isp2024/pisp-downloads
```

The committed fixture keeps `fixture-manifest.toml` one level up, alongside `NOTICE.md` — not inside `pisp-downloads/`. If you're replacing the live fixture, move it up after building:

```sh
mv test/data/isp2024/pisp-downloads/fixture-manifest.toml test/data/isp2024/
```

Example:

```sh
julia --project=. scripts/build_pipeline_regression_data_2024.jl check \
  --source-root data/2024/pisp-downloads \
  --fixture-root test/data/isp2024/pisp-downloads
```

> [!NOTE]
> `--source-root` must be the maintainer's complete, uncropped local ISP 2024
> collection. That collection is not part of this repository, so `build`
> cannot be run without access to it — `check` is the mode most contributors
> can realistically use, and only if they have that source tree locally.

## `audit_pipeline_regression.jl`

Proves that the fixture built above is *value-preserving*: for each case in the fixed `PIPELINE_REGRESSION_CASES` matrix (defined in `test/support/pipeline_regression.jl`), it runs the pipeline once against a complete local data root and once against the fixture root, then compares the resulting 19 in-memory tables cell-by-cell with `isequal` (so `missing`, `NaN`, and signed-zero distinctions all count as mismatches). Both roots are treated as read-only.

```sh
# Verify every case:
julia --project=. scripts/audit_pipeline_regression.jl verify-fixture \
  --full-data-root /path/to/full/pisp-downloads \
  --fixture-root test/data/isp2024/pisp-downloads

# Verify a single case:
julia --project=. scripts/audit_pipeline_regression.jl verify-fixture \
  --full-data-root /path/to/full/pisp-downloads \
  --fixture-root test/data/isp2024/pisp-downloads \
  --case <case-id>
```

Run with `--help` to print the current list of known `--case` ids. On mismatch, it prints the failing table name, row, column, and both values.

Example:

```sh
julia --project=. scripts/audit_pipeline_regression.jl verify-fixture \
  --full-data-root data/2024/pisp-downloads \
  --fixture-root test/data/isp2024/pisp-downloads
```

Example:

```sh
julia --project=. scripts/audit_pipeline_regression.jl verify-fixture \
  --full-data-root data/2024/pisp-downloads \
  --fixture-root test/data/isp2024/pisp-downloads \
  --case default_fy_splice
```

> [!NOTE]
> Only the `verify-fixture` subcommand is implemented. `capture` and `check`
> (trusted-baseline capture/promotion) are not implemented.

## `audit_source_spec_equivalence.jl`

`ParseISP` reads most workbook data through declarative `source_spec` definitions (workbook path + worksheet + cell range, keyed by a `source_id` symbol) rather than hardcoded literal reads scattered through the codebase. This script proves the two approaches agree, across the full case list covering core generator/network tables, DSP (Demand-Side Participation) tables per scenario/region/season, VPP capacity/energy outlooks, hydro scheme inflows, EV workbook sheets, and per-scenario `Core`/`Auxiliary` workbooks discovered from `--data-root`.

It has three modes:

```sh
# Read every case via literal, hardcoded workbook/sheet/range reads:
julia --project=. scripts/audit_source_spec_equivalence.jl legacy \
  --data-root /path/to/pisp-downloads \
  --output /path/to/legacy-manifest.toml

# Read every case via ParseISP's source_spec machinery instead:
julia --project=. scripts/audit_source_spec_equivalence.jl specs \
  --data-root /path/to/pisp-downloads \
  --output /path/to/specs-manifest.toml

# Compare two manifests (rows, columns, column names, SHA-256 of the
# CSV-serialized table) and report every mismatch:
julia --project=. scripts/audit_source_spec_equivalence.jl compare \
  --baseline /path/to/legacy-manifest.toml \
  --candidate /path/to/specs-manifest.toml
```

`legacy` and `specs` each write a manifest recording, per case: the workbook/worksheet/range read, row/column counts, column names, and a SHA-256 of the table's CSV serialization. Cases whose source workbook is missing from `--data-root`, or that error while reading, are recorded under `skips` with a reason instead of failing the whole run. `compare` exits non-zero if any case is present in only one manifest or differs on any tracked field.

Example:

```sh
julia --project=. scripts/audit_source_spec_equivalence.jl legacy \
  --data-root data/2024/pisp-downloads \
  --output /tmp/legacy-manifest.toml

julia --project=. scripts/audit_source_spec_equivalence.jl specs \
  --data-root data/2024/pisp-downloads \
  --output /tmp/specs-manifest.toml

julia --project=. scripts/audit_source_spec_equivalence.jl compare \
  --baseline /tmp/legacy-manifest.toml \
  --candidate /tmp/specs-manifest.toml
```

## `test_coverage.sh`

Runs the full test suite with Julia's coverage instrumentation enabled, then prints a per-file coverage summary and writes an LCOV report.

```sh
./scripts/test_coverage.sh
```

Steps:

1. Deletes stray `*.cov` files under `src/`, `test/`, `docs/` (same cleanup as `clean_cov.sh`).
2. Runs `Pkg.test(; coverage=true)`.
3. Processes the generated `.cov` files with `Coverage.jl`, prints per-file and overall coverage percentages, and writes `coverage-lcov.info` at the repo root.

## `clean_cov.sh`

Deletes stray `*.cov` files left under `src/`, `test/`, and `docs/` by prior coverage runs (e.g. after an interrupted `test_coverage.sh`, or before committing).

```sh
./scripts/clean_cov.sh
```
