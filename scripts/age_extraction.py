import os
import re
import json

import fitz
import warnings
import requests
import subprocess

import pandas as pd

from glob import glob
from shutil import copyfile
from os import system, mkdir
from os.path import basename, join, exists
from datetime import date, timedelta, datetime
from dateutil.parser import parse as parsedate

from bs4 import BeautifulSoup, SoupStrainer


class AgeExtractor:
    def __init__(self):
        self.today = date.today()

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
            print("==> CDC data already up to date up to {}".format(data_date))
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
            print("==> Georgia data already up to date up to {}".format(data_date))
        else:
            system(
                "wget --no-check-certificate -O georgia.zip https://ga-covid19.ondemand.sas.com/docs/ga_covid_data.zip;unzip georgia.zip; rm countycases.csv demographics.csv georgia.zip; mv deaths.csv data/{}/georgia.csv".format(
                    data_date
                )
            )

    def get_washington(self):
        ## now obtain PDF update date
        # r = requests.head(
        #     "https://www.doh.wa.gov/Portals/1/Documents/1600/coronavirus/data-tables/PUBLIC-CDC-Event-Date-SARS.xlsx"
        # )
        r = requests.head(
            "https://www.doh.wa.gov/Portals/1/Documents/1600/coronavirus/data-tables/PUBLIC_CDC_Event_Date_SARS.xlsx"
        )

        # use https://www.doh.wa.gov/Portals/1/Documents/1600/coronavirus/data-tables/PUBLIC_CDC_Event_Date_SARS.xlsx if not working
        ## the reports are always published 1 day later (possibly!)
        data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        # check if this data is in the data folder already
        existing_assets = list(
            map(basename, glob("data/{}/washington.xlsx".format(data_date)))
        )
        if existing_assets:
            print("==> Washingston data already up to date up to {}".format(data_date))
        else:
            os.makedirs(f"data/{data_date}", exist_ok=True)
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
            print("==> Texas data already up to date up to {}".format(data_date))
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
            print(
                "==> PDF last updated on {}. Please wait for the latest published report".format(
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


    def get_connecticut(self):
        ## now obtain PDF update date
        r = requests.get(
            "https://data.ct.gov/api/views/ypz6-8qyf/rows.csv", verify=False,
        )
        ## the reports are always published 1 day later (possibly!)
        data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        # check if this data is in the data folder already
        existing_assets = list(
            map(basename, glob("data/{}/connecticut.csv".format(data_date)))
        )
        if existing_assets:
            print("==> Connecticut data already up to date up to {}".format(data_date))
        else:
            system(
                "wget --no-check-certificate -O data/{}/connecticut.csv https://data.ct.gov/api/views/ypz6-8qyf/rows.csv".format(
                    data_date
                )
            )

    def get_massachusetts(self):
        # check existing assets
        # os.getcwd() # check current path
        if not exists("pdfs/massachusetts"):
            mkdir("pdfs/massachusetts")
        existing_assets = list(map(basename, glob("pdfs/massachusetts/*.pdf")))
        api_base_url = "https://www.mass.gov/doc/"
        date_diff = self.today - date(2020, 7, 1) 

        for i in range(date_diff.days + 1):
            day = date(2020, 7, 1) + timedelta(days=i)
            day_string = day.strftime("%Y-%m-%d")
            day = day.strftime("%B-%-d-%Y").lower()
            pdf_name = "covid-19-dashboard-{}/download".format(day)

            if pdf_name.split("/")[0] + ".pdf" not in existing_assets:
                try:
                    r = requests.get(join(api_base_url, pdf_name))
                    r.raise_for_status()
                except requests.exceptions.HTTPError as err:
                    print(err)
                    print(
                        "==> Report for Massachusetts {} is not available".format(day)
                    )
                else:

                    url = join(api_base_url, pdf_name)
                    with open(
                        "pdfs/massachusetts/" + pdf_name.split("/")[0] + ".pdf", "wb"
                    ) as f:
                        response = requests.get(url)
                        f.write(response.content)

                    # now scrape the PDFs
                    # day = 'may-19-2020'
                    # dayy = date(2020,5,19)
                    age_data = {}
                    doc = fitz.open(
                        "pdfs/massachusetts/covid-19-dashboard-{}.pdf".format(day)
                    )
                    # find the page
                    lines = doc.getPageText(0).splitlines()
                    lines += doc.getPageText(1).splitlines()
                    lines += doc.getPageText(2).splitlines()
                    lines += doc.getPageText(3).splitlines()
                    ## find key word to point to the age data table
                    for num, l in enumerate(lines):
                        if "Deaths and Death Rate by Age Group" in l:
                            begin_page = l.split()[-1]
                            break
                    # april-20-2020, on page 10 but in it was written as on page 11, need to check more days
                    lines = doc.getPageText(int(begin_page) - 2).splitlines()
                    lines += doc.getPageText(int(begin_page) - 1).splitlines()
                    lines += doc.getPageText(int(begin_page)).splitlines()
                    ## find key word to point to the age data plot
                    for num, l in enumerate(lines):
                        if "Deaths by Age Group" in l:
                            begin_num = num

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

                    os.makedirs("data/{}".format(day_string), exist_ok=True)

                    with open("data/{}/ma_daily.json".format(day_string), "w") as f:
                        json.dump(age_data, f)
                    doc.close()

    def get_nyc(self):
        # check existing assets
        existing_assets = list(map(basename, glob("pdfs/nyc/*.pdf")))
        api_base_url = "https://www1.nyc.gov/assets/doh/downloads/pdf/imm/"
        date_diff = self.today - date(2020, 4, 20)
        covid_links = []

        for i in range(date_diff.days + 1):
            day = date(2020, 4, 20) + timedelta(days=i)
            day_old_format = day.strftime("%Y-%m-%d")
            day = day.strftime("%m%d%Y").lower()
            pdf_name = "covid-19-deaths-confirmed-probable-daily-{}.pdf".format(day)
            covid_links.append(pdf_name)

            if pdf_name not in existing_assets:
                try:
                    r = requests.get(join(api_base_url, pdf_name))
                    r.raise_for_status()
                except requests.exceptions.HTTPError as err:
                    print(err, "\n ==> Report for  NYC {} is not available")
                else:
                    subprocess.run(
                        [
                            "wget",
                            "--no-check-certificate",
                            "-O",
                            "pdfs/nyc/{}".format(pdf_name),
                            join(api_base_url, pdf_name),
                        ]
                    )
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

    def get_michigan(self):
        subprocess.run(
            [
                "wget",
                "--no-check-certificate",
                "-O",
                "html/michigan/temp.html",
                "https://www.michigan.gov/coronavirus/0,9753,7-406-98163_98173---,00.html",
            ]
        )
        with open("html/michigan/temp.html") as f:
            soup = BeautifulSoup(f, "html.parser")

        tables = soup.find_all("table")

        html_date = tables[0].caption.text.split(" ")[-1]
        html_date = datetime.strptime(html_date, "%m/%d/%Y").strftime("%d/%m/%Y")
        html_date = html_date.replace("/", "-")

        copyfile("html/michigan/temp.html", f"html/michigan/{html_date}.html")

        os.remove("html/michigan/temp.html")

        def process_michigan_day(file_date):
            file_date = datetime.strptime(file_date, "%d-%m-%Y")

            with open(f"html/michigan/{file_date.strftime('%d-%m-%Y')}.html") as f:
                soup = BeautifulSoup(f, "html.parser")

            tables = soup.find_all("table")

            county_table = tables[0]
            age_table = tables[4]

            total_deaths = int(county_table.find_all("tr")[-1].find_all("td")[-1].text)

            age_rows = age_table.find_all("tr")[1:]
            data = dict()
            for row in age_rows:
                row = row.find_all("td")
                data[row[0].text] = row[2].text

            data["N"] = total_deaths

            with open(f"data/{file_date.strftime('%Y-%m-%d')}/michigan.json", "w") as f:
                json.dump(data, f)

            print(f'Processed {file_date} for Michigan')

        files = os.listdir("html/michigan")
        for f in files:
            process_michigan_day(f.split(".")[0])

    def get_minnesota(self):
        subprocess.run(
            [
                "wget",
                "--no-check-certificate",
                "-O",
                "html/minnesota/temp.html",
                "https://www.health.state.mn.us/diseases/coronavirus/situation.html",
            ]
        )   

        with open("html/minnesota/temp.html") as f:
            soup = BeautifulSoup(f, "html.parser")

        html_date = soup.find('p', class_='small').find('strong').text[9:]
        html_date = datetime.strptime(html_date, '%B %d, %Y').strftime("%d/%m/%Y")
        html_date = html_date.replace("/", "-")

        copyfile("html/minnesota/temp.html", f"html/minnesota/{html_date}.html")

        os.remove("html/minnesota/temp.html")

        def process_minnesota_day(file_date):
            file_date = datetime.strptime(html_date, "%d-%m-%Y")

            with open(f"html/minnesota/{file_date.strftime('%d-%m-%Y')}.html") as f:
                soup = BeautifulSoup(f, "html.parser")

            table = soup.find("table", id='agetable')
            table_rows = table.find_all('tr')

            data = dict()

            for row in table_rows[1:]:
                age_band = row.find('th').text
                deaths = row.find_all('td')[1].text.strip(' ')
                data[age_band] = deaths

            os.makedirs(f"data/{file_date.strftime('%Y-%m-%d')}", exist_ok=True)
            with open(f"data/{file_date.strftime('%Y-%m-%d')}/minnesota.json", "w") as f:
                json.dump(data, f)

            print(f'Processed {file_date} for Minnesota')

        files = os.listdir("html/minnesota")
        for f in files:
            process_minnesota_day(f.split(".")[0])

    def get_virginia(self):
        subprocess.run(
            [
                "wget",
                "--no-check-certificate",
                "-O",
                "csvs/virginia/temp.csv",
                "https://www.vdh.virginia.gov/content/uploads/sites/182/2020/03/VDH-COVID-19-PublicUseDataset-Cases_By-Age-Group.csv",
            ]
        )   

        data = pd.read_csv("csvs/virginia/temp.csv")
        csv_date = datetime.strptime(data['Report Date'][0], '%m/%d/%Y').strftime("%d-%m-%Y")

        copyfile("csvs/virginia/temp.csv", f"csvs/virginia/{csv_date}.csv")

        os.remove("csvs/virginia/temp.csv")

        def process_virginia_day(file_date):
            print(file_date)
            file_date = datetime.strptime(file_date, "%d-%m-%Y")

            data = pd.read_csv(f"csvs/virginia/{file_date.strftime('%d-%m-%Y')}.csv")
            data = data.groupby(by='Age Group').sum()['Number of Deaths'].reset_index()

            ret = dict()
            for i in range(len(data)):
                ret[data.loc[i]['Age Group']] = int(data.loc[i]['Number of Deaths'])

            print(ret)

            os.makedirs(f"data/{file_date.strftime('%Y-%m-%d')}", exist_ok=True)
            with open(f"data/{file_date.strftime('%Y-%m-%d')}/virginia.json", "w") as f:
                json.dump(ret, f)

            print(f'Processed {file_date} for Virginia')

        files = os.listdir("csvs/virginia")
        for f in files:
            process_virginia_day(f.split(".")[0])

    def get_district_of_columbia(self):
        os.makedirs('csvs/district_of_columbia/', exist_ok=True)
        i = 0
        while True:
            url = f"https://coronavirus.dc.gov/sites/default/files/dc/sites/coronavirus/page_content/attachments/DC-COVID-19-Data-for-{(self.today-timedelta(days=i)).strftime('%B-%-d-%Y')}.xlsx"
            ret = subprocess.run(
                [
                    "wget",
                    "--no-check-certificate",
                    "-O",
                    f"csvs/district_of_columbia/{(self.today-timedelta(days=i)).strftime('%d-%m-%Y')}.xlsx",
                    url,
                ]
            )
            print(ret)
            if ret.returncode==0:
                break
            else:
                os.remove(f"csvs/district_of_columbia/{(self.today-timedelta(days=i)).strftime('%d-%m-%Y')}.xlsx")
                i += 1

        data = pd.read_excel(f"csvs/district_of_columbia/{(self.today-timedelta(days=i)).strftime('%d-%m-%Y')}.xlsx", sheet_name="Lives Lost by Age", index_col=0)
        data = data.drop(labels=['Age', 'All'], axis=0)

        for date in data.columns:
            os.makedirs(f'data/{date.strftime("%Y-%m-%d")}', exist_ok=True)
            data[date].to_json(f'data/{date.strftime("%Y-%m-%d")}/doc.json')
        

    def get_all(self):
        """TODO: running get_*() for every state
        """
        return NotImplementedError()


if __name__ == "__main__":
    ageExtractor = AgeExtractor()

    try:
        print("\n### Running Georgia ###\n")
        ageExtractor.get_georgia()
    except:
        print("\n!!! GEORGIA FAILED !!!\n")

    try:
        print("\n### Running CDC ###\n")
        ageExtractor.get_cdc()
    except:
        print("\n!!! CDC FAILED !!!\n")

    try:
        print("\n### Running Washington###\n")
        ageExtractor.get_washington()
    except:
        print("\n!!! WASHINGTON FAILED !!!\n")

    try:
        print("\n### Running Texas ###\n")
        ageExtractor.get_texas()
    except:
        print("\n!!! TEXAS FAILED !!!\n")

    try:
        print("\n### Running Connecticut ###\n")
        ageExtractor.get_connecticut()
    except:
        print("\n!!! CONNECTICUT FAILED !!!\n")

    try:
        print("\n### Running Minnesota ###\n")
        ageExtractor.get_minnesota()
    except:
        print("\n!!! MINNESOTA FAILED !!!\n")

    try:
        print("\n### Running Virginia ###\n")
        ageExtractor.get_virginia()
    except:
        print("\n!!! VIRGINIA FAILED !!!\n")

    try:
        print("\n### Running DOC ###\n")
        ageExtractor.get_district_of_columbia()
    except:
        print("\n!!! DOC FAILED !!!\n")

    try:
        print("\n### Running NYC ###\n")
        ageExtractor.get_nyc()
    except:
        print("\n!!! NYC FAILED !!!\n")
                               
    #try:
    #    print("\n### Running MA ###\n")
    #    ageExtractor.get_massachusetts()
    #except:
    #    print("\n!!! MA FAILED !!!\n")                             
    
    #ageExtractor.get_new_jersey()
    #ageExtractor.get_florida()
    # ageExtractor.get_michigan()
    
