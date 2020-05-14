# US-covid19-data-scraping
Extract and data from various states in the US related to COVID-19. We need the Python dependencies
```
fitz
PyMuPDF
pandas
pyjson
beautifulsoup4
requests
```

1. To extract and clean, run
```
make files
```
This will get you the latest data in `data/$DATE` and `pdfs/$DATE`.

2. To process, run
```
Rscript scripts/process.data.R
```
This will get you csv files for every state with variables *age*, *date*, *daily.deaths* or *weekly.deaths* and *code* in `data/$DATE/processed`.

## PDF extractions
We use Requests to make HTTP/HTTPS requests to a web API, BeautifulSoup to extract the download links in the HTML page and Fitz to extract the data within the PDF. The resulting data is stored in a `.json` file in `data/$DATE`.

## non-PDF extractions (e.g. csvs, xlsx ...)

We use Requests to make HTTP/HTTPS requests to a web API, checking whether the data is up-to-date. We then download the raw files to `data/$date`, via `scripts/age_extraction.py`. This is summarised in `Makefile` in the `make files` directive.

## State specifications
| Country        | Date record start           | Notes and link  |
| ------------- |:-------------:| -----:|
| Florida| 2020-03-26 |[link](https://www.floridadisaster.org/covid19/covid-19-data-reports/); file string; age data on page 3 table: `covid-19-data---daily-report-$year-$month-$day-$time.pdf` |
| Connecticut| 2020-04-05 | [link](https://data.ct.gov/api/views/ypz6-8qyf/rows.csv); full time series|
| Colorado| 2020-03-23 | [link](https://data-cdphe.opendata.arcgis.com/datasets/cdphe-covid19-state-level-open-data-repository); full time series|
| Massachusetts| 2020-04-20 | [link](https://www.mass.gov/doc/covid-19-dashboard-april-20-2020/download); similar to florida |
| New Jersey| 2020-05-06 | [link](https://www.nj.gov/health/cd/documents/topics/NCOV/COVID_Confirmed_Case_Summary.pdf); cumulative, need extracting daily |
| New York City| 2020-04-14 | [link](https://www1.nyc.gov/assets/doh/downloads/pdf/imm/covid-19-deaths-confirmed-probable-daily-04142020.pdf); daily cumulative, need extracting daily|
| Georgia| 2020-04-27 | [link](https://ga-covid19.ondemand.sas.com/docs/ga_covid_data.zip); daily cumulative, need extracting daily; no historical archive; missing data between 2020-04-27 and 2020-05-06|
| Washington| 2020-05-04 | [link](https://www.doh.wa.gov/Portals/1/Documents/1600/coronavirus/data-tables/PUBLIC-CDC-Event-Date-SARS.xlsx); daily cumulative, need extracting daily; no historical archive|
| CDC| 2020-05-06 | [link](https://data.cdc.gov/api/views/9bhg-hcku/rows.csv); daily cumulative, need extracting daily; no historical archive|
| Texas| 2020-05-06 | [link](https://dshs.texas.gov/coronavirus/TexasCOVID19CaseCountData.xlsx); daily cumulative, need extracting daily; no historical archive|

## Warnings
- Florida did not publish a report on 2020-05-09
- NY and NJ have a 1 day latency, meaning that the cumulative deaths we extract on day t are the cumulative deaths in day t-1
- For Washington, the download URL keeps changing between using `-` and `_` separators. When there's an error, simply use the recommended line of code in `get_washington()`

## Time series of extracted data as of 2020-05-12
![](figures/time.series_allstates.png)
