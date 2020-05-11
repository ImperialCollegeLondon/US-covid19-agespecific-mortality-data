import fitz
from datetime import date, timedelta, datetime
from dateutil.parser import parse as parsedate
import json
from os.path import basename, join
from os import system
from glob import glob
from bs4 import BeautifulSoup, SoupStrainer
import requests
import subprocess
import warnings


class AgeExtractor:
    def __init__(self):
        self.today = date.today().strftime("%Y-%m-%d")

    def get_cdc(self):
        ## now obtain PDF update date
        r = requests.get(
            "https://data.cdc.gov/api/views/9bhg-hcku/rows.csv", verify=False,
        )
        ## the reports are always published 1 day later (possibly!)
        data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        # check if this data is in the data folder already
        existing_assets = list(map(basename, glob("data/{}/cdc.csv".format(data_date))))
        if existing_assets:
            warnings.warn("CDC data already up to date up to {}".format(data_date))
        else:
            system(
                "wget --no-check-certificate -O data/{}/cdc.csv https://data.cdc.gov/api/views/9bhg-hcku/rows.csv".format(
                    data_date
                )
            )


    def get_georgia(self):
        ## now obtain PDF update date
        r = requests.head("https://ga-covid19.ondemand.sas.com/docs/ga_covid_data.zip")
        ## the reports are always published 1 day later (possibly!)
        data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        # check if this data is in the data folder already
        existing_assets = list(
            map(basename, glob("data/{}/georgia.csv".format(data_date)))
        )
        if existing_assets:
            warnings.warn("Georgia data already up to date up to {}".format(data_date))
        else:
            system(
                "wget --no-check-certificate -O georgia.zip https://ga-covid19.ondemand.sas.com/docs/ga_covid_data.zip;unzip georgia.zip; rm countycases.csv demographics.csv georgia.zip; mv deaths.csv data/{}/georgia.csv".format(
                    data_date
                )
            )

    def get_washington(self):
        ## now obtain PDF update date
        r = requests.head(
            "https://www.doh.wa.gov/Portals/1/Documents/1600/coronavirus/data-tables/PUBLIC_CDC_Event_Date_SARS.xlsx"
        )
        ## the reports are always published 1 day later (possibly!)
        data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        # check if this data is in the data folder already
        existing_assets = list(
            map(basename, glob("data/{}/washington.xlsx".format(data_date)))
        )
        if existing_assets:
            warnings.warn(
                "Washington data already up to date up to {}".format(data_date)
            )
        else:
            system(
                "wget --no-check-certificate -O data/{}/washington.xlsx https://www.doh.wa.gov/Portals/1/Documents/1600/coronavirus/data-tables/PUBLIC_CDC_Event_Date_SARS.xlsx".format(
                    data_date
                )
            )

    def get_texas(self):
        ## now obtain PDF update date
        r = requests.head(
            "https://dshs.texas.gov/coronavirus/TexasCOVID19CaseCountData.xlsx",
            verify=False,
        )
        ## the reports are always published 1 day later (possibly!)
        data_date = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        # check if this data is in the data folder already
        existing_assets = list(
            map(basename, glob("data/{}/texas.xlsx".format(data_date)))
        )
        if existing_assets:
            warnings.warn("Texas data already up to date up to {}".format(data_date))
        else:
            system(
                "wget --no-check-certificate -O data/{}/texas.xlsx https://dshs.texas.gov/coronavirus/TexasCOVID19CaseCountData.xlsx".format(
                    data_date
                )
            )

    def get_new_jersey(self):
        existing_assets = list(map(basename, glob("pdfs/new_jersey/*.pdf")))
        existing_dates = [pdf_date.split(".")[0] for pdf_date in existing_assets]

        ## now obtain PDF update date
        r = requests.head(
            "https://www.nj.gov/health/cd/documents/topics/NCOV/COVID_Confirmed_Case_Summary.pdf"
        )
        ## the reports are always published 1 day later (possibly!)
        pdf_date = (parsedate(r.headers["Last-modified"]) - timedelta(days=1)).strftime(
            "%Y-%m-%d"
        )
        if pdf_date in existing_dates:
            warnings.warn(
                "PDF last updated on {}. Please wait for the latest published report".format(
                    pdf_date
                )
            )

        else:
            system(
                "wget --no-check-certificate -O pdfs/new_jersey/{}.pdf https://www.nj.gov/health/cd/documents/topics/NCOV/COVID_Confirmed_Case_Summary.pdf".format(
                    pdf_date
                )
            )
            age_data = {}
            doc = fitz.Document("pdfs/new_jersey/{}.pdf".format(pdf_date))
            lines = doc.getPageText(0).splitlines()
            # remove \xa0 separators
            lines = list(map(lambda v: v.replace("\xa0", " "), lines))
            ## find key word to point to the age data table
            for num, l in enumerate(lines):
                if "0 to 4" in l:
                    line_num = num
                    break
            lines = lines[line_num:]
            age_data["0-4"] = lines[1]
            age_data["5-17"] = lines[4]
            age_data["18-29"] = lines[7]
            age_data["30-49"] = lines[10]
            age_data["50-64"] = lines[13]
            age_data["65-79"] = lines[16]
            age_data["80+"] = lines[19]

            with open("data/{}/new_jersey.json".format(pdf_date), "w") as f:
                json.dump(age_data, f)

    def get_florida(self):
        # check existing assets
        existing_assets = list(map(basename, glob("pdfs/florida/*.pdf")))

        headers = requests.utils.default_headers()
        url = "https://www.floridadisaster.org/covid19/covid-19-data-reports/"
        req = requests.get(url, headers)
        soup = BeautifulSoup(req.content, "html.parser")
        covid_links = []
        for links in soup.find_all("a"):
            link = links.get("href")
            if link and "/global" == link[:7]:
                pdf_name = basename(link)
                # check if pdf is already up to date
                if (
                    pdf_name not in existing_assets
                    and pdf_name != "covid-19-data---daily-report-2020-03-24-1657.pdf"
                ):
                    covid_links.append(pdf_name)

        # download these assets
        api_base_url = "https://www.floridadisaster.org/globalassets/covid19/dailies"
        for pdf_name in covid_links:
            subprocess.run(
                [
                    "wget",
                    "--no-check-certificate",
                    "-O",
                    "pdfs/florida/{}".format(pdf_name),
                    join(api_base_url, pdf_name),
                ]
            )

        # extract the latest data for each day
        existing_assets = glob("pdfs/florida/*.pdf")
        existing_assets.sort()
        usable_assets = {}
        for pdf_path in existing_assets:
            pdf_date = basename(pdf_path).split("report-")[1][:10]
            if datetime.strptime(pdf_date, "%Y-%m-%d") >= datetime.strptime(
                "2020-03-27", "%Y-%m-%d"
            ):
                usable_assets[pdf_date] = pdf_path

        for day in usable_assets.keys():
            age_data = {}
            doc = fitz.Document(usable_assets[day])
            lines = doc.getPageText(1).splitlines()
            lines += doc.getPageText(2).splitlines()
            lines += doc.getPageText(3).splitlines()
            ## find key word to point to the age data table
            for num, l in enumerate(lines):
                if "years" in l:
                    line_num = num
                    age_data[lines[line_num]] = lines[line_num + 5]

            with open("data/{}/florida.json".format(day), "w") as f:
                json.dump(age_data, f)

    # def get_connecticut(self):
    #     # check existing assets
    #     existing_assets = list(map(basename, glob("pdfs/connecticut/*.pdf*")))
    #     api_base_url = "https://portal.ct.gov/-/media/Coronavirus/"
    #     date_diff = date.today() - date(2020, 3, 22)
    #     covid_links = []

    #     for i in range(date_diff.days + 1):
    #         day = date(2020, 3, 22) + timedelta(days=i)
    #         day = day.strftime("%-m%d%Y")
    #         pdf_name = "CTDPHCOVID19summary{}.pdf?la=en".format(day)
    #         covid_links.append(pdf_name)

    #         if pdf_name not in existing_assets:
    #             try:
    #                 subprocess.run(
    #                     [
    #                         "wget",
    #                         "--no-check-certificate",
    #                         "-O",
    #                         "pdfs/connecticut/{}".format(pdf_name),
    #                         join(api_base_url, pdf_name),
    #                     ]
    #                 )

    #             except:
    #                 warnings.warn(
    #                     "Warning: Report for Connecticut {} is not available".format(
    #                         day
    #                     )
    #                 )

    #     # TODO: extract the data from the graphs, a mixture of PDFS/SVGS and JPEG
    def get_connecticut(self):
        ## now obtain PDF update date
        r = requests.get(
            "https://data.ct.gov/api/views/ypz6-8qyf/rows.csv", verify=False,
        )
        ## the reports are always published 1 day later (possibly!)
        data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        # check if this data is in the data folder already
        existing_assets = list(map(basename, glob("data/{}/connecticut.csv".format(data_date))))
        if existing_assets:
            warnings.warn("Connecticut data already up to date up to {}".format(data_date))
        else:
            system(
                "wget --no-check-certificate -O data/{}/connecticut.csv https://data.ct.gov/api/views/ypz6-8qyf/rows.csv".format(
                    data_date
                )
            )
    def get_massachusetts(self):
        # check existing assets
        existing_assets = list(map(basename, glob("pdfs/massachusetts/*.pdf")))
        api_base_url = "https://www.mass.gov/doc/"
        date_diff = date.today() - date(2020, 4, 20)
        covid_links = []

        for i in range(date_diff.days + 1):
            day = date(2020, 4, 20) + timedelta(days=i)
            day = day.strftime("%B-%-d-%Y").lower()
            pdf_name = "covid-19-dashboard-{}/download".format(day)
            covid_links.append(pdf_name)

            if pdf_name.split("/")[0] + ".pdf" not in existing_assets:
                try:
                    subprocess.run(
                        [
                            "wget --no-check-certificate",
                            "-O",
                            "pdfs/massachusetts/{}".format(pdf_name[:-9] + ".pdf"),
                            join(api_base_url, pdf_name),
                        ]
                    )
                except:
                    warnings.warn(
                        "Warning: Report for Massachusetts {} is not available".format(
                            day
                        )
                    )

    # def get_nyc(self):
    #     with open('data/nyc/nyc_commits.json', "rb") as json_file:
    #         data = json.load(json_file)

    #     commit_hist = [(f["sha"], f["commit"]["author"]["date"][:10]) for f in data]
    #     commit_hist.reverse()
    #     commit_hist_latest = {}
    #     # now only take the latest commit daily
    #     for commit in commit_hist:
    #         commit_hist_latest[commit[1]] = commit[0]

    #     for date in commit_hist_latest.keys():
    #         subprocess("wget --no-check-certificate -O data/nyc/{}.csv https://raw.githubusercontent.com/nychealth/coronavirus-data/{}/by-age.csv".format(date, commit_hist_latest[date]))

    def get_nyc(self):
        # check existing assets
        existing_assets = list(map(basename, glob("pdfs/nyc/*.pdf")))
        api_base_url = "https://www1.nyc.gov/assets/doh/downloads/pdf/imm/"
        date_diff = date.today() - date(2020, 4, 14)
        covid_links = []

        for i in range(date_diff.days + 1):
            day = date(2020, 4, 14) + timedelta(days=i)
            day_old_format = day.strftime("%Y-%m-%d")
            day = day.strftime("%m%d%Y").lower()
            pdf_name = "covid-19-deaths-confirmed-probable-daily-{}.pdf".format(day)
            covid_links.append(pdf_name)

            if pdf_name not in existing_assets:
                try:
                    subprocess.run(
                        [
                            "wget",
                            "--no-check-certificate",
                            "-O",
                            "pdfs/nyc/{} {}".format(pdf_name),
                            join(api_base_url, pdf_name),
                        ]
                    )
                    # now scrape the PDFs
                    age_data = {}
                    doc = fitz.Document(
                        "pdfs/nyc/covid-19-deaths-confirmed-probable-daily-{}.pdf".format(
                            day
                        )
                    )
                    lines = doc.getPageText(0).splitlines()
                    ## find key word to point to the age data table
                    for num, l in enumerate(lines):
                        if "0 to 17" in l:
                            line_num = num
                            break

                    lines = lines[line_num:]
                    age_data["0-17"] = [lines[1], lines[2]]
                    age_data["18-44"] = [lines[4], lines[5]]
                    age_data["45-64"] = [lines[7], lines[8]]
                    age_data["65-76"] = [lines[10], lines[11]]
                    age_data["75+"] = [lines[13], lines[14]]
                    age_data["unknown"] = [lines[16], lines[17]]
                    with open("data/{}/nyc.json".format(day_old_format), "w") as f:
                        json.dump(age_data, f)
                except:
                    warnings.warn(
                        "Warning: Report for  NYC {} is not available".format(day)
                    )

    def get_all(self):
        """TODO: running get_*() for every state
        """
        return NotImplementedError()


if __name__ == "__main__":
    ageExtractor = AgeExtractor()
    ageExtractor.get_georgia()
    ageExtractor.get_cdc()
    ageExtractor.get_washington()
    ageExtractor.get_texas()
    ageExtractor.get_new_jersey()
    ageExtractor.get_florida()
    ageExtractor.get_connecticut()
    ageExtractor.get_massachusetts()
    ageExtractor.get_nyc()
