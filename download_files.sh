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
<<<<<<< HEAD
GET https://opendata.arcgis.com/datasets/882fd53e0c1b43c2b769a4fbdc1c6448_0.csv?outSR=%7B%22latestWkid%22%3A4269%2C%22wkid%22%3A4269%7D > data/$today/colorado.csv
GET https://www.tn.gov/content/dam/tn/health/documents/cedep/novel-coronavirus/datasets/Public-Dataset-Age.XLSX > data/$today/tn.xlsx
=======
GET https://opendata.arcgis.com/datasets/90cc1ace62254550879f18cf94ca216b_0.csv > data/$today/colorado.csv
GET https://www.tn.gov/content/dam/tn/health/documents/cedep/novel-coronavirus/datasets/Public-Dataset-Age.XLSX > data/$today/tn.xlsx

GET https://opendata.arcgis.com/datasets/b913e9591eae4912b33dc5b4e88646c5_10.csv?outSR=%7B%22latestWkid%22%3A3857%2C%22wkid%22%3A102100%7D > data/Wisconsin.csv
Rscript scripts/Wisconsin_extraction.R
>>>>>>> 79f27dcfaecb79581e8797d83af7bb7d17a41edd
