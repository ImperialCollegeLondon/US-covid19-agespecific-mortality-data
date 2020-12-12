#!/bin/bash
today=$(date +'%Y-%m-%d')
echo "$today"
mkdir -p data/$today/
mkdir -p pdfs/$today/

# run python scripts
python scripts/extractor.py
python scripts/selenium_extractor.py

# GET method to directly download some data
GET https://data.ct.gov/resource/ypz6-8qyf.json > data/$today/connecticut_2.csv
GET https://opendata.arcgis.com/datasets/ebf62bbdba59497a9dba00aed0c17078_0.csv > data/$today/alaska.csv
GET https://data.virginia.gov/api/views/uktn-mwig/rows.csv?accessType=DOWNLOAD > data/$today/virginia.csv
GET https://opendata.arcgis.com/datasets/b913e9591eae4912b33dc5b4e88646c5_10.csv?outSR=%7B%22latestWkid%22%3A3857%2C%22wkid%22%3A102100%7D > data/Wisconsin.csv
GET https://www.tn.gov/content/dam/tn/health/documents/cedep/novel-coronavirus/datasets/Public-Dataset-Age.XLSX > data/tn.xlsx
