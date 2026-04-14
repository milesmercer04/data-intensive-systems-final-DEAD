#!/usr/bin/env python3
"""Convert all .xlsx files in this repo to .csv files for BigQuery upload.

Output CSVs are written to ./csv_output/, mirroring the source directory
structure, so they can be bulk-uploaded to GCS in one shot.
"""

import argparse
import sys
from pathlib import Path

import pandas as pd


REPO_ROOT = Path(__file__).parent
OUTPUT_ROOT = REPO_ROOT / "csv_output"


def convert_xlsx(xlsx_path: Path, force: bool = False) -> list[Path]:
    """Convert an xlsx file to one csv per sheet. Returns list of created csv paths."""
    rel = xlsx_path.relative_to(REPO_ROOT)
    out_dir = OUTPUT_ROOT / rel.parent
    out_dir.mkdir(parents=True, exist_ok=True)

    created = []
    xf = pd.ExcelFile(xlsx_path)

    for sheet in xf.sheet_names:
        if len(xf.sheet_names) == 1:
            csv_path = out_dir / xlsx_path.with_suffix(".csv").name
        else:
            safe_sheet = sheet.replace(" ", "_").replace("/", "-") # type: ignore
            csv_path = out_dir / f"{xlsx_path.stem}__{safe_sheet}.csv"

        if csv_path.exists() and not force:
            print(f"  SKIP  {csv_path.relative_to(REPO_ROOT)}  (already exists, use --force to overwrite)")
            created.append(csv_path)
            continue

        df = pd.read_excel(xf, sheet_name=sheet, dtype=str)
        df.to_csv(csv_path, index=False)
        print(f"  WROTE {csv_path.relative_to(REPO_ROOT)}")
        created.append(csv_path)

    return created


def main():
    parser = argparse.ArgumentParser(description="Convert .xlsx files in this repo to .csv")
    parser.add_argument("--force", action="store_true", help="Overwrite existing .csv files")
    parser.add_argument(
        "--gcs-bucket",
        metavar="BUCKET",
        help="If provided, print gsutil commands to upload all generated CSVs (e.g. gs://my-bucket/data/)",
    )
    args = parser.parse_args()

    xlsx_files = sorted(REPO_ROOT.rglob("*.xlsx"))
    if not xlsx_files:
        print("No .xlsx files found.")
        sys.exit(0)

    print(f"Found {len(xlsx_files)} .xlsx file(s). Writing CSVs to: {OUTPUT_ROOT.relative_to(REPO_ROOT)}/\n")
    all_csvs: list[Path] = []

    for xlsx_path in xlsx_files:
        print(f"[{xlsx_path.relative_to(REPO_ROOT)}]")
        all_csvs.extend(convert_xlsx(xlsx_path, force=args.force))
        print()

    print(f"Done. {len(all_csvs)} CSV file(s) in {OUTPUT_ROOT.relative_to(REPO_ROOT)}/")

    if args.gcs_bucket:
        bucket = args.gcs_bucket.rstrip("/")
        print("\n--- Upload commands ---\n")
        print("# Upload the entire csv_output/ tree, preserving directory structure:")
        print(f"  gsutil -m cp -r '{OUTPUT_ROOT}' {bucket}/\n")
        print("# Or sync (skips files already in GCS):")
        print(f"  gsutil -m rsync -r '{OUTPUT_ROOT}' {bucket}/csv_output")


if __name__ == "__main__":
    main()
