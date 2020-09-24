import os
import time
import json
import requests
from os.path import basename
from datetime import date, timedelta
from dateutil.parser import parse as parsedate
import xlrd
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager, ChromeType


import fitz
from glob import glob
from bs4 import BeautifulSoup

class AgeExtractor:
    """ Using the Chrome driver to render a web page with the help of Selenium.
        Need to install a Chromdirver.exe and copy its path into the code.
        The web can automatically click the button and switch the page,
        but it need time to load, otherwise, we would get the wrong or empty results.
    """

    def __init__(self):
        self.today = date.today().strftime("%Y-%m-%d")

    def get_louisiana(self):
        url = 'https://www.arcgis.com/apps/opsdashboard/index.html#/4a6de226701e45bdb542f09b73ee79e1'
        options = Options()
        options.add_argument('headless')
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(5) # Let the page load
        button1 = browser.find_elements_by_css_selector('div.flex-fluid.overflow-hidden')
        time.sleep(2)
        day = requests.get(url).headers['Date']
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/louisiana.json".format(day), os.F_OK):
            browser.implicitly_wait(2)
            button_name = button1[0].text.split('\n')[-1]
            button = [e for e in button1 if e.text == button_name][0]
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
            print(age_data)
        else:
            print('Report for Louisiana {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_oklahoma(self):
        ## just have the percentage
        url = "https://looker-dashboards.ok.gov/embed/dashboards/76"
        options = Options()
        options.add_argument('headless')
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
            print(age_data)
        else:
            print('Report for Oklahoma {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_oklahoma2(self):
        if not os.path.exists("pdfs/oklahoma"):
            os.mkdir("pdfs/oklahoma")
        existing_assets = list(map(basename, glob("pdfs/oklahoma/*.pdf")))
        date_diff = date.today() - date(2020, 8, 27)
        for i in range(date_diff.days + 1):
            dayy = date(2020,8,27) + timedelta(days=i)
            day = dayy.strftime("%-m-%-d-%y").lower()
            url = "https://coronavirus.health.ok.gov/sites/g/files/gmc786/f/eo_-_covid-19_report_-_{}.pdf".format(day)
            if url.split("/")[-1] not in existing_assets:
                if requests.get(url).status_code == 200:
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

    def get_nd_png(self):
        url = "https://www.health.nd.gov/diseases-conditions/coronavirus/north-dakota-coronavirus-cases"
        url = 'https://app.powerbigov.us/view?r=eyJrIjoiYjJhZjUwM2QtZDIwZi00MmU3LTljZjEtZjgyMzIzZDVmMmQxIiwidCI6IjJkZWEwNDY0LWRhNTEtNGE4OC1iYWUyLWIzZGI5NGJjMGM1NCJ9&pageName=ReportSectionf5bbf68127089e2bd8ea'

        day = requests.get(url).headers['Date']
        day = parsedate(day).strftime('%Y-%m-%d')
        options = Options()
        options.add_argument('headless')
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)

        browser.get(url)
        browser.implicitly_wait(30)
        time.sleep(50)
        browser.implicitly_wait(50)
        width = browser.execute_script("return document.documentElement.scrollWidth")
        height = browser.execute_script("return document.documentElement.scrollHeight")
        # print(width, height)
        browser.set_window_size(width, height)
        time.sleep(50)
        browser.implicitly_wait(50)
        time.sleep(10)
        browser.save_screenshot('pngs/NorthDakota/{}_2.png'.format(day))
        browser.close()
        browser.quit()



    def get_nd(self):
        url = "https://www.health.nd.gov/diseases-conditions/coronavirus/north-dakota-coronavirus-cases"
        url = 'https://app.powerbigov.us/view?r=eyJrIjoiYjJhZjUwM2QtZDIwZi00MmU3LTljZjEtZjgyMzIzZDVmMmQxIiwidCI6IjJkZWEwNDY0LWRhNTEtNGE4OC1iYWUyLWIzZGI5NGJjMGM1NCJ9&pageName=ReportSectionf5bbf68127089e2bd8ea'
        day = requests.get(url).headers['Date']
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/NorthDakota.json".format(day), os.F_OK):
            options = Options()
            options.add_argument('headless')
            browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
            browser.get(url)
            time.sleep(20)
            browser.implicitly_wait(60)
            age_data = {}
            for i in range(9):
                data = browser.find_element_by_xpath(
                    '//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[22]/transform/div/div[3]/div/visual-modern/div/*[name()="svg"]/*[name()="svg"]/*[name()="g"][1]/*[name()="g"][2]/*[name()="svg"]/*[name()="g"][2]/*[name()="rect"][' + str(
                        i + 1) + ']')
                data = data.get_attribute('aria-label')
                age_data[data.split('.')[0].split()[-1]] = data.split('.')[1].split()[-1]
            if age_data:
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/NorthDakota.json".format(day), "w") as f:
                    json.dump(age_data, f)
                print('\n------ Processed North Dakota {} ------\n'.format(day))
                print(age_data)
            width = browser.execute_script("return document.documentElement.scrollWidth")
            height = browser.execute_script("return document.documentElement.scrollHeight")
            # print(width, height)
            browser.set_window_size(width, height)
            time.sleep(1)
            browser.save_screenshot('pngs/NorthDakota/{}.png'.format(day))

        else:
            print('Report for North Dakota{} is already exist'.format(day))


        browser.close()
        browser.quit()

    def get_az(self):
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
                data = lines
                age_data = {}
                age_data['<20y'] = data[17]
                age_data['20-44y'] = data[14]
                age_data['45-54y'] = data[15]
                age_data['55-64y'] = data[16]
                age_data['65+'] = data[13]
                doc.close()
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)

                with open("data/{}/arizona.json".format(day), "w") as f:
                    json.dump(age_data, f)
                print('\n------ Processed Arizona {} ------\n'.format(day))
                print(age_data)
            else:
                print('Data for Arizona {} is already exist'.format(day))


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
                "==> Report for North Carolina {} is not available".format(day)
            )
        else:
            if not os.access("data/{}/NorthCarolina.json".format(day), os.F_OK):
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
                age_data[data[1]] = data[27]
                age_data[data[2]] = data[9]
                age_data[data[3]] = data[8]
                age_data[data[4]] = data[7]
                age_data[data[5]] = data[28]
                doc.close()
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)

                with open("data/{}/NorthCarolina.json".format(day), "w") as f:
                    json.dump(age_data, f)
                print('\n------ Processed North Carolina {} ------\n'.format(day))
                print(age_data)
            else:
                print('Data for North Carolina {} is already exist'.format(day))

    def get_mississippi(self):
        existing_assets = list(map(basename, glob("pngs/mississippi/*.png")))
        date_diff = date.today() - date(2020, 8, 27)
        for i in range(date_diff.days + 1):
            dayy = date(2020, 8, 27) + timedelta(days=i)
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

        url = 'https://mophep.maps.arcgis.com/apps/opsdashboard/index.html#/c1f2a0115b0b4e4e9cc9ded149d0ae09'
        url = 'https://mophep.maps.arcgis.com/apps/opsdashboard/index.html#/2ee3d6c43e49401fa22a9435dd7ba064'

        options = Options()
        options.add_argument('headless')
        day = requests.get(url).headers['Date']
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/missouri.json".format(day), os.F_OK):
            browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
            browser.get(url)
            browser.implicitly_wait(25)
            data = browser.find_elements_by_css_selector('g.amcharts-graph-column')
            time.sleep(2)
            data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label') and 'Count' in e.get_attribute('aria-label')]
            time.sleep(2)
            age_data = {}
            for i in range(len(data)):
                age_data[data[i].split()[1]] = data[i].split()[-1]
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            if age_data:
                with open("data/{}/missouri.json".format(day), "w") as f:
                    json.dump(age_data, f)
                print('\n------ Processed Missouri {} ------\n'.format(day))
                browser.save_screenshot('pngs/missouri/{}.png'.format(day))
                print(age_data)
            else:
                print('\n !!!----  Missouri error ----!!!\n')
        else:
            print('Report for Missouri {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_kentucky(self):
        url = "https://kygeonet.maps.arcgis.com/apps/opsdashboard/index.html#/543ac64bc40445918cf8bc34dc40e334"
        r = requests.get(url)
        day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        options = Options()
        options.add_argument('headless')
        browser = webdriver.Chrome(ChromeDriverManager().install(), options=options)
        browser.get(url)
        browser.implicitly_wait(40)
        time.sleep(20)
        data = browser.find_elements_by_css_selector('g.amcharts-graph-column')
        # data contain the cases and deaths
        data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label')]
        browser.implicitly_wait(5)
        if not os.access("data/{}/kentucky.json".format(day), os.F_OK):
            browser.implicitly_wait(5)
            age_data = {}
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
            print(age_data)
        else:
            print('Report for kentucky {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_delware(self):
        url = 'https://myhealthycommunity.dhss.delaware.gov/locations/state#outcomes'
        day = requests.get(url).headers['Last-Modified']
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/delaware.json".format(day), os.F_OK):
            options = Options()
            options.add_argument('headless')
            browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
            browser.get(url)
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
                width = browser.execute_script("return document.documentElement.scrollWidth")
                height = browser.execute_script("return document.documentElement.scrollHeight")

                browser.set_window_size(width, height)
                time.sleep(1)
                browser.save_screenshot('pngs/delaware/{}.png'.format(day))
                print(age_data)
            else:
                print('error for extracting')
        else:
            print('Report for Delaware {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_vermont(self):
        url = 'https://vcgi.maps.arcgis.com/apps/opsdashboard/index.html#/f2d395572efa401888eddceebddc318f'
        url = 'https://vcgi.maps.arcgis.com/apps/opsdashboard/index.html#/3779c97adb8a42159d2a67a7d663b45e'

        options = Options()
        options.add_argument('headless')
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)

        browser.get(url)
        browser.implicitly_wait(5)
        time.sleep(20)
        #day = browser.find_element_by_xpath('//*[@id="ember437"]/div/div').text
        #day = parsedate(day.split()[2]).strftime('%Y-%m-%d')
        day = requests.get(url).headers['Date']
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/vermont.json".format(day), os.F_OK):
            browser.implicitly_wait(3)
            browser.find_element_by_xpath('//*[@id="ember392"]').click()
            browser.implicitly_wait(3)
            browser.find_element_by_xpath('//*[@id="ember377"]').click()
            browser.implicitly_wait(3)
            browser.find_element_by_xpath('//*[@id="ember392"]').click()
            time.sleep(3)
            age_data = {}
            age_data['0-9'] = 0
            age_data['10-19'] = 0
            age_data['20-29'] = 0
            for i in range(6):
                data = browser.find_element_by_xpath(
                    '//*[@id="ember201"]/div/div/*[name()="svg"]/*[name()="g"][7]/*[name()="g"]/*[name()="g"]/*[name()="g"][' + str(
                        i + 1) + ']').get_attribute('aria-label')
                age_data[data.split()[0]] = data.split()[-1]
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/vermont.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Vermont {} ------\n'.format(day))
            browser.save_screenshot('pngs/vermont/{}.png'.format(day))
            print(age_data)
        else:
            print('Report for Vermont {} is already exist'.format(day))
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
                k = sh.row_values(0).index('COVID_DEATHS')
                for rownum in range(1, sh.nrows):
                    row_values = sh.row_values(rownum)
                    age_data[row_values[0]] = int(row_values[k])
                # Write to file
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/indiana.json".format(day), "w") as f:
                    json.dump(age_data, f)
                print('\n------ Processed Indiana {} ------\n'.format(day))
                print(age_data)
            else:
                print('Report for Indiana {} is already exist'.format(day))

    def get_maryland(self):
        url = 'https://coronavirus.maryland.gov/'
        day = parsedate(requests.get(url).headers['Date']).strftime('%Y-%m-%d')
        options = Options()
        options.add_argument('headless')
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(5)
        if not os.access("data/{}/maryland.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                time.sleep(4)
                browser.implicitly_wait(2)
                age_data = {}
                for i in range(9):
                    group = browser.find_element_by_xpath('//*[@id="ember113"]/div/table[2]/tbody/tr[' + str(i + 2) + ']/td[1]').text
                    data = browser.find_element_by_xpath('//*[@id="ember113"]/div/table[2]/tbody/tr[' + str(i + 2) + ']/td[3]').text
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
                width = browser.execute_script("return document.documentElement.scrollWidth")
                height = browser.execute_script("return document.documentElement.scrollHeight")
                browser.set_window_size(width, height)
                time.sleep(3)
                browser.save_screenshot('pngs/maryland/{}.png'.format(day))
                print(age_data)
            else:
                 print('error for extracting')
        else:
            print('Report for Maryland {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_maryland_pngs(self):
        url = 'https://coronavirus.maryland.gov/'
        day = parsedate(requests.get(url).headers['Date']).strftime('%Y-%m-%d')
        options = Options()
        options.add_argument('headless')
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(15)
        if not os.access("data/{}/maryland.json".format(day), os.F_OK):
            width = browser.execute_script("return document.documentElement.scrollWidth")
            height = browser.execute_script("return document.documentElement.scrollHeight")
            browser.set_window_size(width, height)
            time.sleep(1)
            browser.save_screenshot('pngs/maryland/{}_2.png'.format(day))

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
                print(age_data)
            else:
                print('Report for Oregon {} is already exist'.format(day))

    def get_pennsylvania(self):
        url = 'https://pema.maps.arcgis.com/apps/opsdashboard/index.html#/90e80f49696e43458fdf4d40e796dd0e'
        options = Options()
        options.add_argument('headless')
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
            print(age_data)
            browser.close()
            browser.quit()
        else:
            print('Report for Pennsylvania {} is already exist'.format(day))

    def get_nevada(self):
        url = 'https://app.powerbigov.us/view?r=eyJrIjoiMjA2ZThiOWUtM2FlNS00MGY5LWFmYjUtNmQwNTQ3Nzg5N2I2IiwidCI6ImU0YTM0MGU2LWI4OWUtNGU2OC04ZWFhLTE1NDRkMjcwMzk4MCJ9'
        options = Options()
        options.add_argument('headless')
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(5)
        time.sleep(2)
        # day = browser.find_element_by_xpath('//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[5]/transform/div/div[3]/div/visual-modern/div/div/div/p[3]/span[1]').text
        browser.find_element_by_xpath(
            '/html/body/div[1]/ui-view/div/div[2]/logo-bar/div/div/div/logo-bar-navigation/span/a[2]/span/span[2]').click()
        time.sleep(2)
        browser.find_element_by_xpath('//*[@id="flyoutElement"]/div[1]/div/div/ul/li[1]/a').click()
        day = browser.find_element_by_xpath(
            '//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[5]/transform/div/div[3]/div/visual-modern/div/div/div/p[2]/span[1]').text
        day = day.split()[3]
        day = parsedate(day).strftime('%Y-%m-%d')
        time.sleep(10)
        if not os.access("data/{}/nevada.json".format(day), os.F_OK):
            time.sleep(1)
            # total = browser.find_element_by_xpath('//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[13]/transform/div/div[3]/div/visual-modern/div/*[name()="svg"]/*[name()="g"][1]/*[name()="text"]/*[name()="tspan"]').text
            # total = browser.find_element_by_xpath('//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[12]/transform/div/div[3]/div/visual-modern/div/*[name()="svg"]/*[name()="g"][1]/*[name()="text"]/*[name()="tspan"]').text
            total = browser.find_element_by_xpath(
                '//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[9]/transform/div/div[3]/div/visual-modern/div/*[name()="svg"]/*[name()="g"][1]/*[name()="text"]/*[name()="tspan"]').text
            # browser.find_element_by_xpath(
            #    '//*[@id="pbiAppPlaceHolder"]/ui-view/div/div[2]/logo-bar/div/div/div/logo-bar-navigation/span/a[3]/i').click()
            time.sleep(2)
            browser.find_element_by_xpath(
                '/html/body/div[1]/ui-view/div/div[2]/logo-bar/div/div/div/logo-bar-navigation/span/a[2]/span/span[2]').click()
            time.sleep(2)
            browser.find_element_by_xpath('//*[@id="flyoutElement"]/div[1]/div/div/ul/li[3]/a').click()

            # browser.find_element_by_xpath(
            #   '//*[@id="pbiAppPlaceHolder"]/ui-view/div/div[2]/logo-bar/div/div/div/logo-bar-navigation/span/a[3]/i').click()

            browser.find_element_by_xpath(
                '//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[5]/transform/div/div[3]/div/visual-modern/div/div/div[2]/div/div').click()
            time.sleep(2)
            browser.find_element_by_xpath(
                '/html/body/div[5]/div[1]/div/div[2]/div/div[1]/div/div/div[2]/div/span').click()
            browser.implicitly_wait(2)
            time.sleep(1)
            data = []
            for i in range(8):
                data.append(browser.find_element_by_xpath(
                    '//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[6]/transform/div/div[3]/div/visual-modern/div/*[name()="svg"]/*[name()="g"][1]/*[name()="g"]/*[name()="path"][' + str(
                        i + 1) + ']').get_attribute('aria-label')
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
            print(age_data)
        else:
            print('Report for Nevada {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_michigan(self):
        url = 'https://app.powerbigov.us/view?r=eyJrIjoiMWNjYjU1YWQtNzFlMC00N2ZlLTg3NjItYmQxMWI4OWIwMGY1IiwidCI6ImQ1ZmI3MDg3LTM3NzctNDJhZC05NjZhLTg5MmVmNDcyMjVkMSJ9'
        options = Options()
        options.add_argument('headless')
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(5)
        time.sleep(200)
        day = browser.find_element_by_xpath(
            '//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-group[2]/transform/div/div[2]/visual-container-modern[2]/transform/div/div[3]/div/visual-modern/div/*[name()="svg"]/*[name()="g"][1]/*[name()="text"]/*[name()="tspan"]').text
        time.sleep(10)
        day = parsedate(day).strftime('%Y-%m-%d')

        if not os.access("data/{}/michigan.json".format(day), os.F_OK):
            browser.implicitly_wait(2)
            time.sleep(10)
            browser.save_screenshot('pngs/michigan/{}_total.png'.format(day))
            browser.implicitly_wait(2)
            total = browser.find_element_by_xpath(
                '//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-modern[2]/transform/div/div[3]/div/visual-modern/div/div/div[2]/div[1]/div[4]/div/div/div[3]/div[1]').text
            browser.implicitly_wait(5)
            browser.find_element_by_xpath(
                '//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-group[3]/transform/div/div[2]/visual-container-modern[4]/transform/div/div[3]/div/visual-modern/div/button').click()
            browser.implicitly_wait(25)
            time.sleep(30)
            browser.find_element_by_xpath(
                '//*[@id="pvExplorationHost"]/div/div/exploration/div/explore-canvas-modern/div/div[2]/div/div[2]/div[2]/visual-container-repeat/visual-container-group/transform/div/div[2]/visual-container-modern[2]/transform/div/div[3]/div/visual-modern/div/button').click()
            browser.implicitly_wait(25)
            time.sleep(20)
            browser.implicitly_wait(5)
            data = browser.find_elements_by_css_selector('rect.column.setFocusRing')
            time.sleep(3)
            age_data = [e.get_attribute('aria-label') for e in data if
                        e.get_attribute('aria-label') and 'Total Deaths' in e.get_attribute(
                            'aria-label') and 'Age Group' in e.get_attribute('aria-label')]
            data = age_data
            age_data = {}
            age_data["0-19"] = '0'
            for i in data:
                age_data[i.split()[2][0:-1]] = i.split()[-1][0:-1]
            age_data["total"] = total
            summ = 0
            for i in data:
                ss = i.split()[-1][0:-1]
                summ = summ + int(''.join(ss.split(',')))
            age_data["0-19"] = str(int(''.join(total.split(','))) - summ)

            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/michigan.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Michigan {} ------\n'.format(day))
            browser.save_screenshot('pngs/michigan/{}.png'.format(day))
            print(age_data)
        else:
            print('Report for Michigan {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_washington(self):
        url = 'https://www.doh.wa.gov/Emergencies/COVID19/DataDashboard'
        options = Options()
        options.add_argument('headless')
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(20)
        time.sleep(20)
        day = browser.find_element_by_xpath('//*[@id="dnn_ctr34535_HtmlModule_lblContent"]/p[3]/strong').text
        time.sleep(10)
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
            browser.set_window_size(width, height)
            time.sleep(1)
            browser.save_screenshot('pngs/washington/{}.png'.format(day))
            print(age_data)
        else:
            print('Report for Washington {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_WA_pngs(self):
        url = 'https://www.doh.wa.gov/Emergencies/COVID19/DataDashboard'
        options = Options()
        options.add_argument('headless')
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(5)
        time.sleep(3)
        browser.implicitly_wait(2)
        browser.find_element_by_xpath('//*[@id="togConfirmedCasesDeathsTbl"]').click()
        browser.implicitly_wait(2)
        time.sleep(2)
        browser.find_element_by_xpath('//*[@id="togCasesDeathsByAgeTbl"]').click()
        browser.implicitly_wait(2)
        time.sleep(2)
        width = browser.execute_script("return document.documentElement.scrollWidth")
        height = browser.execute_script("return document.documentElement.scrollHeight")
        browser.set_window_size(width, height)
        time.sleep(1)
        browser.save_screenshot('pngs/washington/{}-2.png'.format(self.today))


    def get_illinois(self):
        url = 'https://www.dph.illinois.gov/covid19/covid19-statistics'
        options = Options()
        options.add_argument('headless')
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
            browser.set_window_size(width, height)
            time.sleep(1)
            browser.save_screenshot('pngs/Illinois/{}.png'.format(day))
            print(age_data)
        else:
            print('Report for Illinois {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_utah(self):
        url = 'https://coronavirus-dashboard.utah.gov/#hospitalizations-mortality'
        options = Options()
        options.add_argument('headless')
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
            print(age_data)
        else:
            print('Report for Utah {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_alabama(self):
        url = 'https://alpublichealth.maps.arcgis.com/apps/opsdashboard/index.html#/6d2771faa9da4a2786a509d82c8cf0f7'
        options = Options()
        options.add_argument('headless')

        day = requests.get(url).headers['Date']
        day = parsedate(day).strftime('%Y-%m-%d')
        browser = webdriver.Chrome(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options)
        browser.get(url)
        browser.implicitly_wait(15)
        browser.implicitly_wait(2)
        if not os.access("data/{}/alabama.json".format(day), os.F_OK):
            browser.implicitly_wait(15)
            total = browser.find_element_by_xpath(
                '//*[@id="ember452"]/*[name()="svg"]/*[name()="g"][2]/*[name()="svg"]/*[name()="text"]').text
            browser.implicitly_wait(2)
            browser.find_element_by_xpath('//*[@id="ember381"]').click()
            time.sleep(3)
            age_data = {}
            age_data['5-17'] = '0%'
            for i in range(5):
                group = browser.find_element_by_xpath(
                    '//*[@id="ember185"]/div/div[2]/*[name()="svg"]/*[name()="g"]/*[name()="g"]/*[name()="g"][' + str(
                        i + 1) + ']/*[name()="text"][1]').text
                data = browser.find_element_by_xpath(
                    '//*[@id="ember185"]/div/div[2]/*[name()="svg"]/*[name()="g"]/*[name()="g"]/*[name()="g"][' + str(
                        i + 1) + ']/*[name()="text"][2]').text
                age_data[group] = data
            age_data['total'] = total

            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/alabama.json".format(day), "w") as f:
                json.dump(age_data, f)
            print('\n------ Processed Alabama {} ------\n'.format(day))
            path = "pngs/alabama"
            if not os.path.exists(path):
                os.mkdir(path)
            time.sleep(1)
            browser.save_screenshot('pngs/alabama/{}.png'.format(day))
            print(age_data)
        else:
            print('Report for Alabama {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_california(self):
        url = 'https://public.tableau.com/views/COVID-19CasesDashboard_15931020425010/Cases.pdf?:embed=y&:showVizHome=no'
        ## updated daily
        try:
            r = requests.get(url)
            r.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print(err)
            print(
                "==> Report for California {} is not available".date.today().strftime('%Y-%m-%d')
            )
        else:
            day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
            if not os.access("data/{}/california.json".format(day), os.F_OK):
                path = "pdfs/california"
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("pdfs/california/{}.pdf".format(day), "wb") as f:
                    f.write(r.content)

                    ####  TODO extract
            else:
                print('Data for California {} is already exist'.format(day))

    def get_sc(self):
        url = 'https://public.tableau.com/views/MainDashboard_15964746061440/DeathsDash.pdf?%3Aembed=y&%3AshowVizHome=no&%3Ahost_url=https%3A%2F%2Fpublic.tableau.com%2F&%3Aembed_code_version=3&%3Atabs=no&%3Atoolbar=yes&%3Aanimate_transition=yes&%3Adisplay_static_image=no&%3Adisplay_spinner=no&%3Adisplay_overlay=yes&%3Adisplay_count=yes&%3Alanguage=en&publish=yes&%3AloadOrderID=0'

        try:
            r = requests.get(url)
            r.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print(err)
            print(
                "==> Report for SouthCarolina {} is not available".date.today().strftime('%Y-%m-%d')
            )
        else:
            day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
            if not os.access("data/{}/SouthCarolina.json".format(day), os.F_OK):
                path = "pdfs/SouthCarolina"
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("pdfs/SouthCarolina/{}.pdf".format(day), "wb") as f:
                    f.write(r.content)

                    ####  TODO extract
            else:
                print('Data for South Carolina {} is already exist'.format(day))

    def get_nh(self):
        url = 'https://nh.gov/t/DHHS/views/COVID-19Dashboard/Summary.pdf?:embed=y&:isGuestRedirectFromVizportal=y&:display_count=n&:showVizHome=n&:origin=viz_share_link'

        try:
            r = requests.get(url)
            r.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print(err)
            print(
                "==> Report for NewHampshire {} is not available".date.today().strftime('%Y-%m-%d')
            )
        else:
            day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
            if not os.access("data/{}/new_hampshire.json".format(day), os.F_OK):
                path = "pdfs/NewHampshire"
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("pdfs/NewHampshire/{}.pdf".format(day), "wb") as f:
                    f.write(r.content)

                    ####  TODO extract
            else:
                print('Data for NewHampshirea {} is already exist'.format(day))


    def get_kansas(self):
        url = 'https://public.tableau.com/views/COVID-19TableauVersion2/DeathSummary.pdf?%3Aembed=y&%3AshowVizHome=no&%3Ahost_url=https%3A%2F%2Fpublic.tableau.com%2F&%3Aembed_code_version=3&%3Atabs=no&%3Atoolbar=yes&%3Aanimate_transition=yes&%3Adisplay_static_image=no&%3Adisplay_spinner=no&%3Adisplay_overlay=yes&%3Adisplay_count=yes&%3Alanguage=en&publish=yes&%3AloadOrderID=0'

        try:
            r = requests.get(url)
            r.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print(err)
            print(
                "==> Report for kansas {} is not available".date.today().strftime('%Y-%m-%d')
            )
        else:
            day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
            if not os.access("data/{}/kansas.json".format(day), os.F_OK):
                path = "pdfs/kansas"
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("pdfs/kansas/{}.pdf".format(day), "wb") as f:
                    f.write(r.content)

                    ####  TODO extract
            else:
                print('Data for kansas {} is already exist'.format(day))

    def get_hawaii(self):
        url = 'https://public.tableau.com/views/AgeGroupsApr4/TableDash.pdf?%3Aembed=y&%3AshowVizHome=no&%3Ahost_url=https%3A%2F%2Fpublic.tableau.com%2F&%3Aembed_code_version=3&%3Atabs=no&%3Atoolbar=no&%3Aanimate_transition=yes&%3Adisplay_static_image=no&%3Adisplay_spinner=no&%3Adisplay_overlay=yes&%3Adisplay_count=yes&null&%3AloadOrderID=3'
        try:
            r = requests.get(url)
            r.raise_for_status()
        except requests.exceptions.HTTPError as err:
            print(err)
            print(
                "==> Report for hawaii {} is not available".date.today().strftime('%Y-%m-%d')
            )
        else:
            day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
            if not os.access("data/{}/hawaii.json".format(day), os.F_OK):
                path = "pdfs/hawaii"
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("pdfs/hawaii/{}.pdf".format(day), "wb") as f:
                    f.write(r.content)

                    ####  TODO extract
            else:
                print('Data for hawaii {} is already exist'.format(day))

if __name__ == "__main__":
    ageExtractor = AgeExtractor()
    try:
        print("\n### Running Oklahoma ###\n")
        ageExtractor.get_oklahoma()
    except:
        print("\n!!! OKLAHOMA FAILED !!!\n")

    try:
        print("\n### Running Oklahoma2 ###\n")
        ageExtractor.get_oklahoma2()
    except:
        print("\n!!! OKLAHOMA 2 FAILED !!!\n")

    try:
        print("\n### Running North Dakota pngs ###\n")
        ageExtractor.get_nd_png()
    except:
        print("\n!!! NORTH DAKOTA png FAILED !!!\n")

    try:
        print("\n### Running North Dakota ###\n")
        ageExtractor.get_nd()
    except:
        print("\n!!! NORTH DAKOTA FAILED !!!\n")

    try:
        print("\n### Running North Carolina 2 ###\n")
        ageExtractor.get_nc2()
    except:
        print("\n!!! NORTH CAROLINA 2 FAILED !!!\n")

    try:
        print("\n### Running Missouri ###\n")
        ageExtractor.get_missouri()
    except:
        print("\n!!! MISSOURI FAILED !!!\n")

    try:
        print("\n### Running Kentucky ###\n")
        ageExtractor.get_kentucky()
    except:
        print("\n!!! KENTUCKY FAILED !!!\n")

    try:
        print("\n### Running Indiana ###\n")
        ageExtractor.get_indiana()
    except:
        print("\n!!! INDIANA FAILED !!!\n")

    try:
        print("\n### Running Oregon ###\n")
        ageExtractor.get_oregon()
    except:
        print("\n!!! OREGON FAILED !!!\n")

    try:
        print("\n### Running Pennsylvania ###\n")
        ageExtractor.get_pennsylvania()
    except:
        print("\n!!! PENNSYLVANIA FAILED !!!\n")

    try:
        print("\n### Running Nevade ###\n")
        ageExtractor.get_nevada()
    except:
        print("\n!!! NEVADA FAILED !!!\n")

    try:
        print("\n### Running Michigan ###\n")
        ageExtractor.get_michigan()
    except:
        print("\n!!! MICHIGAN FAILED !!!\n")

    try:
        print("\n### Running Illinois ###\n")
        ageExtractor.get_illinois()
    except:
        print("\n!!! ILLINOIS FAILED !!!\n")

    try:
        print("\n### Running Utah ###\n")
        ageExtractor.get_utah()
    except:
        print("\n!!! UTAH FAILED !!!\n")

    try:
        print("\n### Running Louisiana ###\n")
        ageExtractor.get_louisiana()
    except:
        print("\n!!! LOUISIANA FAILED !!!\n")

    try:
        print("\n### Running Arizona ###\n")
        ageExtractor.get_az()
    except:
        print("\n!!! ARIZONA FAILED !!!\n")

    try:
        print("\n### Running Maryland ###\n")
        ageExtractor.get_maryland()
    except:
        print("\n!!! MARYLAND FAILED !!!\n")

    try:
        print("\n### Running Maryland png ###\n")
        ageExtractor.get_maryland_pngs()
    except:
        print("\n!!! MARYLAND PNG FAILED !!!\n")

    try:
        print("\n### Running Vermont ###\n")
        ageExtractor.get_vermont()
    except:
        print("\n!!! VERMONT FAILED !!!\n")

    try:
        print("\n### Running Delaware ###\n")
        ageExtractor.get_delware()
    except:
        print("\n!!! DELAWARE FAILED !!!\n")

    try:
        print("\n### Running Washington ###\n")
        ageExtractor.get_washington()
    except:
        print("\n!!! WASHINGTON FAILED !!!\n")



    try:
        print("\n### Running Washington png ###\n")
        ageExtractor.get_WA_pngs()
    except:
        print("\n!!! WASHINGTON PNG FAILED !!!\n")

    try:
        print("\n### Running Mississippi ###\n")
        ageExtractor.get_mississippi()
    except:
        print("\n!!! MISSISSIPPI FAILED !!!\n")


    try:
        print("\n### Running Alabama ###\n")
        ageExtractor.get_alabama()
    except:
        print("\n!!! ALABAMA FAILED !!!\n")


    try:
        print("\n### Running california ###\n")
        ageExtractor.get_california()
    except:
        print("\n!!! california FAILED !!!\n")

    try:
        print("\n### Running South Carolina ###\n")
        ageExtractor.get_sc()
    except:
        print("\n!!! South Carolina FAILED !!!\n")

    try:
        print("\n### Running New Hampshire ###\n")
        ageExtractor.get_nh()
    except:
        print("\n!!! New Hampshire FAILED !!!\n")

    try:
        print("\n### Running Kansas ###\n")
        ageExtractor.get_kansas()
    except:
        print("\n!!! Kansas FAILED !!!\n")

    try:
        print("\n### Running Hawaii ###\n")
        ageExtractor.get_hawaii()
    except:
        print("\n!!! Hawaii FAILED !!!\n")