import fitz
from datetime import date, timedelta, datetime
import json
from os.path import basename, join
from glob import glob
from bs4 import BeautifulSoup, SoupStrainer
import requests
import subprocess
import warnings

class AgeExtractor:
    def __init__(self):
        self.today = date.today().strftime("%Y-%m-%d")

    def get_new_jersey(self):
        age_data = {}
        doc = fitz.Document("pdfs/{}/new_jersey.pdf".format(self.today))
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

        with open("data/{}/new_jersey.json".format(self.today), "w") as f:
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
            print(pdf_name)
            subprocess(
                "wget --no-check-certificate -O pdfs/florida/{} {}".format(
                    pdf_name, join(api_base_url, pdf_name)
                )
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

    def get_connecticut(self):
        # check existing assets
        existing_assets = list(map(basename, glob("pdfs/connecticut/*.pdf*")))
        api_base_url = "https://portal.ct.gov/-/media/Coronavirus/"
        date_diff = date.today() - date(2020, 3, 22)
        covid_links = []

        for i in range(date_diff.days + 1):
            day = date(2020, 3, 22) + timedelta(days=i)
            day = day.strftime("%-m%d%Y")
            pdf_name = "CTDPHCOVID19summary{}.pdf?la=en".format(day)
            covid_links.append(pdf_name)

            if pdf_name not in existing_assets:
                try :
                    subprocess(
                        "wget --no-check-certificate -O pdfs/connecticut/{} {}".format(
                            pdf_name, join(api_base_url, pdf_name)
                        )
                    )
                except:
                    warnings.warn("Warning: Report for Connecticut {} is not available".format(day))

        # TODO: extract the data from the graphs, a mixture of PDFS/SVGS and JPEG

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
                    subprocess(
                        "wget --no-check-certificate -O pdfs/massachusetts/{} {}".format(
                            pdf_name[:-9] + ".pdf", join(api_base_url, pdf_name)
                        )
                    )
                except:
                    warnings.warn("Warning: Report for Massachusetts {} is not available".format(day))

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
                print(join(api_base_url, pdf_name))
                try:
                    subprocess(
                        "wget --no-check-certificate -O pdfs/nyc/{} {}".format(
                            pdf_name, join(api_base_url, pdf_name)
                        )
                    )
                    # now scrape the PDFs
                    age_data = {}
                    doc = fitz.Document(
                        "pdfs/nyc/covid-19-deaths-confirmed-probable-daily-{}.pdf".format(day)
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
                    print("Warning: Report for  NYC {} is not available".format(day))

    def get_all(self):
        """TODO: running get_*() for every state
        """
        return NotImplementedError()


if __name__ == "__main__":
    ageExtractor = AgeExtractor()
    ageExtractor.get_new_jersey()
    ageExtractor.get_florida()
    ageExtractor.get_connecticut()
    ageExtractor.get_massachusetts()
    ageExtractor.get_nyc()
