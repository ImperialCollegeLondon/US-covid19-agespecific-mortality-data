# US-covid19-data-scraping
Extract and data from various states in the US related to COVID-19. We need the Python dependencies
```
fitz
PyMuPDF
pandas
pyjson
beautifulsoup4
requests
selenium
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

## Dynamic websites

We use webdriver from selenium to find the elements and extract the corresponding data. 

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
| Louisiana| 2020-05-12| [link](http://ldh.la.gov/coronavirus/); daily updated and replaced, need extracting daily; no historical archive|
| Oklahoma| 2020-05-13| [link](https://looker-dashboards.ok.gov/embed/dashboards/42); daily updated and replaced, need extracting daily; no historical archive|
| North Carolina| 2020-05-13| [link](https://covid19.ncdhhs.gov/dashboard#by-age); daily updated and replaced, need extracting daily; no historical archive|
| Mississippi| 2020-05-12| [link](https://msdh.ms.gov/msdhsite/_static/14,0,420.html); daily updated and replaced, need exreacting daily; no historical archive|
| Missouri| 2020-05-13| [link](https://health.mo.gov/living/healthcondiseases/communicable/novel-coronavirus/results.php);  daily updated and replaced, need exreacting daily; no historical archive|
| Delaware| 2020-05-12| [link](https://myhealthycommunity.dhss.delaware.gov/locations/state); daily updated and replaced, need exreacting daily; no historical archive|
| Vermont| 2020-05-13| [link](https://vcgi.maps.arcgis.com/apps/opsdashboard/index.html#/6128a0bc9ae14e98a686b635001ef7a7); daily updated and replaced, need exreacting daily; no historical archive| 

| Idaho| 2020-05-13| [link](https://public.tableau.com/profile/idaho.division.of.public.health#!/vizhome/DPHIdahoCOVID-19Dashboard_V2/Story1); daily updated and replaced, need exreacting daily; no historical archive| 
| Arizona| 2020-05-13| [link](https://www.azdhs.gov/preparedness/epidemiology-disease-control/infectious-disease-epidemiology/covid-19/dashboards/index.php); daily updated and replaced, need exreacting daily; no historical archive| 
| Kansas| 2020-05-13| [link](https://www.coronavirus.kdheks.gov/160/COVID-19-in-Kansas); daily updated and replaced, need exreacting daily; no historical archive| 
| South Carolina| 2020-05-13| [link](https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19); updated not daily; no historical archive| 
|Ioawa| 2020-05-13| [link](https://coronavirus.iowa.gov/pages/case-counts); daily updated and replaced, need exreacting daily; no historical archive| 
| North Dakota| 2020-05-14| [link](https://www.health.nd.gov/diseases-conditions/coronavirus/north-dakota-coronavirus-cases); daily updated and replaced, need exreacting daily; no historical archive| 
| Kentucky| 2020-05-13| [link](https://kygeonet.maps.arcgis.com/apps/opsdashboard/index.html#/543ac64bc40445918cf8bc34dc40e334); daily updated and replaced, need exreacting daily; no historical archive| 
| California| 2020-05-13| [link](https://public.tableau.com/views/COVID-19PublicDashboard/Covid-19Public?%3Aembed=y&%3Adisplay_count=no&%3AshowVizHome=no); daily updated and replaced, need exreacting daily; no historical archive| 
| Indiana| 2020-05-13| [link](https://www.coronavirus.in.gov/); daily updated and replaced, need exreacting daily; no historical archive| 
| Maryland| 2020-05-14| [link](https://coronavirus.maryland.gov/); daily updated and replaced, need exreacting daily; no historical archive| 


## Warnings
- Florida did not publish a report on 2020-05-09
- NY and NJ have a 1 day latency, meaning that the cumulative deaths we extract on day t are the cumulative deaths in day t-1
- For Washington, the download URL keeps changing between using `-` and `_` separators. When there's an error, simply use the recommended line of code in `get_washington()`
- For North Carolina, the total death number is updated daily, but the age death data is not updated daily

## Time series of extracted data as of 2020-05-12
![](figures/time.series_allstates.png)
