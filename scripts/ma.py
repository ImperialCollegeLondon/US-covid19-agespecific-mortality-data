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


    def get_massachusetts(self):
        # check existing assets
        # os.getcwd() # check current path
        existing_assets = list(map(basename, glob("pdfs/massachusetts/*.pdf")))
        if existing_assets == []:
            if not os.path.exists("pdfs/massachusetts"):
                os.mkdir("pdfs/massachusetts")
        api_base_url = "https://www.mass.gov/doc/"
        date_diff = date.today() - date(2020, 4, 20)
        #covid_links = []

        for i in range(date_diff.days + 1):
            dayy = date(2020, 4, 20) + timedelta(days=i)
            day = dayy.strftime("%B-%d-%Y").lower()
            pdf_name = "covid-19-dashboard-{}/download".format(day)
            #covid_links.append(pdf_name)
            url = join(api_base_url, pdf_name)

            if pdf_name.split("/")[0] + ".pdf" not in existing_assets:
                
                if requests.get(url).status_code == 200:
                '''
                    subprocess.run(
                        [
                            "wget --no-check-certificate",
                            "-O",
                            "pdfs/massachusetts/{}".format(pdf_name[:-9] + ".pdf"),
                            url,
                        ]
                    )
                '''
                    url = join(api_base_url, pdf_name)
                    with open("pdfs/massachusetts/" + pdf_name.split("/")[0] + ".pdf", "wb") as f:
                        response = requests.get(url)
                        f.write(response.content)
                    
                    # now scrape the PDFs
                    age_data = {}
                    doc = fitz.Document(
                        "pdfs/massachusetts/covid-19-dashboard-{}.pdf".format(day)
                    )
                    # find the page
                    lines = doc.getPageText(0).splitlines()
                    lines += doc.getPageText(1).splitlines()
                    ## find key word to point to the age data table
                    for num, l in enumerate(lines):
                        if "Deaths and Death Rate by Age Group" in l.split(".")[0]:
                            begin_page = l.split()[-1]
                    # april-20-2020, on page 10 but in it was written as on page 11, need to check more days       
                    lines = doc.getPageText(int(begin_page) - 2).splitlines()
                    lines += doc.getPageText(int(begin_page) - 1).splitlines()
                    lines += doc.getPageText(int(begin_page)).splitlines()
                    ## find key word to point to the age data plot
                    for num, l in enumerate(lines):
                        if "Deaths by Age Group in Confirmed COVID-19" in l:
                            begin_num = num
                        #if "Rate (per 100,000) of Deaths in Confirmed" in l:
                        #    stop_num = num
                        #    break
                    for num, l in enumerate(lines[begin_num:]):
                        if "Count" in l:
                            line_num = num
                            break
                    lines = lines[begin_num:][line_num:]
                    age_data["0-19"] = [lines[1], lines[9]]
                    age_data["20-29"] = [lines[2], lines[10]]
                    age_data["30-39"] = [lines[3], lines[11]]
                    age_data["40-49"] = [lines[4], lines[12]]
                    age_data["50-59"] = [lines[5], lines[13]]
                    age_data["60-69"] = [lines[6], lines[14]]
                    age_data["70-79"] = [lines[7], lines[15]]
                    age_data["80+"] = [lines[8], lines[16]]
                    path = "data/{}".format(dayy.strftime("%Y-%m-%d"))
                    if not os.path.exists(path):
                        os.mkdir(path)
                    with open("data/{}/ma.json".format(dayy.strftime("%Y-%m-%d")), "w") as f:
                        json.dump(age_data, f)

                else:
                    warnings.warn(
                        "Warning: Report for Massachusetts {} is not available".format(
                            day
                        )
                    )

 
if __name__ == "__main__":
    ageExtractor = AgeExtractor()
    ageExtractor.get_massachusetts()


