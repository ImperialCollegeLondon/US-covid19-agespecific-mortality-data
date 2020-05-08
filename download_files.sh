#!/bin/bash
today=$(date +'%Y-%m-%d')
echo "$today"
mkdir -p data/$today/
mkdir -p pdfs/$today/
# csvs, excel sheets
## CDC official cumulative
wget --no-check-certificate -O data/$today/cdc.csv https://data.cdc.gov/api/views/9bhg-hcku/rows.csv

# washington
wget --no-check-certificate -O data/$today/washington.xlsx https://www.doh.wa.gov/Portals/1/Documents/1600/coronavirus/data-tables/PUBLIC-CDC-Event-Date-SARS.xlsx
## new york
wget--no-check-certificate -O data/$today/new_york.csv https://raw.githubusercontent.com/nychealth/coronavirus-data/master/by-age.csv
## georgia
wget --no-check-certificate -O georgia.zip https://ga-covid19.ondemand.sas.com/docs/ga_covid_data.zip
unzip georgia.zip
rm countycases.csv demographics.csv georgia.zip
mv deaths.csv data/$today/georgia.csv
## texas
wget --no-check-certificate -O data/$today/texas.xlsx https://dshs.texas.gov/coronavirus/TexasCOVID19CaseCountData.xlsx 

## new jersey
wget --no-check-certificate -O pdfs/$today/new_jersey.pdf https://www.nj.gov/health/cd/documents/topics/NCOV/COVID_Confirmed_Case_Summary.pdf

## mass
# https://www.mass.gov/doc/covid-19-dashboard-april-30-2020/download

## florida, connecticut
python scripts/age_extraction.py

