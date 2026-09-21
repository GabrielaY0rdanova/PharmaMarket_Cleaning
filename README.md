# PharmaMarket Cleaning

![SQL Server](https://img.shields.io/badge/SQL%20Server-2022-blue?logo=microsoftsqlserver&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.x-blue?logo=python&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

## Overview

This repository contains the cleaning and validation stage of the PharmaMarket Data Platform. It reads the relational output produced by [PharmaMarket ETL](https://github.com/GabrielaY0rdanova/PharmaMarket_ETL), loads it into a separate SQL Server database, applies documented corrections, and verifies the final state.

The source ETL database remains unchanged. Cleaning runs against a separate target database so the source and cleaned versions can be compared.

The verified clean database contains:

| Table | Rows |
|---|---:|
| `Drug_Class` | 422 |
| `Dosage_Form` | 113 |
| `Manufacturer` | 240 |
| `Indication` | 2,043 |
| `Generic` | 1,711 |
| `Medicine` | 21,708 |
| `Medicine_PackageSize` | 14,349 |
| `Medicine_PackageContainer` | 22,707 |
| `Generic_Indication` | 1,608 |

## Repository Structure

```text
PharmaMarket_Cleaning/
├── docs/
│   └── cleaning_findings.md
├── source_data/
│   └── nine exported CSV tables
├── scripts/
│   ├── 00_CreateDatabase.sql
│   ├── 01_ExportSourceData.py
│   ├── 02_LoadSourceData.sql
│   └── 03 through 11 cleaning scripts
├── tests/
│   ├── 12_Validation.sql
│   ├── 13_ValidationGate.sql
│   └── test_cleaning_contract.py
├── run_full_cleaning.sql
└── run_validation.sql
```

## Cleaning Results

The detailed review is available in [`docs/cleaning_findings.md`](docs/cleaning_findings.md).

| Table | Finding | Result |
|---|---|---|
| `Drug_Class` | 1,178 comma artifacts and 2 encoding artifacts | Invalid and duplicate rows were resolved. Garbled beta characters were corrected. |
| `Dosage_Form` | 1 capitalization inconsistency | Corrected. |
| `Manufacturer` | Encoding, spacing, punctuation, capitalization, and spelling inconsistencies | Eight values were corrected. |
| `Indication` | 24 encoding artifacts | Corrected. |
| `Generic` | 5 encoding artifacts | Corrected. |
| `Medicine` | Missing source attributes and 59 duplicate records | Preserved and documented because the source does not support deterministic correction. |
| `Medicine_PackageSize` | No confirmed data-quality defects | No changes required. |
| `Medicine_PackageContainer` | Placeholder values and repeated source combinations | Preserved and documented. |
| `Generic_Indication` | No confirmed data-quality defects | No changes required. |

The cleaning process does not invent missing pharmaceutical information. Source limitations remain null or are documented when a reliable correction is not available.

## Running the Workflow

### Requirements

- SQL Server 2022 or compatible version
- SQL Server Management Studio with SQLCMD Mode
- Python 3
- `pandas`
- `pyodbc`
- Microsoft ODBC Driver 17 or 18 for SQL Server

### Use the Included Source Snapshot

The repository includes the exported CSV files in `source_data/`. You can rebuild the clean database without running the ETL project locally.

1. Open `run_full_cleaning.sql` in SSMS.
2. Enable `Query > SQLCMD Mode`.
3. Confirm the variables at the top of the file:

```sql
:setvar DatabaseName "PharmaMarketAnalytics_Clean_Test"
:setvar AllowDestructiveReset "YES"
:setvar SourceDataPath "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\source_data"
```

4. Confirm that the `:r` paths match the local project location.
5. Run the complete script.

The default database is `PharmaMarketAnalytics_Clean_Test`. This keeps the verified test workflow separate from the original ETL and clean databases.

### Export a Fresh ETL Snapshot

Use `scripts/01_ExportSourceData.py` when you have already built the ETL database locally and want to refresh `source_data/`.

The script reads these optional environment variables:

```text
PHARMA_SQL_SERVER
PHARMA_ETL_DATABASE
PHARMA_ODBC_DRIVER
PHARMA_CLEAN_SOURCE_DIR
```

Example PowerShell configuration:

```powershell
$env:PHARMA_SQL_SERVER = "DESKTOP-SJC0GQV\SQLEXPRESS"
$env:PHARMA_ETL_DATABASE = "PharmaMarketAnalytics_ETL_Test"
$env:PHARMA_ODBC_DRIVER = "ODBC Driver 18 for SQL Server"
python scripts/01_ExportSourceData.py
```

The default output directory is the repository's `source_data/` folder.

## Safety Controls

`scripts/02_LoadSourceData.sql` drops and recreates the target tables. It refuses to continue unless:

```sql
:setvar AllowDestructiveReset "YES"
```

The default runner targets `PharmaMarketAnalytics_Clean_Test`. Change the database name only when you intentionally want to rebuild another cleaning database.

The workflow does not modify the ETL source database.

## Validation

The full runner executes two validation layers:

1. `tests/12_Validation.sql` provides detailed quality and distribution checks.
2. `tests/13_ValidationGate.sql` enforces required row counts, uniqueness, and referential integrity. It stops the run when a required check fails.

To validate an existing clean database without reloading data, open `run_validation.sql` in SSMS with SQLCMD Mode enabled and run it.

A successful run ends with:

```text
Cleaning validation gate passed.
Complete cleaning rebuild and validation finished for PharmaMarketAnalytics_Clean_Test.
```

Run the repository contract tests with:

```powershell
python -m unittest discover -s tests -p "test_*.py" -v
```

## Related Projects

- [PharmaMarket ETL](https://github.com/GabrielaY0rdanova/PharmaMarket_ETL)
- [PharmaMarket EDA](https://github.com/GabrielaY0rdanova/PharmaMarket_EDA)
- [PharmaMarket Visualization](https://github.com/GabrielaY0rdanova/PharmaMarket_Visualization)

## Data Source

The source data comes from the Kaggle dataset [Assorted Medicine Dataset of Bangladesh](https://www.kaggle.com/datasets/ahmedshahriarsakib/assorted-medicine-dataset-of-bangladesh).

This project uses the data for educational and portfolio purposes.

## License

This project is licensed under the [MIT License](LICENSE.txt).
