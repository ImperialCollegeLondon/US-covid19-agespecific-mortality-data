#!/bin/bash
today=$(date +'%Y-%m-%d')
echo "$today"
mkdir -p data/$today/
mkdir -p pdfs/$today/
# csvs, excel sheets
## georgia

## Get most data
python scripts/age_extraction.py
GET https://data.ct.gov/resource/ypz6-8qyf.json > data/$today/colorado.csv