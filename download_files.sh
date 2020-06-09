#!/bin/bash
today=$(date +'%Y-%m-%d')
echo "$today"
mkdir -p data/$today/
mkdir -p pdfs/$today/
# csvs, excel sheets
## georgia

## Get most data
python scripts/age_extraction.py
GET https://data.ct.gov/resource/ypz6-8qyf.json > data/$today/connecticut_2.csv
python scripts/extraction_try.py
GET https://opendata.arcgis.com/datasets/ebf62bbdba59497a9dba00aed0c17078_0.csv > data/$today/alaska.csv
GET https://opendata.arcgis.com/datasets/882fd53e0c1b43c2b769a4fbdc1c6448_0.csv?outSR=%7B%22latestWkid%22%3A4269%2C%22wkid%22%3A4269%7D > data/$today/colorado.csv

