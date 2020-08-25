![Run daily update](https://github.com/MJHutchinson/US-covid19-data-scraping/workflows/Run%20daily%20update/badge.svg?branch=master) ![Run daily update to s3](https://github.com/MJHutchinson/US-covid19-data-scraping/workflows/Run%20daily%20update%20to%20s3/badge.svg)

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
This will get you csv files for every state with variables *age*, *date*, *daily.deaths* and (state) *code* in `data/processed/$DATE/`.

3. To create figures, run
```
Rscript scripts/plot.comparison.and.timeseries.R
```
This will get you pdfs in `figures/$DATE/` of 
* Comparison between extracted data from the Department of Health and JHU overall deaths as well as,
* Time series of overall deaths for every state.


## PDF extractions
We use Requests to make HTTP/HTTPS requests to a web API, BeautifulSoup to extract the download links in the HTML page and Fitz to extract the data within the PDF. The resulting data is stored in a `.json` file in `data/$DATE`.

## non-PDF extractions (e.g. csvs, xlsx ...)

We use Requests to make HTTP/HTTPS requests to a web API, checking whether the data is up-to-date. We then download the raw files to `data/$date`, via `scripts/age_extraction.py`. This is summarised in `Makefile` in the `make files` directive.

## Dynamic websites

We use webdriver from selenium to find the elements and extract the corresponding data. 


## Warnings (not updated since 2020-06-10)
### Updates
- Florida did not publish a report on 2020-05-09
- South Carolina data have not been updated on 2020-05-17
- Iowa did not update the website on 2020-05-18
- Idaho did not update the website on 2020-05-18
- Missouri change website on the 2020-05-20 and did not update
- Indiana did not update the data on 2020-05-30
- Washingtin did not update the website on 2020-06-12
- Mississippi did not update the website on 2020-06-10

### Website dynamics
- For Washington, the download URL keeps changing between using `-` and `_` separators. When there's an error, simply use the recommended line of code in `get_washington()`
- For Missouri, the website is changed on 2020-05-21, cannot find the timestamp
- Delware did not update the website on 2020-05-21
- For Oklahoma, website changed on 2020-06-06

### About the data
- For North Carolina, the total death number is updated daily, but the age death data is not updated daily. The website format changes from 2020-05-20 
- NY and NJ have a 1 day latency, meaning that the cumulative deaths we extract on day t are the cumulative deaths in day t-1
- From 2020-06-04, age band 0-9 was added for Kentucky 


## About
### Licence
This data set is licensed under the Creative Commons Attribution 4.0 International (CC BY 4.0) by Imperial College London on behalf of its COVID-19 Response Team. Copyright Imperial College London 2020.

### Warranty
Imperial makes no representation or warranty about the accuracy or completeness of the data nor that the results will not constitute in infringement of third-party rights. 
Imperial accepts no liability or responsibility for any use which may be made of any results, for the results, nor for any reliance which may be placed on any such work or results.

### Cite 
Attribute the data as the "COVID-19 Age specific Mortality Data Repository by the Imperial College London COVID-19 Response Team", and the urls sepecified below.

| State        | Date record start           | Link(s)  | Notes |
| ----------- |:-----------------:| -----:| ------:|
| Alabama | 2020-05-03 | [link](https://alpublichealth.maps.arcgis.com/apps/opsdashboard/index.html#/6d2771faa9da4a2786a509d82c8cf0f7) | dashboard updated daily and replaced; no historical archive |
| Alaska | 2020-06-09 | [link](https://coronavirus-response-alaska-dhss.hub.arcgis.com/datasets/summary-tables) | metadata updated daily and replaced; no historical archive |
| Arizona | 2020-05-13 | [link](https://www.azdhs.gov/preparedness/epidemiology-disease-control/infectious-disease-epidemiology/covid-19/dashboards/index.php) | dashboard updated daily and replaced; no historical archive | 
| California | 2020-05-13 | [link](https://public.tableau.com/views/COVID-19CasesDashboard_15931020425010/Cases?:embed=y&:showVizHome=no) | dashboard updated daily and replaced; no historical archive | 
| Colorado| 2020-03-23 | [link](https://data-cdphe.opendata.arcgis.com/datasets/cdphe-covid19-state-level-open-data-repository?geometry=-125.744%2C35.977%2C-85.358%2C41.950) | metadata updated daily; full time series; LINK DIED ON 2020-08-20 |
| Connecticut | 2020-04-05 | [link](https://data.ct.gov/Health-and-Human-Services/COVID-19-Cases-and-Deaths-by-Age-Group/ypz6-8qyf); metadata updated daily; full time series|
| Delaware | 2020-05-12 | [link](https://myhealthycommunity.dhss.delaware.gov/locations/state) | dashboard updated daily and replaced; no historical archive |
| District of Columbia | 2020-04-13 | [link](https://coronavirus.dc.gov/page/coronavirus-data) | metadata updated daily; full time series |
| Florida | 2020-03-27 | [link](https://www.floridadisaster.org/covid19/covid-19-data-reports/) | daily report; with historical archive |
| Georgia | 2020-04-27 | [link](https://ga-covid19.ondemand.sas.com/docs/ga_covid_data.zip) | metadata updated daily and replaced; no historical archive |
| Idaho | 2020-05-13 | [link](https://public.tableau.com/profile/idaho.division.of.public.health#!/vizhome/DPHIdahoCOVID-19Dashboard_V2/Story1) | dashboard updated daily and replaced; no historical archive| 
| Illinois | 2020-05-14 | [link](https://www.dph.illinois.gov/covid19/covid19-statistics) | dashboard updated daily and replaced; no historical archive | 
| Indiana | 2020-05-13 | [link](https://www.coronavirus.in.gov/) | dashboard updated daily and replaced; no historical archive | 
| Iowa | 2020-05-13 | [link](https://coronavirus.iowa.gov/pages/outcome-analysis-deaths) | dashboard updated daily and replaced; no historical archive | 
| Kansas | 2020-05-13 | [link](https://www.coronavirus.kdheks.gov/160/COVID-19-in-Kansas) | dashboard updated Monday, Wednesday and Friday, and replaced; no historical archive | 
| Kentucky | 2020-05-13 | [link](https://kygeonet.maps.arcgis.com/apps/opsdashboard/index.html#/543ac64bc40445918cf8bc34dc40e334) | dashboard updated daily and replaced; no historical archive | 
| Louisiana | 2020-05-12 | [link](https://www.arcgis.com/apps/opsdashboard/index.html#/4a6de226701e45bdb542f09b73ee79e1) | dashboard updated daily except on Saturday and replaced; no historical archive|
| Maine | 2020-03-13 | [link](https://www.maine.gov/dhhs/mecdc/infectious-disease/epi/airborne/coronavirus/data.shtml) | metadata updated daily; full time series |
| Maryland | 2020-05-14 | [link](https://coronavirus.maryland.gov/) | dashboard updated daily and replaced; no historical archive | 
| Massachusetts | 2020-04-20 | [link](https://www.mass.gov/info-details/archive-of-covid-19-cases-in-massachusetts) | daily report; with historical archive; STOPPED REPORTING BY AGE ON 2020-08-11 |
| Michigan | 2020-03-21 | (1) `data/req/michigan weekly.csv` and (2) [link](https://www.michigan.gov/coronavirus/0,9753,7-406-98163_98173---,00.html) | (1) data requested to the DoH (2) dashboard updated daily and replaced; no historical archive |
| Mississippi | 2020-04-27 | [link](https://msdh.ms.gov/msdhsite/_static/14,0,420.html) | dashboard updated daily and replaced; no historical archive |
| Missouri | 2020-05-13 | [link](https://health.mo.gov/living/healthcondiseases/communicable/novel-coronavirus/results.php) | dashboard updated daily and replaced; no historical archive |
| Nevada | 2020-06-07 | [link](https://nvhealthresponse.nv.gov) | dashboard updated daily and replaced; no historical archive |
| New Hampshire | 2020-06-07 | [link](https://www.nh.gov/covid19/dashboard/summary.htm) | dashboard updated daily and replaced; no historical archive |
| New Jersey | 2020-05-25 | [link](https://njhealth.maps.arcgis.com/apps/opsdashboard/index.html#/81a17865cb1a44db92eb8eb421703635) | dashboard updated daily and replaced; no historical archive|
| New Mexico | 2020-05-25 | [link](https://cv.nmhealth.org/newsroom/) | daily written report; with history archive |
| New York City | 2020-04-14 | [link](https://www1.nyc.gov/site/doh/covid/covid-19-data-archive.page) until 2020-05-18 and [link](https://github.com/nychealth/coronavirus-data/blob/master/by-age.csv) since | report / csv updated daily, with history archive |
| North Carolina | 2020-05-20 | [link](https://covid19.ncdhhs.gov/dashboard/about-data) | dashboard updated daily and replaced; no historical archive |
| North Dakota | 2020-05-14 | [link](https://www.health.nd.gov/diseases-conditions/coronavirus/north-dakota-coronavirus-cases) | dashboard updated daily and replaced; no historical archive|
| Oklahoma | 2020-05-13 | [link](https://looker-dashboards.ok.gov/embed/dashboards/76) | dashboard updated daily and replaced; no historical archive |
| Oregon | 2020-06-05 | [link](https://public.tableau.com/profile/oregon.health.authority.covid.19#!/vizhome/OregonCOVID-19CaseDemographicsandDiseaseSeverityStatewide/DemographicData?:display_count=y&:toolbar=n&:origin=viz_share_link&:showShareOptions=false) | dashboard updated daily and replaced; no historical archive |
| Pennsylvania | 2020-06-07 | [link](https://experience.arcgis.com/experience/cfb3803eb93d42f7ab1c2cfccca78bf7) | dashboard updated daily and replaced; no historical archive |
| Rhode Island | 2020-06-01 | [link](https://docs.google.com/spreadsheets/d/1c2QrNMz8pIbYEKzMJL7Uh2dtThOJa2j1sSMwiDo5Gz4/edit#gid=31350783) | metadata updated weekly and replaced; no historical archive |
| South Carolina| 2020-05-14 | [link](https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19) | dashboard updated on Tuesday and Friday; no historical archive | 
| Tennessee | 2020-04-09 | [link](https://www.tn.gov/health/cedep/ncov/data/downloadable-datasets.html) | metadata updated daily; full time series |
| Texas | 2020-05-06 | [link](https://dshs.texas.gov/coronavirus/TexasCOVID19CaseCountData.xlsx) | metadata updated daily and replaced; no historical archive |
| Utah | 2020-06-17 | [link](https://coronavirus.utah.gov/case-counts/) | dashboard updated daily and replaced; no historical archive| 
| Vermont | 2020-05-13 | [link](https://vcgi.maps.arcgis.com/apps/opsdashboard/index.html#/f2d395572efa401888eddceebddc318f) | dashboard updated daily and replaced; no historical archive | 
| Virginia | 2020-04-21 | [link](https://data.virginia.gov/Government/VDH-COVID-19-PublicUseDataset-Cases_By-Age-Group/uktn-mwig) | metadata updated daily; full time series |
| Washington| 2020-06-08 | [link](https://www.doh.wa.gov/Emergencies/NovelCoronavirusOutbreak2020COVID19/DataDashboard) | dashboard updated daily and replaced; no historical archive |
| Wisconsin | 2020-03-15 | [link](https://hub.arcgis.com/datasets/wi-dhs::covid-19-historical-data-table) | metadata updated daily; full time series |


