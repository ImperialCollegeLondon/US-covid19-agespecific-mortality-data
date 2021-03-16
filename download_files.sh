#!/bin/bash
today=$(date +'%Y-%m-%d')
echo "$today"
mkdir -p data/$today/
mkdir -p pdfs/$today/

# run python scripts
python scripts/extractor.py
python scripts/selenium_extractor.py
python scripts/nm_pa_extractor.py

# GET method to directly download some data
GET https://data.ct.gov/resource/ypz6-8qyf.json > data/$today/connecticut_2.csv
GET https://opendata.arcgis.com/datasets/ebf62bbdba59497a9dba00aed0c17078_0.csv > data/$today/alaska.csv
GET https://data.virginia.gov/api/views/uktn-mwig/rows.csv?accessType=DOWNLOAD > data/$today/virginia.csv
GET https://opendata.arcgis.com/datasets/859602b5d427456f821de3830f89301c_11.csv?outSR=%7B%22latestWkid%22%3A3857%2C%22wkid%22%3A102100%7D > data/$today/wisconsin.csv
GET https://www.tn.gov/content/dam/tn/health/documents/cedep/novel-coronavirus/datasets/Public-Dataset-Age.XLSX > data/$today/tn.xlsx
GET https://dshs.texas.gov/coronavirus/TexasCOVID19CaseCountData.xlsx > data/$today/texas_total.xlsx
GET https://data.chhs.ca.gov/dataset/f333528b-4d38-4814-bebb-12db1f10f535/resource/e2c6a86b-d269-4ce1-b484-570353265183/download/covid19casesdemographics.csv > data/$today/california.csv
GET https://www.doh.wa.gov/Portals/1/Documents/1600/coronavirus/data-tables/WA_COVID19_Cases_Hospitalizations_Deaths.xlsx > data/$today/washington.xlsx
