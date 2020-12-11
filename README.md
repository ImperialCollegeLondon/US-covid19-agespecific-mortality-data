![Run daily update](https://github.com/ImperialCollegeLondon/US-covid19-data-scraping/workflows/Run%20daily%20update/badge.svg) ![Run daily update to s3](https://github.com/ImperialCollegeLondon/US-covid19-data-scraping/workflows/Run%20daily%20update%20to%20s3/badge.svg)

# Age-specific COVID-19 mortality data in the United-States

## Data 
The user may directly find age-specific mortality by date, age and location in 
```
data/processed/latest/DeathsByAge_US.csv
```
We aim to update the processed data at least once a week. The data set currently includes 44 U.S. states and 2 metropolitan areas, New York City and the District of Columbia.

## Usage 

### Docker
The easiest way for reproducibility is using `docker`. A `Dockerfile` is in the repository.

Run:
```sh
sudo apt-get install docker # for linux. For mac you can use something like brew. In any case,
# you need to install docker onto your machine 
docker build -t usaage .
docker run --rm -t -d --name usaage_container -v $(pwd):/code usaage
```

This will keep a docker container running in the background, which you can inspect using docker ps.

Now all the development can be done in the container and you can edit the code as usual locally (changes will be synced to the docker container since we made it share folders using the flag `-v`). You might need to use Remote-SSH in the VSCODE IDE for convenience. You can also just attach a shell onto the container using `docker exec -it usaage_container /bin/bash`

You can check that everything works by running make all in the container.

### Structure Overview
The code is divided into 2 parts: First, the extraction of the COVID-19 mortality counts data from Department of Health websites. Second, the processing of the extracted data to create a complete time series of age-specific COVID-19 mortality counts for every location. 

### Dependencies
#### Data extraction
- Python version >= 3.6.1
- Python libraries:
```
fitz
PyMuPDF
pandas
pyjson
beautifulsoup4
requests
selenium
```

#### Data processing
- R version >= 4.0.2
- R libraries:
```
data.table
ggplot2 
scales
gridExtra
tidyverse
rjson
readxl
reshape2
```


### 1. Data extraction 
To extract, run
```bash
$ make files
```
This will get you the latest data in `data/$DATE`.

### 2. Data processing 
To process, run
```bash
$ Rscript scripts/process.data.R
```
This will get you a csv file for every state with variables *age*, *date*, *daily.deaths* and (state) *code* in `data/processed/$DATE/`.


## More details about the data extraction

The main entry point is `make files`. 

### Scripts
`make files` will execute the `files` task in `Makefile`, which currently is composed only of the script `./download_files.sh`. This script follows the following steps:

1. Set a date, `$date`, in the local environment
2. Create new folders in `data` and `pdfs` for the `$date`.
3. Run the following scripts:
    - `scripts/age_extraction.py` to extract the locations for which data are available in CSV, XLSX or JSON format.  
    - a series of `GET` requests to the web API. They download CSVs made available by the DoH directly.
    - `scripts/extraction_try.py`, which downloads data that are in webpage, XLSX or PDF format.
    - `python scripts/get_nm.py` to get New Mexico data. 
    

### General procedure

Depending on the data format made available by the DoH, we do the following:

**PDFs**: We use `fitz` in order to read data within PDFs and save them to JSON or CSV format.

**CSVs, XLSX, JSON**: We download the data directly.

**Static Webpages (HTML)**: We save the HTML and extract the data using `BeautifulSoup`, and save them in JSON format.

**Dynamic Webpages (Dashboard)**: We use `selenium` to render a webpage and switch to the right page. Then, if the data is stored in the source code, we find their path or css, extract them and save them to a `JSON` format. Otherwise, if the webpage can be saved as a PDFs, we use `BeautifulSoup` to download the webpage in a PDFs format and `fitz` to extract the data within PDFs. If we cannot use either of the latter options, we take a screenshot of the webpage, and extract the data manually.


**Screenshots/PNGs**: To record the data published in the dynamic webpages


## More details about the data processing
### Procedure
#### Pre-processing adjustments
We reconstruct time series for every location and age band, therefore all extracted data need to have the same age bands. If the DoH changes the reported age bands at time $t$ and,

- the old age bands can be used to find the new age bands, then we find the mortality counts by the old age bands for every data from $t$ before processing.
- the old age bands cannot be used to find the new age bands, then we truncate the time series: $t$ becomes the first day of the time series and all data extracted before $t$ are ignored.

#### Processing stages

1. Read the data
      - If a complete time series records of age-specific COVID-19 attributable death burden is available
          - Use only the last data available
          - Every state has its own processing function depending on the data format 
      
      - If daily snapshots of age-specific COVID-19 attributable death burden are available
          - Use every data ever extracted
          - if CSV or XLSX: the state has its own processing function 
          -  if JSON: common processing function 

2. Ensure that the mortality counts are strictly increasing 
      - some DoH updates indicated a decreasing mortality count from one day to the next.
      - In this case, we set the mortality count on the earliest day to match the mortality count on the most recent day.

3. Find daily deaths
      - some days had missing data, usually either because no updates were reported, because the webpage failed or because the URL of the website had mutated. 
      - The missing daily mortality count were imputed, assuming a constant increase in daily mortality count between days with data. 

4. Check that the reconstructed cumulative deaths on the last day match the ones reported in the latest data.

The script that acts as a spine for those four stages is `utils/obtain.data.R`. Functions for stage 1 are in `utils/read.daily-historical.data.R` and `utils/read.json.data.R`. Functions from stage 2, 3 are in `utils/summary_functions.R`. Function for stage 4 is in `utils/sanity.check.processed.data.R`.

#### Post-processing adjustments 
After reconstructing the time series, we make final adjustements for analysis:

1. Modify the age bands boundaries from the ones declared by the Department of Health, such that they reflect the closest age bands in the set, A = { [0-4], [5-9], ..., [75-79], [80-84], [85+] }. 
For example, age band [0-17] becomes [0-19] and age band [61-65]. 

2. Keep only days that match closely with JHU overall mortality counts.

Both data set, adjusted and non adjusted are available, `DeathsByAge_US_adj.csv` and `DeathsByAge_US.csv`.

## Data source
This table includes a complete list of all sources ever used in the data set. We acknowledge and are grateful to U.S. state Departments of Health for making the primary data available at the following sources:

| State        | Date record start           | Link(s)  | Notes |
| ----------- |:-----------------:| -------:| ------:|
| Alabama | 2020-05-03 | [link](https://alpublichealth.maps.arcgis.com/apps/opsdashboard/index.html#/6d2771faa9da4a2786a509d82c8cf0f7) | dashboard updated daily and replaced; no historical archive |
| Alaska | 2020-06-09 | [link](https://coronavirus-response-alaska-dhss.hub.arcgis.com/datasets/summary-tables) | metadata updated daily and replaced; no historical archive |
| Arizona | 2020-05-13 | [link](https://www.azdhs.gov/preparedness/epidemiology-disease-control/infectious-disease-epidemiology/covid-19/dashboards/index.php) | dashboard updated daily and replaced; no historical archive | 
| California | 2020-05-13 | [link](https://public.tableau.com/views/COVID-19CasesDashboard_15931020425010/Cases?:embed=y&:showVizHome=no) | dashboard updated daily and replaced; no historical archive | 
| Colorado| 2020-03-23 | (1) [link](https://data-cdphe.opendata.arcgis.com/datasets/cdphe-covid19-state-level-open-data-repository?geometry=-125.744%2C35.977%2C-85.358%2C41.950) until 2020-08-20, (2) [link](https://covid19.colorado.gov/data) since 2020-08-20 |(1) metadata updated daily; full time series; died in 2020-08-20; (2) dashboard updated daily and replaced; no historical archive |
| Connecticut | 2020-04-05 | [link](https://data.ct.gov/Health-and-Human-Services/COVID-19-Cases-and-Deaths-by-Age-Group/ypz6-8qyf) | metadata updated daily; full time series|
| Delaware | 2020-05-12 | [link](https://myhealthycommunity.dhss.delaware.gov/locations/state) | dashboard updated daily and replaced; no historical archive |
| District of Columbia | 2020-04-13 | [link](https://coronavirus.dc.gov/page/coronavirus-data) | metadata updated daily; full time series |
| Florida | 2020-03-27 | [link](https://www.floridadisaster.org/covid19/covid-19-data-reports/) | daily report; with historical archive |
| Hawaii | 2020-09-18 | [link](https://health.hawaii.gov/coronavirusdisease2019/what-you-should-know/current-situation-in-hawaii/) |dashboard updated weekly and replaced |
| Georgia | 2020-04-27 | [link](https://ga-covid19.ondemand.sas.com/docs/ga_covid_data.zip) | metadata updated daily and replaced; no historical archive |
| Idaho | 2020-05-13 | (1) [link](https://public.tableau.com/profile/idaho.division.of.public.health#!/vizhome/DPHIdahoCOVID-19Dashboard_V2/Story1), (2) [link](https://public.tableau.com/profile/idaho.division.of.public.health#!/vizhome/DPHIdahoCOVID-19Dashboard/Home) | dashboard updated daily and replaced; no historical archive ; (1) died on 2020-09-04| 
| Illinois | 2020-05-14 | [link](https://www.dph.illinois.gov/covid19/covid19-statistics) | dashboard updated daily and replaced; no historical archive | 
| Indiana | 2020-05-13 | [link](https://www.coronavirus.in.gov/) | dashboard updated daily and replaced; no historical archive | 
| Iowa | 2020-05-13 | [link](https://coronavirus.iowa.gov/pages/outcome-analysis-deaths) | dashboard updated daily and replaced; no historical archive | 
| Kansas | 2020-05-13 | [link](https://www.coronavirus.kdheks.gov/160/COVID-19-in-Kansas) | dashboard updated Monday, Wednesday and Friday, and replaced; no historical archive | 
| Kentucky | 2020-05-13 | [link](https://kygeonet.maps.arcgis.com/apps/opsdashboard/index.html#/543ac64bc40445918cf8bc34dc40e334) | dashboard updated daily and replaced; no historical archive | 
| Louisiana | 2020-05-12 | [link](https://www.arcgis.com/apps/opsdashboard/index.html#/4a6de226701e45bdb542f09b73ee79e1) | dashboard updated daily except on Saturday and replaced; no historical archive|
| Maine | 2020-03-12 | [link](https://www.maine.gov/dhhs/mecdc/infectious-disease/epi/airborne/coronavirus/data.shtml) | metadata updated daily; full time series |
| Maryland | 2020-05-14 | [link](https://coronavirus.maryland.gov/) | dashboard updated daily and replaced; no historical archive | 
| Massachusetts | 2020-04-20 | [link](https://www.mass.gov/info-details/archive-of-covid-19-cases-in-massachusetts) until 2020-08-11 and [link](https://www.mass.gov/info-details/covid-19-response-reporting) since | (1) daily report, with historical archive; (2) weekly report, with historical archive  |
| Michigan | 2020-03-21 | (1) `data/req/michigan weekly.csv` and (2) [link](https://www.michigan.gov/coronavirus/0,9753,7-406-98163_98173---,00.html) | (1) data requested to the DoH (2) dashboard updated daily and replaced; no historical archive |
| Minnesota | 2020-05-21 | [link](https://www.health.state.mn.us/diseases/coronavirus/stats/index.html) | weekly report, with historical archive |
| Mississippi | 2020-04-27 | [link](https://msdh.ms.gov/msdhsite/_static/14,0,420.html) | dashboard updated daily and replaced; no historical archive |
| Missouri | 2020-05-13 | (1)[link](https://health.mo.gov/living/healthcondiseases/communicable/novel-coronavirus/results.php) and (2)[link](https://showmestrong.mo.gov/data/public-health/) | dashboard updated daily and replaced; no historical archive |
| Nevada | 2020-06-07 | [link](https://nvhealthresponse.nv.gov) | dashboard updated daily and replaced; no historical archive |
| New Hampshire | 2020-06-07 | [link](https://www.nh.gov/covid19/dashboard/summary.htm) | dashboard updated daily and replaced; no historical archive |
| New Jersey | 2020-05-25 | [link](https://njhealth.maps.arcgis.com/apps/opsdashboard/index.html#/81a17865cb1a44db92eb8eb421703635) | dashboard updated daily and replaced; no historical archive|
| New Mexico | 2020-05-25 | [link](https://cv.nmhealth.org/newsroom/) | daily written report; with history archive |
| New York City | 2020-04-14 | [link](https://www1.nyc.gov/site/doh/covid/covid-19-data-archive.page), [link](https://github.com/nychealth/coronavirus-data/blob/master/by-age.csv) since 2020-05-18, [link](https://github.com/nychealth/coronavirus-data/blob/master/totals/by-age.csv) since 2020-11-08 | report / csv updated daily, with history archive |
| North Carolina | 2020-05-20 | [link](https://covid19.ncdhhs.gov/dashboard/about-data) | dashboard updated daily and replaced; no historical archive |
| North Dakota | 2020-05-14 | [link](https://www.health.nd.gov/diseases-conditions/coronavirus/north-dakota-coronavirus-cases) | dashboard updated daily and replaced; no historical archive|
| Oklahoma | 2020-05-13 | [link](https://looker-dashboards.ok.gov/embed/dashboards/76) | dashboard updated daily and replaced; no historical archive |
| Oregon | 2020-06-05 | [link](https://public.tableau.com/profile/oregon.health.authority.covid.19#!/vizhome/OregonCOVID-19CaseDemographicsandDiseaseSeverityStatewide/DemographicData?:display_count=y&:toolbar=n&:origin=viz_share_link&:showShareOptions=false) | dashboard updated dashboard updated on Monday-Friday and sometimes on Saturday and replaced; no historical archive |
| Pennsylvania | 2020-06-07 | (1)[link](https://experience.arcgis.com/experience/cfb3803eb93d42f7ab1c2cfccca78bf7) and (2)[link](https://www.health.pa.gov/topics/disease/coronavirus/Pages/Cases.aspx)| dashboard updated daily and replaced; no historical archive |
| Rhode Island | 2020-06-01 | [link](https://docs.google.com/spreadsheets/d/1c2QrNMz8pIbYEKzMJL7Uh2dtThOJa2j1sSMwiDo5Gz4/edit#gid=31350783) | metadata updated weekly and replaced; no historical archive |
| South Carolina| 2020-05-14 | [link](https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19) | dashboard updated on Tuesday and Friday; no historical archive | 
| Tennessee | 2020-04-09 | [link](https://www.tn.gov/health/cedep/ncov/data/downloadable-datasets.html) | metadata updated daily; full time series |
| Texas | 2020-05-06 | (1) [link](https://dshs.texas.gov/coronavirus/TexasCOVID19CaseCountData.xlsx) until 2020-09-24, (2) [link](https://dshs.texas.gov/coronavirus/TexasCOVID19Demographics.xlsx.asp) since 2020-09-24 | metadata updated daily and replaced; no historical archive |
| Utah | 2020-06-17 | [link](https://coronavirus.utah.gov/case-counts/) | dashboard updated daily and replaced; no historical archive| 
| Vermont | 2020-05-13 | (1) [link](https://vcgi.maps.arcgis.com/apps/opsdashboard/index.html#/f2d395572efa401888eddceebddc318f) until 2020-09-03, (2) [link](https://experience.arcgis.com/experience/85f43bd849e743cb957993a545d17170) since 2020-09-03 | dashboard updated daily and replaced; no historical archive; (1) does not report mortality by age since 2020-09-03 | 
| Virginia | 2020-04-21 | [link](https://data.virginia.gov/Government/VDH-COVID-19-PublicUseDataset-Cases_By-Age-Group/uktn-mwig) | metadata updated daily; full time series |
| Washington| 2020-06-08 | [link](https://www.doh.wa.gov/Emergencies/NovelCoronavirusOutbreak2020COVID19/DataDashboard) | dashboard updated daily and replaced; no historical archive |
| Wisconsin | 2020-03-15 | (1) [link](https://hub.arcgis.com/datasets/wi-dhs::covid-19-historical-data-table) until 2020-10-19, (2) [link](https://data.dhsgis.wi.gov/datasets/covid-19-historical-data-by-state/data?orderBy=GEOID) since 2020-10-19 | metadata updated daily; full time series |
| Wyoming| 2020-09-22| [link](https://health.wyo.gov/publichealth/infectious-disease-epidemiology-unit/disease/novel-coronavirus/covid-19-map-and-statistics/) | dashboard updated daily and replaced; no historical archive |


## About
### Maintainers and Contributors
<p float="left">
  <a href="https://www.imperial.ac.uk/"> <img src="logos/IMP_ML_1CS_4CP_CLEAR%20SPACE.svg" height="100" /> </a> 
  <a href="https://www.ox.ac.uk/"> <img src="logos/ox_brand1_pos.gif" height="100" /> </a>  
  <a href="https://statml.io/"> <img src="logos/cropped-LOGO_512_512.svg-270x270.png" height="100" /> </a>  
</p>


#### Active maintainers (alphabetically)

- [Yu Chen](https://github.com/YuCHENJT) - Department of Mathematics, Imperial College London
- [Michael Hutchinson](https://www.github.com/MJHutchinson) - Department of Statistics, Oxford
- Vidoushee Jogarah - Mary Lister McCammon Fellow, Department of Mathematics, Imperial College London
- [Mélodie Monod](https://github.com/melodiemonod) - Department of Mathematics, Imperial College London
- [Oliver Ratmann](https://github.com/olli0601) - Department of Mathematics, Imperial College London
- [Harrison Zhu](https://github.com/harrisonzhu508) - Department of Mathematics, Imperial College London

#### Contributors

- [Martin McManus](https://github.com/MartinMcManus1) - Department of Mathematics, Imperial College London

### Licence
This data set is licensed under the Creative Commons Attribution 4.0 International (CC BY 4.0) by Imperial College London on behalf of its COVID-19 Response Team. Copyright Imperial College London 2020.

### Warranty
Imperial makes no representation or warranty about the accuracy or completeness of the data nor that the results will not constitute in infringement of third-party rights. 
Imperial accepts no liability or responsibility for any use which may be made of any results, for the results, nor for any reliance which may be placed on any such work or results.

### Cite 
Attribute the data as the "COVID-19 Age specific Mortality Data Repository by the Imperial College London COVID-19 Response Team", and the urls sepecified below.

### Acknowledgements
We acknowledge the support of the EPSRC through the [EPSRC Centre for Doctoral Training in Modern Statistics and Statistical Machine Learning](https://statml.io) at Imperial and Oxford.

### Funding
This research was partly funded by the The Imperial College COVID-19 Research Fund.



