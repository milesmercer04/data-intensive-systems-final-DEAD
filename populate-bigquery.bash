#!/usr/bin/env bash
# bigquery_setup.sh
# Prerequisites: gcloud CLI installed + authenticated, files already in GCS

set -euo pipefail

PROJECT="your-gcp-project-id"
DATASET="oews_bea"
BUCKET="gs://your-bucket-name"    # wherever you uploaded csv_output/
LOCATION="US"

# ── 1. Create dataset ──────────────────────────────────────────────────────────
bq --project_id="$PROJECT" mk \
  --dataset \
  --location="$LOCATION" \
  --description="OEWS + BEA MSA data" \
  "$DATASET" || echo "Dataset already exists, continuing."

# ── 2. Load tables from GCS ────────────────────────────────────────────────────
# MSA-level OEWS wages (the big one)
bq --project_id="$PROJECT" load \
  --source_format=CSV \
  --autodetect \
  --skip_leading_rows=1 \
  --replace \
  "$DATASET.oews_msa" \
  "$BUCKET/csv_output/oesm24ma/MSA_M2024_dl__MSA_M2024_dl.csv"

# BEA Regional Price Parities
bq --project_id="$PROJECT" load \
  --source_format=CSV \
  --autodetect \
  --skip_leading_rows=1 \
  --replace \
  "$DATASET.bea_marpp" \
  "$BUCKET/MARPP_MSA_2008_2024.csv"

# BEA Implicit Regional Price Deflators
bq --project_id="$PROJECT" load \
  --source_format=CSV \
  --autodetect \
  --skip_leading_rows=1 \
  --replace \
  "$DATASET.bea_mairpd" \
  "$BUCKET/MAIRPD_MSA_2008_2024.csv"

# ── 3. First joined query: real wages by MSA ───────────────────────────────────
# Joins 2024 OEWS median annual wages with BEA 2024 RPP to get
# cost-of-living-adjusted wages. Filtered to a single occupation for clarity.
bq --project_id="$PROJECT" query \
  --use_legacy_sql=false \
  --destination_table="$DATASET.prototype_wages_adjusted" \
  --replace \
  "
  WITH oews AS (
    SELECT
      CAST(AREA AS STRING)  AS cbsa_code,
      AREA_TITLE,
      OCC_CODE,
      OCC_TITLE,
      SAFE_CAST(A_MEDIAN AS FLOAT64) AS median_annual_wage
    FROM \`$PROJECT.$DATASET.oews_msa\`
    WHERE OCC_CODE = '15-1252'   -- Software Developers; swap as needed
      AND A_MEDIAN NOT IN ('*','#','**')
  ),
  rpp AS (
    SELECT
      TRIM(REPLACE(GeoFIPS, '\"', '')) AS cbsa_code,
      TRIM(GeoName)                    AS metro_name,
      SAFE_CAST(\`2024\` AS FLOAT64)   AS rpp_2024
    FROM \`$PROJECT.$DATASET.bea_marpp\`
    WHERE LineCode = 1   -- 'RPPs: All items'
  )
  SELECT
    o.AREA_TITLE,
    o.OCC_TITLE,
    o.median_annual_wage,
    r.rpp_2024,
    ROUND(o.median_annual_wage / (r.rpp_2024 / 100), 0) AS real_wage_adjusted
  FROM oews o
  JOIN rpp r ON o.cbsa_code = r.cbsa_code
  ORDER BY real_wage_adjusted DESC
  LIMIT 50
  "

echo "Done. Table written to $PROJECT:$DATASET.prototype_wages_adjusted"
