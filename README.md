# data-intensive-systems-final

A data pipeline project that ingests government economic datasets and loads them into Google BigQuery for analysis.

## Data Sources

### BEA — Bureau of Economic Analysis
- **MARPP / MAIRPD** — Metropolitan Area Personal Income and Regional Price Parities, 2008–2024 (pre-converted CSVs in repo root)

### BLS — Occupational Employment and Wage Statistics (OEWS), May 2024
Downloaded from the [BLS OEWS data downloads page](https://www.bls.gov/oes/tables.htm):

| Directory | Contents |
|-----------|----------|
| `oesm24all/` | All industries combined |
| `oesm24in4/` | Industry detail (3-digit, 4-digit, 5/6-digit NAICS; sector; ownership) |
| `oesm24ma/` | Metropolitan and nonmetropolitan areas (MSA + Boston detail) |
| `oesm24nat/` | National estimates |
| `oesm24st/` | State-level estimates |

## Transforming Data for BigQuery

Google BigQuery does not support `.xlsx` uploads. Run the conversion script to produce `.csv` files:

```bash
# Requires pandas and openpyxl
pip install pandas openpyxl

python3 xlsx_to_csv.py
```

All output CSVs are written to `csv_output/`, mirroring the source directory structure. Multi-sheet workbooks produce one CSV per sheet, named `<file>__<sheet>.csv`.

Re-running is safe — existing files are skipped unless you pass `--force`.

## Uploading to Google Cloud Storage

```bash
# Copy the entire csv_output/ tree to GCS
gsutil -m cp -r csv_output gs://your-bucket-name/

# Or sync (skips files already present in GCS)
gsutil -m rsync -r csv_output gs://your-bucket-name/csv_output
```

Pass `--gcs-bucket` to the script to have it print the exact commands for your bucket:

```bash
python3 xlsx_to_csv.py --gcs-bucket gs://your-bucket-name/data
```

Once the files are in GCS, create external or native BigQuery tables pointing at the relevant CSVs.
