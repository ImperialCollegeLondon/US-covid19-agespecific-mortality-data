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

To extract and process, run
```
make files
```
This will get you the latest data in `data/$DATE` and `pdfs/$DATE`.

## PDF extractions
We use Requests to make HTTP/HTTPS requests to a web API, BeautifulSoup to extract the download links in the HTML page and Fitz to extract the data within the PDF. The resulting data is stored in a `.json` file in `data/$DATE`.

## non-PDF extractions (e.g. csvs, xlsx ...)

First we download the raw files to `data/$today` using `download_files.sh`. Then, we process it via scripts in `scripts`. This is summarised in `Makefile` in the `make files` directive.

## State specifications
| Country        | Date record start           | Notes and link  |
| ------------- |:-------------:| -----:|
| Florida| 2020-03-26 |[link](https://www.floridadisaster.org/covid19/covid-19-data-reports/); file string; age data on page 3 table: `covid-19-data---daily-report-$year-$month-$day-$time.pdf` |
| Florida| 2020-03-26 | [link](https://www.floridadisaster.org/covid19/covid-19-data-reports/) |
| Florida| 2020-03-26 | [link](https://www.floridadisaster.org/covid19/covid-19-data-reports/) |
| Florida| 2020-03-26 | [link](https://www.floridadisaster.org/covid19/covid-19-data-reports/) |
| Florida| 2020-03-26 | [link](https://www.floridadisaster.org/covid19/covid-19-data-reports/) |