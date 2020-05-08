import fitz
from datetime import date, timedelta
import json
from os.path import basename, join
from os import system
from glob import glob
from bs4 import BeautifulSoup, SoupStrainer
import requests


class AgeExtractor:
    def __init__(self):
        self.today = date.today().strftime("%Y-%m-%d")

    def get_new_jersey(self):
        age_data = {}
        doc = fitz.Document("pdfs/{}/new_jersey.pdf".format(self.today))
        lines = doc.getPageText(0).splitlines()
        # remove \xa0 separators
        lines = list(map(lambda v: v.replace("\xa0", " "), lines))
        lines = lines[37:60]
        age_data["0-4"] = lines[4]
        age_data["5-17"] = lines[7]
        age_data["18-29"] = lines[10]
        age_data["30-49"] = lines[13]
        age_data["50-64"] = lines[16]
        age_data["65-79"] = lines[19]
        age_data["80+"] = lines[22]

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
                if pdf_name not in existing_assets:
                    covid_links.append(pdf_name)

        # download these assets
        api_base_url = "https://www.floridadisaster.org/globalassets/covid19/dailies"
        for pdf_name in covid_links:
            print(pdf_name)
            system(
                "wget --no-check-certificate -O pdfs/florida/{} {}".format(
                    pdf_name, join(api_base_url, pdf_name)
                )
            )

        # TODO: extract the by-age deaths data using the same trick as get_new_jersey()
        # TODO: filter the links after march the 26th

    def get_connecticut(self):
        # check existing assets
        existing_assets = list(map(basename, glob("pdfs/connecticut/*.pdf")))
        api_base_url = "https://portal.ct.gov/-/media/Coronavirus/"
        date_diff = date.today() - date(2020, 3, 22)
        covid_links = []

        for i in range(date_diff.days + 1):
            day = date(2020, 3, 22) + timedelta(days=i)
            day = day.strftime("%-m%d%Y")
            pdf_name = "CTDPHCOVID19summary{}.pdf?la=en".format(day)
            covid_links.append(pdf_name)

            if pdf_name not in existing_assets:
                print(pdf_name, join(api_base_url, pdf_name))
                system("wget --no-check-certificate -O pdfs/connecticut/{} {}".format(pdf_name, join(api_base_url, pdf_name)))

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

            if pdf_name not in existing_assets:
                print(join(api_base_url, pdf_name))
                system("wget --no-check-certificate -O pdfs/massachusetts/{} {}".format(pdf_name[:-9] + ".pdf", join(api_base_url, pdf_name)))

    def get_all(self):
        """TODO: running get_*() for every state
        """
        return NotImplementedError()


if __name__ == "__main__":
    ageExtractor = AgeExtractor()
    # ageExtractor.get_new_jersey()
    # ageExtractor.get_florida()
    # ageExtractor.get_connecticut()
    ageExtractor.get_massachusetts()