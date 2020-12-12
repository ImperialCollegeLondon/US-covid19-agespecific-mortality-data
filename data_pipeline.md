# Data Pipeline

The main entry point is `make files`. It is recommended that you obtain all the dependencies through `pip install -r requirements.txt`.

I recommend using:

- `virtualenv`: https://virtualenv.pypa.io/en/stable/installation.html
- `conda`
- `pipenv`
- `venv`

You will also need to install `GET` by running

```
sudo apt-get install libwww-perl
```

The easiest way would be to use Docker to setup the environment, which is explained in the last section of this document.

## Scripts
`make files` will except the `files` task in `Makefile`, which currently is composed of just running the script `./download_files.sh`:

- This script first sets a date in the local environment, so we know which date we're scraping for
- Then we create new folders in `data` and `pdfs` for the date.
- First, execute `python scripts/age_extraction.py` to extract the below states. You can read more about it in the [code](https://github.com/ImperialCollegeLondon/US-covid19-agespecific-mortality-data/blob/master/scripts/age_extraction.py)

    - Georgia: `ZIP file`
    - CDC: `csv`
    - Washington: `xlsx`
    - Texas: `xlsx`
    - Connecticut: `csv`
    - Minnesota: `JSON`
    - Virginia: `csv`
    - DC: `xlsx`
    - NYC: `json`
    
- Then a series of `GET` requests to the web API. This basically just downloads the CSVs directly.
- `python scripts/extraction_try.py`, which downloads data that are in webpage, xlsx or PDF format. Some of the data are presented in a dashboard, which means that we can only take screenshots and then manually extract the data later by hand. You can read more about it in the [code](https://github.com/ImperialCollegeLondon/US-covid19-agespecific-mortality-data/blob/master/scripts/extraction_try.py)


- `python scripts/get_nm.py`, which runs the [script](https://github.com/ImperialCollegeLondon/US-covid19-agespecific-mortality-data/blob/master/scripts/get_nm.py) to get New Mexico data. The data gets dumped into `data` as a `JSON` file.


## General procedure

**PDFs**
- We use `fitz` in order to read data off the PDFs and then save them to `JSON` or `CSV` format.

**CSVs, JSON**
- These can be downloaded directly

**XLSX**
- These can be processed @Melodie

**Static Webpages (HTML)**
- We save the html and extract the data using `BeautifulSoup` to get the data, and then save it in `JSON` format

**Dynamic Webpages (Dashboard)**
- We use `selenium` in order to render a webpage and also switch to the right page. Then we get the data via its `path` or `css` (find from the `inspect`) and save it into `JSON` format

**Screenshots/PNGs**
- To record the data published in the dynamic webpages

## GitHub Actions config files

- These are the configuration scripts for GitHub Actions, which basically runs the configured tasks automatically everyday.
- Within the scripts, there are different jobs being listed. Within `build-and-deploy`, there are `name`'s that indicate the checkpoints the job. These get run in order. Most of them are self-explanatory.
- `runs-on` indicates the operating system of the machine that we request from GitHub and use for the workflow
- The one that executes the data scraping and subsequent storage is `Cache, process and update`
- The following indicates when the jobs get run each day. Here, `08 23 * * * ` just means that it will run at 23:08 UTC every day.
```
name: Run daily update
on:
  schedule:
    - cron: "08 23 * * *"
```

- `env` basically has configured AWS access keys (it's located in the secrets tab of the repository, but you can leave it as it is unless you're switching to another cloud storage bucket).

There are 3 components listed on GitHub, which can be found in the `.github/workflows` folder.

[**GitHub Main Updates**](https://github.com/ImperialCollegeLondon/US-covid19-agespecific-mortality-data/blob/master/.github/workflows/update_data.yml)
- This first clones the data on GitHub and then runs the `Update Data Sources` task. We also make a copy of the repo called `output`.
- We first execute `make files`, and then copy all the updated data into `output`. 
- Then we `git add` and then push to the `update_data` branch on GitHub.

[**S3 Updates**](https://github.com/ImperialCollegeLondon/US-covid19-agespecific-mortality-data/blob/master/.github/workflows/update_data_to_s3.yml)
- This first clones the data on GitHub and then runs the `Update Data Sources` task. We also make a copy of the repo called `output`.
- We then run `aws s3 ls s3://$AWS_BUCKET/update_data/pdfs/florida/ > existing_assets_florida` to find out what's already in the cloud storage bucket
- We first execute `make files`, and then copy all the updated data into `output`. 
- We also run `python scripts/florida_extraction.py` to scrape data from Florida.
- Finally, a series of `s3` commands to push all the data to the cloud storage bucket.

[**Test**](https://github.com/ImperialCollegeLondon/US-covid19-agespecific-mortality-data/blob/master/.github/workflows/test.yml)
- This does the same thing as the above 2 except it doesn't update any existing database. This just serves as something you can use for testing.
- This gets executed everytime there is a pull request or commit.

## Data processing

Using the raw data extracted from the DoH websites, we reconstuct time series of age-specific COVID-19 attributable death counts for every state. 

#### Where to find
The latest data are available in `data/processed/latest/DeathsByAge_US.csv`.

#### Usage
To process the raw data, run
```R
$ Rscript scripts/process.data.R
```

#### Procedure
##### Pre-processing adjustments
We reconstruct time series for every location and age band, therefore all extracted data need to have the same age bands. If the DoH changes the reported age bands at time $t$ and,

- the old age bands can be used to find the new age bands, then we find the mortality counts by the old age bands for every data from $t$ before processing.
- the old age bands cannot be used to find the new age bands, then we truncate the time series: $t$ becomes the first day of the time series and all data extracted before $t$ are ignored.

##### Processing stages

1. Read the data

  a. If a complete time series records of age-specific COVID-19 attributable death burden is available
      - Use only the last data available
      - Every state has its own processing function depending on the data format 
      
  b. If daily snapshots of age-specific COVID-19 attributable death burden are available
      - Use every data ever extracted
      - if CSV or XLSX: the state has its own processing function 
      - if JSON: common processing function 


2. Ensure that the mortality counts are strictly increasing 
      - some DoH updates indicated a decreasing mortality count from one day to the next.
      - In this case, we set the mortality count on the earliest day to match the mortality count on the most recent day.


3. Find daily deaths
      - some days had missing data, usually either because no updates were reported, because the webpage failed or because the URL of the website had mutated. 
      - The missing daily mortality count were imputed, assuming a constant increase in daily mortality count between days with data. 


4. Check that the reconstructed cumulative deaths on the last day match the ones reported in the latest data.

The script that acts as a spine for those four stages is `utils/obtain.data.R`. Functions for stage 1 are in `utils/read.daily-historical.data.R` and `utils/read.json.data.R`. Functions from stage 2, 3 are in `utils/summary_functions.R`. Function for stage 4 is in `utils/sanity.check.processed.data.R`.

##### Post-processing adjustments 
After reconstructing the time series, we make final adjustements for analysis:

1. Modify the age bands boundaries from the ones declared by the Department of Health, such that they reflect the closest age bands in the set:
\begin{equation}
\mathcal{A}= \Big\{ [0-4], [5-9], \dots, [75-79], [80-84], [85+] \Big\}.
\end{equation}
For example, age band $[0$-$17]$ becomes $[0$-$19]$ and age band $[61$-$65]$. 

2. Keep only days that match closely with JHU overall mortality counts.

Both data set, adjusted and non adjusted are available, `DeathsByAge_US_adj.csv` and `DeathsByAge_US.csv`.

## Docker 
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