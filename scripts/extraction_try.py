# pip install selenium
# pip install webdriver_manager
## updated:  for arizona
# pip install xlrd
import os
import re
import csv
import time
import json
import warnings
import requests
import subprocess

from os import system
from os.path import basename, join
from shutil import copyfile
from datetime import date, timedelta, datetime
from dateutil.parser import parse as parsedate
import xlrd
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.action_chains import ActionChains
from webdriver_manager.chrome import ChromeDriverManager, ChromeType
from PIL import Image

import fitz
import numpy as np
from glob import glob
from bs4 import BeautifulSoup, SoupStrainer

class AgeExtractor:
    """ Using the Chrome driver to render a web page with the help of Selenium.
        Need to install a Chromdirver.exe and copy its path into the code.
        The web can automatically click the button and switch the page,
        but it need time to load, otherwise, we would get the wrong or empty results.
    """

    def __init__(self):
        self.today = date.today().strftime("%Y-%m-%d")

    def get_louisiana(self):
        url = "https://www.arcgis.com/apps/opsdashboard/index.html#/69b726e2b82e408f89c3a54f96e8f776"
        #chromed = "D:\chromedriver.exe"
        #os.chdir("/mnt/d")
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)

        browser.get(url)
        browser.implicitly_wait(5) # Let the page load
        button1 = browser.find_elements_by_css_selector('div.flex-fluid.overflow-hidden')
        time.sleep(2)
        day = button1[0].text
        idx = re.search( r'updated:.*/2020', day).span()
        day = day[idx[0]: idx[1]].split(':')[1]
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/louisiana.json".format(day), os.F_OK):
            browser.implicitly_wait(2)
            button_name = button1[0].text.split('\n')[-1]
            button = [e for e in button1 if e.text == button_name][0]
            # button = [e for e in button1 if e.text == 'State Map of Cases by Parish'][0]
            time.sleep(2)
            button.click()
            browser.implicitly_wait(2)
            button = browser.find_elements_by_css_selector('div.flex-fluid')
            time.sleep(2)
            button = [e for e in button if e.text == button_name or e.text == 'Cases and Deaths by Age']
            time.sleep(2)
            button[1].click()
            browser.implicitly_wait(1)
            button[2].click()
            browser.implicitly_wait(1)
            board = browser.find_elements_by_css_selector('g.amcharts-graph-column')#.amcharts-graph-graphAuto1_1589372672251')
            data = [e.get_attribute('aria-label') for e in board if e.get_attribute('aria-label') and 'death' in e.get_attribute('aria-label')]
            browser.implicitly_wait(5)
            age_data ={}
            for a in data:
                age_data[" ".join(a.split()[1:-1])] = a.split()[-1]

            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/louisiana.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Louisiana {} ------\n'.format(day))
            browser.save_screenshot('pngs/louisiana/{}.png'.format(day))
        else:
            print('Report for Louisiana {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_oklahoma(self):
        ## just have the percentage
        url = "https://looker-dashboards.ok.gov/embed/dashboards/76"
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(5)
        data = browser.find_elements_by_css_selector('tspan.highcharts-data-label')
        data = [e.text for e in data if e.text and e.text[0] >= '0' and e.text[0] <= '9']

        pdf_url = 'https://storage.googleapis.com/ok-covid-gcs-public-download/covid19_cases_summary.pdf'

        r = requests.get(pdf_url).headers['Last-Modified']
        day = parsedate(r).strftime('%Y-%m-%d')
        if not os.access("data/{}/oklahoma.json".format(day), os.F_OK):
            path = "pdfs/oklahoma"
            if not os.path.exists(path):
                os.mkdir(path)
            with open("pdfs/oklahoma/" + day + ".pdf", "wb") as f:
                response = requests.get(pdf_url)
                f.write(response.content)
            ##
            doc = fitz.Document(
                "pdfs/oklahoma/{}.pdf".format(day)
            )
            # find the page
            lines = doc.getPageText(0).splitlines()
            total = int(lines[2])
            age_data = {}
            for i in data:
               age_data[i.split()[0]] = int(round(total * float(i.split()[1][0:-1])* 0.01, 0))
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/oklahoma.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Oklahoma {} ------\n'.format(day))
            browser.save_screenshot('pngs/oklahoma/{}.png'.format(day))
        else:
            print('Report for Oklahoma {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_oklahoma2(self):
        # check existing assets
        # os.getcwd() # check current path
        if not os.path.exists("pdfs/oklahoma"):
            os.mkdir("pdfs/oklahoma")
        existing_assets = list(map(basename, glob("pdfs/oklahoma/*.pdf")))
        date_diff = date.today() - date(2020, 6, 5)
        for i in range(date_diff.days + 1):
            dayy = date(2020,6,5) + timedelta(days=i)
            day = dayy.strftime("%-m-%-d-%y").lower()
            url = "https://coronavirus.health.ok.gov/sites/g/files/gmc786/f/eo_-_covid-19_report_-_{}.pdf".format(day)
            if url.split("/")[-1] not in existing_assets:
                if requests.get(url).status_code == 200:

                     #subprocess.run(
                     #   [
                     #       "wget --no-check-certificate",
                     #       "-O",
                     #       "pdfs/oklahoma/" + url.split("/")[-1],
                     #       url,
                     #   ]
                     #)
                     with open(
                             "pdfs/oklahoma/" + url.split("/")[-1], "wb"
                     ) as f:
                         response = requests.get(url)
                         f.write(response.content)
                     age_data = {}
                     doc = fitz.open(
                         "pdfs/oklahoma/eo_-_covid-19_report_-_{}.pdf".format(day)
                     )
                     lines = doc.getPageText(1).splitlines()
                     ## find key word to point to the age data table
                     for num, l in enumerate(lines):
                         if "Age Group" in l:
                             begin = num
                             break
                     lines = lines[begin:]
                     age_data[lines[4]] = lines[6]
                     age_data[lines[7]] = lines[9]
                     age_data[lines[10]] = lines[12]
                     age_data[lines[13]] = lines[15]
                     age_data[lines[16]] = lines[18]
                     age_data[lines[19]] = lines[21]
                     path = "data/{}".format(dayy.strftime("%Y-%m-%d"))
                     if not os.path.exists(path):
                         os.mkdir(path)
                     with open("data/{}/oklahoma2.json".format(dayy.strftime("%Y-%m-%d")), "w") as f:
                         json.dump(age_data, f)
                     print('\n------ Processed Oklahoma2 {} ------\n'.format(day))
                     doc.close()

                else:
                    print(
                        "Warning: Report for Oklahoma {} is not available".format(
                            day
                        )
                    )

    def get_nd(self):
        url = "https://www.health.nd.gov/diseases-conditions/coronavirus/north-dakota-coronavirus-cases"
        #chromed = "D:\chromedriver.exe"
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)

        browser.get(url)
        day = browser.find_element_by_xpath('/html/body/div[1]/div[5]/div/section/div[2]/article/div/div[1]/div/div[2]/div/div/div/div/p').text.split(':')[1].split()[0]
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/NorthDakota.json".format(day), os.F_OK):
            browser.implicitly_wait(5)
            #if browser.execute_script("return document.readyState") == "complete":
            data = browser.find_elements_by_css_selector('rect.highcharts-point')
            data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label')]
            # data from 24 to 33
            data = data[24:33]
            age_data = {}
            for i in data:
                age_data[i.split(',')[0].split('.')[1]] = i.split(',')[1].split('.')[0]
            if age_data:
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/NorthDakota.json".format(day), "w") as f:
                    json.dump(age_data, f)
                print('\n------ Processed North Dakota {} ------\n'.format(day))
            #else:
            #    print('error for extracting')
            # take the full screenshot
            # thanks https://zhuanlan.zhihu.com/p/73255362
            width = browser.execute_script("return document.documentElement.scrollWidth")
            height = browser.execute_script("return document.documentElement.scrollHeight")
            #print(width, height)
            browser.set_window_size(width, height)
            time.sleep(1)
            browser.save_screenshot('pngs/NorthDakota/{}.png'.format(day))

        else:
            print('Report for North Dakota{} is already exist'.format(day))


        browser.close()
        browser.quit()

    def get_az(self):
        ##
        # url = "https://www.azdhs.gov/preparedness/epidemiology-disease-control/infectious-disease-epidemiology/covid-19/dashboards/index.php"
        url = 'https://tableau.azdhs.gov/views/COVID-19Deaths/Deaths/sheet.pdf'
        ## updated daily
        try:
            r = requests.get(url)
            r.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print(err)
            print(
                "==> Report for Arizona {} is not available".date.today().strftime('%Y-%m-%d')
            )
        else:
            day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
            if not os.access("data/{}/arizona.json".format(day), os.F_OK):
                with open("pdfs/arizona/{}.pdf".format(day), "wb") as f:
                    f.write(r.content)
                doc = fitz.Document("pdfs/arizona/{}.pdf".format(day))
                # find the page
                lines = doc.getPageText(0).splitlines()
                day = parsedate(lines[1]).strftime('%Y-%m-%d')
                for num, l in enumerate(lines):
                    if 'COVID-19 Deaths by Gender' in l:
                        data_num = num
                        break
                lines = lines[data_num + 1 : ]
                age_data = {}
                 ## need to worry about the order
                #age_data[lines[4]] = lines[9]
                #age_data[lines[0]] = lines[6]
                #age_data[lines[1]] = lines[7]
                #age_data[lines[2]] = lines[8]
                #age_data[lines[3]] = lines[5]
                data = lines[5:10]
                data = sorted([int(''.join(e.split(','))) for e in data])
                age_data['<20y'] = data[0]
                age_data['20-44y'] = data[1]
                age_data['45-54y'] = data[2]
                age_data['55-64y'] = data[3]
                age_data['65+'] = data[4]
                doc.close()
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)

                with open("data/{}/arizona.json".format(day), "w") as f:
                    json.dump(age_data, f)
                print('\n------ Processed Arizona {} ------\n'.format(day))
            else:
                print('Data for Arizona {} is already exist'.format(day))

    def get_nc(self):
        ## do manually, download the pdf
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)

        # browser.get("https://covid19.ncdhhs.gov/dashboard#by-age")
        ###  from 2020-05-20 change the web....   can download
        url = 'https://covid19.ncdhhs.gov/dashboard/cases'
        url = 'https://public.tableau.com/views/NCDHHS_COVID-19_Dashboard_Cases/NCDHHS_Dashboard_Cases2?%3Aembed=y&%3Adisplay_count=y&publish=yes%3F%3Aembed&publish=yes&%3AshowVizHome=no&%3Ahost_url=https%3A%2F%2Fpublic.tableau.com%2F&%3Aembed_code_version=3&%3A%E2%80%98toolbar%E2%80%99=%E2%80%98no%E2%80%99&%3Aanimate_transition=yes&%3Adisplay_static_image=no&%3A%E2%80%98display_spinner%E2%80%99=%E2%80%98no%E2%80%99&%3Adisplay_overlay=yes&%3A%E2%80%98display_count%E2%80%99=%E2%80%98no%E2%80%99&%3Adisplay_spinner=no&%3AloadOrderID=0'
        browser.get(url)
        day = requests.get(url).headers['Date']
        day = "/".join(day.split(',')[1].split()[0:3])
        day = parsedate(day).strftime('%Y-%m-%d')

        ## download manually
        ##########

        #########################
        if not os.access("data/{}/NorthCarolina.json".format(day), os.F_OK):
            doc = fitz.Document("pdfs/nc/{}.pdf".format(day))
            lines = doc.getPageText(0).splitlines()
            for num, l in enumerate(lines):
                if "TOTAL" in l:
                    total_num = num
                    break

            for num, l in enumerate(lines):
                if "By\tAge" in l:
                    end_num = num
                    break
            age_data = {}
            total = int(lines[total_num + 2])
            age_data['0-17'] = round(0.01 * float(lines[end_num - 3][0:-1]) * total)
            age_data['18-24'] = round(0.01 * float(lines[end_num - 2][0:-1]) * total)
            age_data['25-49'] = round(0.01 * float(lines[end_num - 1][0:-1]) * total)
            age_data['50-64'] = round(0.01 * float(lines[end_num - 6][0:-1]) * total)
            age_data['65-74'] = round(0.01 * float(lines[end_num - 5][0:-1]) * total)
            age_data['75+'] = round(0.01 * float(lines[end_num - 4][0:-1]) * total)
            age_data['total'] = total
            doc.close()
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/NorthCarolina.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed North Carolina {} ------\n'.format(day))
        else:
            print('Report for NorthCarolina {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_nc2(self):
        path = "pdfs/nc2"
        if not os.path.exists(path):
            os.mkdir(path)
        url = 'https://covid19.ncdhhs.gov/dashboard/about-data'
        day = requests.get(url).headers['Last-Modified']
        day = parsedate(day).strftime('%Y-%m-%d')
        url = 'https://public.tableau.com/views/NCDHHS_COVID-19_DataDownload/Demographics.pdf?:showVizHome=no'
        try:
            r = requests.get(url)
            r.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print(err)
            print(
                "==> Report for North Carolina2 {} is not available".format(day)
            )
        else:
            if not os.access("data/{}/NorthCarolina2.json".format(day), os.F_OK):
                with open("pdfs/nc2/{}.pdf".format(day), "wb") as f:
                    f.write(r.content)
                doc = fitz.Document("pdfs/nc2/{}.pdf".format(day))
                # find the page
                lines = doc.getPageText(0).splitlines()
                for num, l in enumerate(lines):
                    if '0-17' in l:
                        data_num = num
                        break
                data = lines[data_num:]
                age_data = {}
                age_data[data[0]] = data[29]
                age_data[data[1]] = data[28]
                age_data[data[2]] = data[11]
                age_data[data[3]] = data[9]
                age_data[data[4]] = data[8]
                age_data[data[5]] = data[7]
                doc.close()
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)

                with open("data/{}/NorthCarolina2.json".format(day), "w") as f:
                    json.dump(age_data, f)
                print('\n------ Processed North Carolina2 {} ------\n'.format(day))
            else:
                print('Data for North Carolina2 {} is already exist'.format(day))

    def get_mississippi(self):
        existing_assets = list(map(basename, glob("pngs/mississippi/*.png")))
        date_diff = date.today() - date(2020, 4, 27)
        for i in range(date_diff.days + 1):
            dayy = date(2020, 4, 27) + timedelta(days=i)
            day = dayy.strftime('%Y-%m-%d')
            url = 'https://msdh.ms.gov/msdhsite/_static/images/graphics/covid19-chart-age-' + str(day[5:]) + '.png'
            if day + '.png' not in existing_assets:
                try:
                    r = requests.get(url)
                    r.raise_for_status()
                except requests.exceptions.HTTPError as err:
                    print(err)
                    print(
                        "==> Report for Mississippi {} is not available".format(day)
                    )
                else:
                    path = "pngs/Mississippi"
                    if not os.path.exists(path):
                        os.mkdir(path)
                    response = requests.get(url)
                    with open("pngs/Mississippi/{}.png".format(day), "wb") as f:
                        for data in response.iter_content(128):
                            f.write(data)
                    print('\n------ Processed Mississippi pngs {} ------\n'.format(day))



    def get_missouri(self):

        url = "https://health.mo.gov/living/healthcondiseases/communicable/novel-coronavirus/results.php"
        ## change web from 2020-05-21
        url = 'https://mophep.maps.arcgis.com/apps/opsdashboard/index.html#/0c6d8b9da4494eb1bcc0c7e2187e48aa'
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)

        browser.get(url)
        day = requests.get(url).headers['Date']
        day = "/".join(day.split(',')[1].split()[0:3])
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/missouri.json".format(day), os.F_OK):
            browser.implicitly_wait(5)
            data = browser.find_elements_by_css_selector('g.amcharts-graph-column')
            data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label')]
            time.sleep(2)
            age_data = {}
            for i in range(len(data)):
                age_data[' '.join(data[i].split()[0:-1])] = data[i].split()[-1]
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/missouri.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Missouri {} ------\n'.format(day))
            browser.save_screenshot('pngs/missouri/{}.png'.format(day))
        else:
            print('Report for Missouri {} is already exist'.format(day))

        browser.close()
        browser.quit()

    #from webdriver_manager.chrome import ChromeDriverManager


    def get_kentucky(self):
        url = "https://kygeonet.maps.arcgis.com/apps/opsdashboard/index.html#/543ac64bc40445918cf8bc34dc40e334"
        r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        #day = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        # 5 pm BST update
        day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        #chromed = "D:\chromedriver.exe"
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager().install(), options=options)
        browser.get(url)
        ## //*[@id="ember57"]/div/div/svg/g[7]/g/g/g[1]
        browser.implicitly_wait(40)
        time.sleep(20)
        data = browser.find_elements_by_css_selector('g.amcharts-graph-column')
        # data contain the cases and deaths
        data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label')]
        browser.implicitly_wait(5)
        if not os.access("data/{}/kentucky.json".format(day), os.F_OK):
            #if browser.execute_script("return document.readyState") == "complete":
                # begin at data[9]
            browser.implicitly_wait(5)
            age_data = {}
            # change the age band from 6.4
            # add group for cases from 6.6
            data = data[10:17]
            age_data['10-19'] = '0'
            age_data['20-29'] = '0'
            for i in data:
                age_data[i.split()[0]] = i.split()[1]
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/kentucky.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Kentucky {} ------\n'.format(day))
            browser.save_screenshot('pngs/kentucky/{}.png'.format(day))
            #else:
            #    print('error for extracting')
        else:
            print('Report for kentucky {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_delware(self):
        ## TODO: get the update day
        url = "https://myhealthycommunity.dhss.delaware.gov/about/acceptable-use"
        # changed from 6.30
        url = 'https://myhealthycommunity.dhss.delaware.gov/locations/state#outcomes'
        #chromed = "D:\chromedriver.exe"
        day = requests.get(url).headers['Last-Modified']
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/delaware.json".format(day), os.F_OK):
            options = Options()
            options.add_argument('headless')
            #browser = webdriver.Chrome(executable_path=chromed, options=options)
            browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
            browser.get(url)
            #browser.find_element_by_xpath('//*[@id="accept"]').click()
            #browser.find_element_by_xpath('/html/body/main/div/div/div[2]/section/form/button').click()
            ##  website change from 2020-05-20
            #day = browser.find_element_by_xpath('//*[@id="outcomes"]/div/article[1]/div/div/div[2]/div[1]/div[1]/div/div/span[2]').text
            #day = browser.find_element_by_xpath('//*[@id="outcomes"]/div/div[2]/div[1]/div/div[1]/div/span').text.split(':')[1]
            #day = parsedate(day).strftime("%Y-%m-%d")
            if browser.execute_script("return document.readyState") == "complete":
                age_data = {}
                for i in range(6):
                    path1 = browser.find_element_by_xpath('//*[@id="total-deaths-by-age"]/div[2]/div/table/tbody/tr[' + str(i + 1) + ']/td[1]/span/span')
                    path2 = browser.find_element_by_xpath('//*[@id="total-deaths-by-age"]/div[2]/div/table/tbody/tr['+ str(i + 1) + ']/td[2]')
                    age_data[path1.text] = path2.text.split()[0]
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/delaware.json".format(day), "w") as f:
                    json.dump(age_data, f)
                print('\n------ Processed Delaware {} ------\n'.format(day))

                #### get the full snapshot:
                # thanks #https://zhuanlan.zhihu.com/p/73255362
                width = browser.execute_script("return document.documentElement.scrollWidth")
                height = browser.execute_script("return document.documentElement.scrollHeight")

                browser.set_window_size(width, height)
                time.sleep(1)
                browser.save_screenshot('pngs/delaware/{}.png'.format(day))

            else:
                print('error for extracting')
        else:
            print('Report for Delaware {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_vermont(self):
        url = "https://vcgi.maps.arcgis.com/apps/opsdashboard/index.html#/6128a0bc9ae14e98a686b635001ef7a7"
        url = 'https://vcgi.maps.arcgis.com/apps/opsdashboard/index.html#/f2d395572efa401888eddceebddc318f'
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)

        browser.get(url)
        browser.implicitly_wait(5)
        time.sleep(2)
        #r = requests.get(url).headers['Last-Modified'] : 4.28
        # change day xpath:
        time.sleep(3)
        browser.implicitly_wait(1)

        date = browser.find_elements_by_css_selector('div.external-html')
        time.sleep(1)
        day = [e.text for e in date if e.text]
        time.sleep(2)
        browser.implicitly_wait(2)
        day = day[0].split()[2]
        #day = requests.get(url).headers['Date']
        day = parsedate(day).strftime("%Y-%m-%d")

        if not os.access("data/{}/vermont.json".format(day), os.F_OK):
            browser.implicitly_wait(2)
            browser.maximize_window()
            time.sleep(2)
            if browser.execute_script("return document.readyState") == "complete":
                time.sleep(2)
                data = browser.find_elements_by_css_selector('g.amcharts-graph-column')
                time.sleep(2)
                full_data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label') and e.get_attribute('aria-label').split()[1] == 'Without']
                time.sleep(2)
                death_data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label') and e.get_attribute('aria-label') .split()[1] == 'Resulting']
                time.sleep(2)
                age_death = {}
                for i in full_data:
                    age_death[i.split()[3]] = 0
                for i in death_data:
                    age_death[i.split()[4]] = i.split()[-1]
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/vermont.json".format(day), "w") as f:
                    json.dump(age_death, f)
                print('\n------ Processed Vermont {} ------\n'.format(day))
                browser.save_screenshot('pngs/vermont/{}.png'.format(day))
            else:
                print('error for extracting')
        else:
            print('Report for Vermont {} is already exist'.format(day))
        browser.close()
        browser.quit()

        #### manual
    def get_california(self):
        url = 'https://public.tableau.com/views/COVID-19PublicDashboard/Covid-19Public?%3Aembed=y&%3Adisplay_count=no&%3AshowVizHome=no'
        url = 'https://www.cdph.ca.gov/Programs/CID/DCDC/Pages/COVID-19/Race-Ethnicity.aspx'
        #soup = BeautifulSoup(url)
        chromed = "D:\chromedriver.exe"
        options = Options()
        options.add_argument('headless')
        browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser.get(url)
        browser.implicitly_wait(5)
        day = browser.find_element_by_xpath('//*[@id="WebPartWPQ4"]/div[1]/div[1]/h3[1]').text.split('\n')[1]
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/california.json".format(day), os.F_OK):
            age_data = {}
            for i in range(10):
                path1 = browser.find_element_by_xpath(
                    '//*[@id="WebPartWPQ4"]/div[1]/div[1]/table/tbody/tr[' + str(i + 2) + ']/td[1]')
                path2 = browser.find_element_by_xpath(
                    '//*[@id="WebPartWPQ4"]/div[1]/div[1]/table/tbody/tr[' + str(i + 2) + ']/td[4]')
                age_data[path1.text] = path2.text.split()[0]
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/california.json".format(day), "w") as f:
                json.dump(age_data, f)
        else:
                print('Report for California {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_indiana(self):
        url = 'https://hub.mph.in.gov/dataset/62ddcb15-bbe8-477b-bb2e-175ee5af8629/resource/2538d7f1-391b-4733-90b3-9e95cd5f3ea6/download/covid_report_demographics.xlsx'
        try:
            r = requests.get(url)
            r.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print(err, "\n ==> Report for  Indiana {} is not available".format(self.today.strftime('%Y-%m-%d')))
        else:
            day = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
            if not os.access("data/{}/indiana.xlsx".format(day), os.F_OK):
                req = requests.get(url)
                url_content = req.content
                file = open("data/{}/indiana.xlsx".format(day), 'wb')
                file.write(url_content)
                file.close()
                print('\n------ Processed Indiana file {} ------\n'.format(day))

                wb = xlrd.open_workbook("data/{}/indiana.xlsx".format(day))
                sh = wb.sheet_by_index(0)
                age_data = {}
                for rownum in range(1, sh.nrows):
                    row_values = sh.row_values(rownum)
                    age_data[row_values[0]] = int(row_values[2])
                # Write to file
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/indiana.json".format(day), "w") as f:
                    json.dump(age_data, f)
                print('\n------ Processed Indiana {} ------\n'.format(day))
            else:
                print('Report for Indiana {} is already exist'.format(day))

    def get_maryland(self):
        ## update
        url = 'https://coronavirus.maryland.gov/'
        #day = parsedate("/".join(requests.get(url).headers['Date'].split()[1:4])).strftime('%Y-%m-%d')
        day = parsedate(requests.get(url).headers['Date']).strftime('%Y-%m-%d')
        #chromed = "D:\chromedriver.exe"
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(5)
        if not os.access("data/{}/maryland.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                width = browser.execute_script("return document.documentElement.scrollWidth")
                height = browser.execute_script("return document.documentElement.scrollHeight")
                browser.set_window_size(width, height)
                time.sleep(1)
                browser.save_screenshot('pngs/maryland/{}.png'.format(day))
                age_data = {}
                for i in range(9):
                    group = browser.find_element_by_xpath('//*[@id="ember111"]/div/table[2]/tbody/tr[' + str(i + 2) + ']/td[1]').text
                    data = browser.find_element_by_xpath('//*[@id="ember111"]/div/table[2]/tbody/tr[' + str(i + 2) + ']/td[3]').text
                    if data == '':
                        data = '0'
                    else:
                        data = data[1:-1]
                    age_data[group] = data

                path = "data/{}".format(day)

                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/maryland.json".format(day), "w") as f:
                    json.dump(age_data, f)
                print('\n------ Processed Maryland {} ------\n'.format(day))
            else:
                 print('error for extracting')
        else:
            print('Report for Maryland {} is already exist'.format(day))

        browser.close()
        browser.quit()
    def get_alabama(self):
        ## TODO: extract from the pie chart, need to care about the order, and the organisation of the pdf
        if not os.path.exists("pdfs/alabama"):
            os.mkdir("pdfs/alabama")
        existing_assets = list(map(basename, glob("pdfs/alabama/*.pdf")))
        api_base_url = "https://www.alabamapublichealth.gov/covid19/assets/"
        date_diff = date.today() - date(2020, 4, 8)
        for i in range(date_diff.days + 1):
            day = date(2020, 4, 8) + timedelta(days=i)
            day = day.strftime("%m%d%Y")[0:-2]
            pdf_name = "cov-al-cases-{}.pdf".format(day)
            # covid_links.append(pdf_name)
            url = join(api_base_url, pdf_name)

            if pdf_name.split("-")[-1] not in existing_assets:
                if requests.get(url).status_code == 200:
                    url = join(api_base_url, pdf_name)
                    with open("pdfs/alabama/" + pdf_name, "wb") as f:
                        response = requests.get(url)
                        f.write(response.content)
                    # now scrape the PDFs
                    doc = fitz.Document("pdfs/alabama/cov-al-cases-{}.pdf".format(day))
                    # find the page
                    lines = doc.getPageText(0).splitlines()
                    lines += doc.getPageText(1).splitlines()
                    ## find key word to point to the age data table
                    for num, l in enumerate(lines):
                        if "REPORTED" in l:
                            line_num = num
                            break
                    total = lines[line_num - 2]
                    for num, l in enumerate(lines[line_num:]):
                        if "DEMOGRAPHIC CHARACTERISTICS OF" in l:
                            line_begin = num
                            a = lines[line_begin:]
                            for num2, l2 in enumerate(a):
                                if "DEATH HAS BEEN VERIFIED" in l2:
                                    line_begin = num2
                                    break
                    lines = lines[line_begin:]
                    for num, l in enumerate(lines):
                        if "SEX" in l:
                            line_end = num
                            break
                    age_data = {}
                else:
                    print(
                        "Warning: Report for Alabama {} is not available".format(
                            day
                        )
                    )

    def get_oregon(self):
        url = 'https://govstatus.egov.com/OR-OHA-COVID-19'
        try:
            r = requests.get(url)
            r.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print(err, "\n ==> Report for Oregon {} is not available".format(self.today.strftime('%Y-%m-%d')))
        else:

            day = r.headers['Last-Modified']
            day = parsedate(day).strftime('%Y-%m-%d')
            if not os.access("data/{}/oregon.json".format(day), os.F_OK):
                path = "html/oregon"
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("html/oregon/{}.html".format(day), "wb") as f:
                    f.write(r.content)
                html = r.text
                soup = BeautifulSoup(html, "html.parser")
                tables = soup.find_all("table")[2]
                rows = tables.find_all("td")
                data = [e.text for e in rows]
                age_data = {}
                for i in range(10):
                    age_data[data[i*5]] = data[i*5 + 4]
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/oregon.json".format(day), "w") as f:
                    json.dump(age_data, f)
                print('\n------ Processed Oregon {} ------\n'.format(day))
            else:
                print('Report for Oregon {} is already exist'.format(day))

    def get_pennsylvania(self):
        url= 'https://experience.arcgis.com/experience/cfb3803eb93d42f7ab1c2cfccca78bf7'
        url= 'https://pema.maps.arcgis.com/apps/opsdashboard/index.html#/034bec0bab3b450888a32012f81b8fe4'
        # the main page
        url = 'https://pema.maps.arcgis.com/apps/opsdashboard/index.html#/90e80f49696e43458fdf4d40e796dd0e'
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(5)
        day = browser.find_element_by_xpath('//*[@id="ember48"]/div/p/em').text
        day = day.split()[7]
        day = parsedate(day).strftime('%Y-%m-%d')
        browser.close()
        browser.quit()
        if not os.access("data/{}/pennsylvania.json".format(day), os.F_OK):
            # the age death page
            url = 'https://pema.maps.arcgis.com/apps/opsdashboard/index.html#/859002d9094b47c7a21092c7c0f25845'
            options = Options()
            options.add_argument('headless')
            # browser = webdriver.Chrome(executable_path=chromed, options=options)
            browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
            browser.get(url)
            browser.implicitly_wait(5)
            time.sleep(2)
            data = browser.find_elements_by_css_selector('g.amcharts-graph-column')
            data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label')][4:13]
            time.sleep(2)
            browser.implicitly_wait(2)
            age_data = {}
            for i in data:
                age_data[i.split()[1]] = i.split()[-1]
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/pennsylvania.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Pennsylvania {} ------\n'.format(day))
            browser.save_screenshot('pngs/pennsylvania/{}.png'.format(day))
            browser.close()
            browser.quit()
        else:
            print('Report for Pennsylvania {} is already exist'.format(day))

    def get_nevada(self):
        #url = 'https://nvhealthresponse.nv.gov/'
        #html = requests.get(url).text
        #soup = BeautifulSoup(html, "html.parser")
        #day = soup.find_all("p", {'class':'announcement__message'})[0].text
        #day = day.split()[0]
        #day = parsedate(day).strftime('%Y-%m-%d')
        url = 'https://app.powerbigov.us/view?r=eyJrIjoiMjA2ZThiOWUtM2FlNS00MGY5LWFmYjUtNmQwNTQ3Nzg5N2I2IiwidCI6ImU0YTM0MGU2LWI4OWUtNGU2OC04ZWFhLTE1NDRkMjcwMzk4MCJ9'
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(5)
        time.sleep(2)
        day = browser.find_element_by_xpath('//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[5]/transform/div/div[3]/div/visual-modern/div/div/div/p[3]/span[1]').text
        day = day.split()[3]
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/nevada.json".format(day), os.F_OK):
            time.sleep(1)
            total = browser.find_element_by_xpath('//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[13]/transform/div/div[3]/div/visual-modern/div/*[name()="svg"]/*[name()="g"][1]/*[name()="text"]/*[name()="tspan"]').text
            browser.find_element_by_xpath(
                '//*[@id="pbiAppPlaceHolder"]/ui-view/div/div[2]/logo-bar/div/div/div/logo-bar-navigation/span/a[3]/i').click()
            time.sleep(2)
            browser.find_element_by_xpath(
                '//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[5]/transform/div/div[3]/div/visual-modern/div/div/div[2]/div/div').click()
            time.sleep(2)
            browser.find_element_by_xpath(
                '/html/body/div[5]/div[1]/div/div[2]/div/div[1]/div/div/div[2]/div/div/span').click()
            browser.implicitly_wait(2)
            time.sleep(1)
            data = []
            for i in range(7):
                data.append(browser.find_element_by_xpath(
                    '//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[6]/transform/div/div[3]/div/visual-modern/div/*[name()="svg"]/*[name()="g"][1]/*[name()="g"]/*[name()="path"][' + str(i+1) + ']').get_attribute('aria-label')
                            )
            age_data = {}
            for i in data:
                age_data[i.split()[0]] = i.split()[1:]
            age_data['total'] = total
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/nevada.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Nevada {} ------\n'.format(day))
            browser.save_screenshot('pngs/nevada/{}.png'.format(day))
        else:
            print('Report for Nevada {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_michigan(self):
        url = 'https://www.michigan.gov/coronavirus/0,9753,7-406-98163_98173---,00.html'
        url = 'https://app.powerbigov.us/view?r=eyJrIjoiMWNjYjU1YWQtNzFlMC00N2ZlLTg3NjItYmQxMWI4OWIwMGY1IiwidCI6ImQ1ZmI3MDg3LTM3NzctNDJhZC05NjZhLTg5MmVmNDcyMjVkMSJ9'
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(5)
        time.sleep(10)
        day = browser.find_element_by_xpath('//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-group[2]/transform/div/div[2]/visual-container-modern[2]/transform/div/div[3]/div/visual-modern/div/*[name()="svg"]/*[name()="g"][1]/*[name()="text"]/*[name()="tspan"]').text
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/michigan.json".format(day), os.F_OK):
            browser.implicitly_wait(2)
            browser.find_element_by_xpath('//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-group[3]/transform/div/div[2]/visual-container-modern[4]/transform/div/div[3]/div/visual-modern/div/button').click()
            browser.implicitly_wait(5)
            browser.find_element_by_xpath('//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-group/transform/div/div[2]/visual-container-modern[2]/transform/div/div[3]/div/visual-modern/div/button').click()
            browser.implicitly_wait(5)
            age_data = {}
            for i in range(9):
                data = browser.find_element_by_xpath('//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[15]/transform/div/div[3]/div/visual-modern/div/*[name()="svg"]/*[name()="svg"]/*[name()="g"][1]/*[name()="g"][2]/*[name()="svg"]/*[name()="g"]/*[name()="rect"][' + str(i+1) + ']').get_attribute('aria-label')
                age_data[data.split()[2][0:-1]] = data.split()[-1][0:-1]
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/michigan.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Michigan {} ------\n'.format(day))
            browser.save_screenshot('pngs/michigan/{}.png'.format(day))
        else:
            print('Report for Michigan {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_washington(self):
        url = 'https://www.doh.wa.gov/Emergencies/Coronavirus#CovidDataTables'
        options = Options()
        options.add_argument('headless')
        # browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(5)
        time.sleep(3)
        day = browser.find_element_by_xpath('//*[@id="dnn_ctr33855_HtmlModule_lblContent"]/p[3]/strong').text
        day = day.split()[-1]
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/washington.json".format(day), os.F_OK):
            browser.implicitly_wait(2)
            browser.find_element_by_xpath('//*[@id="togConfirmedCasesDeathsTbl"]').click()
            browser.implicitly_wait(2)
            time.sleep(2)
            browser.find_element_by_xpath('//*[@id="togCasesDeathsByAgeTbl"]').click()
            browser.implicitly_wait(2)
            time.sleep(2)
            total = browser.find_element_by_xpath('//*[@id="pnlConfirmedCasesDeathsTbl"]/div/div/table/tbody/tr[41]/td[3]').text
            time.sleep(2)
            age_data = {}
            for i in range(6):
                group = browser.find_element_by_xpath('//*[@id="pnlCasesDeathsByAgeTbl"]/div/div/table/tbody/tr[' + str(i+1) + ']/td[1]').text
                data = browser.find_element_by_xpath('//*[@id="pnlCasesDeathsByAgeTbl"]/div/div/table/tbody/tr[' + str(i+1) + ']/td[4]').text
                age_data[group] = data
            age_data['total'] = total
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/washington.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Washington {} ------\n'.format(day))
            width = browser.execute_script("return document.documentElement.scrollWidth")
            height = browser.execute_script("return document.documentElement.scrollHeight")
            #print(width, height)
            browser.set_window_size(width, height)
            time.sleep(1)
            browser.save_screenshot('pngs/washington/{}.png'.format(day))
        else:
            print('Report for Washington {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_illinois(self):
        ## TODO: extract
        # try again
        url = 'https://www.dph.illinois.gov/covid19/covid19-statistics'
        options = Options()
        options.add_argument('headless')
        # browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(5)
        time.sleep(2)
        day = parsedate(browser.find_element_by_xpath('//*[@id="updatedDate"]').text).strftime('%Y-%m-%d')
        if not os.access("data/{}/illinois.json".format(day), os.F_OK):
            browser.implicitly_wait(2)
            time.sleep(2)
            browser.find_element_by_xpath('//*[@id="liAgeChartDeaths"]/a').click()
            browser.implicitly_wait(3)
            time.sleep(2)
            age_data = {}
            group = ['Unknown','<20','20-29', '30-39', '40-49', '50-59', '60-69', '70-79', '80+']
            # j the age_groups
            for j in range(9):
                # i the race
                data = []
                for i in range(8):
                    s = browser.find_elements_by_xpath('//*[@id="pieAge"]/div/div/*[name()="svg"][1]/*[name()="g"][4]/*[name()="g"]/*[name()="g"][8]/*[name()="g"][1]/*[name()="g"][' + str(i+1) + ']/*[name()="g"]/*[name()="g"][' + str(j+1) + ']/*[name()="text"]')
                    if len(s) != 0:
                        data.append(int(s[0].text))
                    else:
                        data.append(0)
                age_data[group[j]] = sum(data)
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/illinois.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Illinois {} ------\n'.format(day))
            width = browser.execute_script("return document.documentElement.scrollWidth")
            height = browser.execute_script("return document.documentElement.scrollHeight")
            #print(width, height)
            browser.set_window_size(width, height)
            time.sleep(1)
            browser.save_screenshot('pngs/Illinois/{}.png'.format(day))
        else:
            print('Report for Illinois {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_utah(self):
        url = 'https://coronavirus-dashboard.utah.gov/#hospitalizations-mortality'
        options = Options()
        options.add_argument('headless')
        # browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(10)
        time.sleep(10)
        day = requests.get(url).headers['Last-Modified']
        day = parsedate(day).strftime('%Y-%m-%d')
        browser.implicitly_wait(2)
        if not os.access("data/{}/utah.json".format(day), os.F_OK):
            width = browser.execute_script("return document.documentElement.scrollWidth")
            height = browser.execute_script("return document.documentElement.scrollHeight")
            # print(width, height)
            browser.set_window_size(width, height)
            time.sleep(1)
            browser.save_screenshot('pngs/Utah/{}.png'.format(day))
            browser.implicitly_wait(2)
            total = browser.find_element_by_xpath('//*[@id="DataTables_Table_2"]/tbody/tr/td[1]').text
            age_data = {}
            browser.implicitly_wait(1)
            for i in range(8):
                group = browser.find_element_by_xpath('//*[@id="DataTables_Table_3"]/tbody/tr[' + str(i+1) + ']/td[1]').text
                data = browser.find_element_by_xpath('//*[@id="DataTables_Table_3"]/tbody/tr[' + str(i+1) + ']/td[3]').text
                age_data[group] = data
            age_data['total'] = total
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/utah.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Utah {} ------\n'.format(day))
        else:
            print('Report for Utah {} is already exist'.format(day))

        browser.close()
        browser.quit()

if __name__ == "__main__":
    # with one # can run step by step
    ageExtractor = AgeExtractor()
    ageExtractor.get_oklahoma()
    ageExtractor.get_oklahoma2()
    ageExtractor.get_nd()
    ###ageExtractor.get_nc()
    ageExtractor.get_nc2()
    ageExtractor.get_missouri()
    # #:
    ageExtractor.get_kentucky()
    ###ageExtractor.get_california()
    ageExtractor.get_indiana()
    ageExtractor.get_oregon()
    ageExtractor.get_pennsylvania()
    ageExtractor.get_nevada()
    ageExtractor.get_michigan()
    ageExtractor.get_illinois()
    ageExtractor.get_utah()
    ###
    ageExtractor.get_louisiana()
    ageExtractor.get_az()
    ageExtractor.get_maryland()
    ageExtractor.get_vermont()
    ageExtractor.get_delware()
    ageExtractor.get_washington()
    # get the figure
    ageExtractor.get_mississippi()
