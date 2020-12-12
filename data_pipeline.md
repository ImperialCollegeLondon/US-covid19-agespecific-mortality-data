# Data Pipeline

The main entry point is `make files`. It is recommended that you obtain all the dependencies through `pip install -r requirements.txt`.


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
- `python scripts/extraction_try.py`, which downloads data that are in webpage, PNG or PDF format. Some of the data are presented in a dashboard, which means that we can only take screenshots and then manually extract the data later by hand.
- `python scripts/get_nm.py`, which runs the [script](https://github.com/ImperialCollegeLondon/US-covid19-agespecific-mortality-data/blob/master/scripts/get_nm.py) to get New Mexico data. The data gets dumped into `data` as a `JSON` file.


## General procedure

**PDFs**
- We use `fitz` in order to read data off the PDFs and then save them to `JSON` or `CSV` format.

**CSVs, JSON**
- These can be downloaded directly

**XLSX**
- These can be processed @Melodie

**Screenshots/PNGs**
- @Yu's expertise

**Static Webpages (HTML)**
- @Yu's expertise

## Data processing

@Melodie's expertise


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

## AWS storage
For larger datasets, such as ones in PDF or PNG format, we don't store them on GitHub but rather on a cloud storage bucket. We are currently using AWS S3 for this.

- First, obtain access instructions and keys from someone in the team via Whatsapp or Telegram
- Then, understand how S3 works through an online tutorial or stackoverflow. The basic commands we use are `aws s3 cp` and `aws s3 ls`.
