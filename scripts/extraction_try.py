# pip install selenium
# pip install webdriver_manager
## updated:  for arizona
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
            button = [e for e in button1 if e.text == 'State Map of Cases by Parish'][0]
            time.sleep(2)
            button.click()
            browser.implicitly_wait(2)
            button = browser.find_elements_by_css_selector('div.flex-fluid')
            time.sleep(2)
            button = [e for e in button if e.text == 'State Map of Cases by Parish'or e.text == 'Cases and Deaths by Age']
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
            browser.save_screenshot('pngs/louisiana/{}.png'.format(day))
        else:
            print('Report for Louisiana {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_oklahoma(self):
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
                     with open("data/{}/oklahoma.json".format(dayy.strftime("%Y-%m-%d")), "w") as f:
                         json.dump(age_data, f)
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
        r = requests.get(url)
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
            data = sorted([int(e) for e in data])
            age_data[lines[4]] = data[0]
            age_data[lines[0]] = data[1]
            age_data[lines[1]] = data[2]
            age_data[lines[2]] = data[3]
            age_data[lines[3]] = data[4]

            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)

            with open("data/{}/arizona.json".format(day), "w") as f:
                json.dump(age_data, f)
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
        else:
            print('Report for NorthCarolina {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_mississippi(self):
        ## the reports are always published 1 day later (possibly!)
        #data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)

        browser.get("https://msdh.ms.gov/msdhsite/_static/14,0,420.html#Mississippi")

        day = " ".join(['2020', " ".join(browser.find_element_by_xpath('//*[@id="article"]/div/h3[1]').text.split()[-2:])])
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("pngs/Mississippi/{}.png".format(day), os.F_OK):
            data_web = 'https://msdh.ms.gov/msdhsite/_static/images/graphics/covid19-chart-age-' + str(day[5:]) + '.png'
            path = "pngs/Mississippi"
            if not os.path.exists(path):
                os.mkdir(path)
            response = requests.get(data_web)
            with open("pngs/Mississippi/{}.png".format(day), "wb") as f:
                for data in response.iter_content(128):
                    f.write(data)
        else:
            print('Report for Mississippi {} is already exist'.format(day))
        browser.close()
        browser.quit()


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
            for i in data:
                age_data[i.split()[0]] = i.split()[1]
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/kentucky.json".format(day), "w") as f:
                json.dump(age_data, f)
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
        #chromed = "D:\chromedriver.exe"
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.find_element_by_xpath('//*[@id="accept"]').click()
        browser.find_element_by_xpath('/html/body/main/div/div/div[2]/section/form/button').click()
        ##  website change from 2020-05-20
        day = browser.find_element_by_xpath('//*[@id="total-deaths-by-age"]/div[2]/div/div[1]/div/div').text
        day = day.split()[1]
        #day = browser.find_element_by_xpath('//*[@id="outcomes"]/div/div[2]/div[1]/div/div[1]/div/span').text.split(':')[1]
        day = parsedate(day).strftime("%Y-%m-%d")
        if not os.access("data/{}/delaware.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                age_data = {}
                for i in range(6):
                    path1 = browser.find_element_by_xpath('//*[@id="total-deaths-by-age"]/div[2]/div/div[2]/div/div/table/tbody/tr[' + str(i + 1) + ']/td[1]')
                    path2 = browser.find_element_by_xpath('//*[@id="total-deaths-by-age"]/div[2]/div/div[2]/div/div/table/tbody/tr['+ str(i + 1) + ']/td[2]')
                    age_data[path1.text] = path2.text.split()[0]
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/delaware.json".format(day), "w") as f:
                    json.dump(age_data, f)

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
        options = Options()
        options.add_argument('headless')
        #browser = webdriver.Chrome(executable_path=chromed, options=options)
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)

        browser.get(url)
        browser.implicitly_wait(5)
        #r = requests.get(url).headers['Last-Modified'] : 4.28
        day = browser.find_element_by_xpath('//*[@id="ember78"]/div/p/strong').text.split(',')[0]
        day = parsedate(day).strftime("%Y-%m-%d")
        if not os.access("data/{}/vermont.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                data = browser.find_elements_by_css_selector('g.amcharts-graph-column')
                full_data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label') and e.get_attribute('aria-label').split()[1] == 'Without']
                death_data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label') and e.get_attribute('aria-label') .split()[1] == 'Resulting']
                age_death = {}
                for i in full_data:
                    #if i.split()[3] not in death_data:
                    if i != full_data[-1]:
                        age_death[i.split()[3]] = 0
                    else:
                        age_death[" ".join([i.split()[3], i.split()[4]])] = 0
                for i in death_data:
                    if i != death_data[-1]:
                        age_death[i.split()[4]] = i.split()[-1]
                    else:
                        age_death[" ".join([i.split()[4], i.split()[5]])] = i.split()[-1]
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/vermont.json".format(day), "w") as f:
                    json.dump(age_death, f)
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
        r = requests.get(url)
        day = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        if not os.access("data/{}/indiana.xlsx".format(day), os.F_OK):
            req = requests.get(url)
            url_content = req.content
            file = open("data/{}/indiana.xlsx".format(day), 'wb')
            file.write(url_content)
            file.close()
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
                age_data = {}
                for i in range(9):
                    group = browser.find_element_by_xpath('//*[@id="ember112"]/div/table[2]/tbody/tr[' + str(i + 2) + ']/td[1]').text
                    data = browser.find_element_by_xpath('//*[@id="ember112"]/div/table[2]/tbody/tr[' + str(i + 2) + ']/td[3]').text
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
                width = browser.execute_script("return document.documentElement.scrollWidth")
                height = browser.execute_script("return document.documentElement.scrollHeight")
                browser.set_window_size(width, height)
                time.sleep(1)
                browser.save_screenshot('pngs/maryland/{}.png'.format(day))
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


if __name__ == "__main__":
    # with one # can run step by step
    ageExtractor = AgeExtractor()
    ageExtractor.get_louisiana()
    ageExtractor.get_oklahoma()
    ageExtractor.get_nd()
    ageExtractor.get_az()
    ###ageExtractor.get_nc()
    # get the figure
    ageExtractor.get_mississippi()
    ageExtractor.get_missouri()
    # #:
    ageExtractor.get_kentucky()
    ageExtractor.get_delware()
    ageExtractor.get_vermont()
    ###ageExtractor.get_california()
    ageExtractor.get_indiana()
    ageExtractor.get_maryland()
