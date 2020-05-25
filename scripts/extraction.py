# need install selenium
from selenium import webdriver
from selenium.webdriver.common.action_chains import ActionChains
import re
from PIL import Image
import fitz
from datetime import date, timedelta, datetime
import time
from dateutil.parser import parse as parsedate
import json
from os.path import basename, join
from os import system
from glob import glob
from bs4 import BeautifulSoup, SoupStrainer
import requests
import subprocess
import warnings
import os
from shutil import copyfile
import csv

class AgeExtractor:
    """ Using the Chrome driver to render a web page with the help of Selenium.
        Need to install a Chromdirver.exe and copy its path into the code.
        The web can automatically click the button and switch the page,
        but it need time to load, otherwise, we would get the wrong or empty results.
    """

    def __init__(self):
        self.today = date.today().strftime("%Y-%m-%d")

    def get_massachusetts(self):
        # check existing assets
        # os.getcwd() # check current path
        if not os.path.exists("pdfs/massachusetts"):
            os.mkdir("pdfs/massachusetts")
        existing_assets = list(map(basename, glob("pdfs/massachusetts/*.pdf")))
        api_base_url = "https://www.mass.gov/doc/"
        date_diff = date.today() - date(2020, 4, 20)
        # covid_links = []

        for i in range(date_diff.days + 1):
            dayy = date(2020, 4, 20) + timedelta(days=i)
            day = dayy.strftime("%B-%-d-%Y").lower()
            pdf_name = "covid-19-dashboard-{}/download".format(day)
            # covid_links.append(pdf_name)
            url = join(api_base_url, pdf_name)

            if pdf_name.split("/")[0] + ".pdf" not in existing_assets:
                if requests.get(url).status_code == 200:

                    # subprocess.run(
                    #    [
                    #        "wget --no-check-certificate",
                    #        "-O",
                    #        "pdfs/massachusetts/{}".format(pdf_name[:-9] + ".pdf"),
                    #        url,
                    #    ]
                    # )

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
                    lines += doc.getPageText(2).splitlines()
                    ## find key word to point to the age data table
                    for num, l in enumerate(lines):
                        if "Deaths and Death Rate by Age Group" in l:
                            begin_page = l.split()[-1]
                    # april-20-2020, on page 10 but in it was written as on page 11, need to check more days
                    lines = doc.getPageText(int(begin_page) - 2).splitlines()
                    lines += doc.getPageText(int(begin_page) - 1).splitlines()
                    lines += doc.getPageText(int(begin_page)).splitlines()
                    ## find key word to point to the age data plot
                    for num, l in enumerate(lines):
                        if "Deaths by Age Group in Confirmed COVID-19" in l:
                            begin_num = num
                        # if "Rate (per 100,000) of Deaths in Confirmed" in l:
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
                    doc.close()
                else:
                    print(
                        "Warning: Report for Massachusetts {} is not available".format(
                            day
                        )
                    )

    def get_louisiana(self):
        url = "https://www.arcgis.com/apps/opsdashboard/index.html#/69b726e2b82e408f89c3a54f96e8f776"
        #os.chdir("/home/zzq")
        #chromed = "D:\chromedriver.exe"
        #os.chdir("/mnt/d")
        chromed = 'D://chromedriver.exe'
        #chromed = '/chromedriver'
        browser = webdriver.Chrome(executable_path=chromed)
        #browser = webdriver.Chrome()
        #browser.get("http://ldh.la.gov/coronavirus/") # Load page
        #url = "http://ldh.la.gov/coronavirus/"
        browser.get(url)
        browser.implicitly_wait(5) # Let the page load
        # find the update day
        #find_day = browser.find_element_by_xpath('//*[@id="ember58"]').text
        #day_idx = re.search( r':.*/20', find_day).span()
        #day = find_day.text[day_idx[0]+1 : day_idx[1]]
        #day = parsedate(day).strftime('%Y-%m-%d')
        day = requests.get(url).headers['Date'].split(',')[1].split()[0:3]
        day = parsedate('/'.join(day)).strftime('%Y-%m-%d')
        if not os.access("data/{}/louisiana.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                    ## get the bottom to select the figure
                    ## path change from 202-05-21 path would change so use the class name
                    #board = browser.find_element_by_id('ember292').click()
                    #board = browser.find_element_by_id('ember254').click()
                    #board = browser.find_element_by_id('ember292').click()
                    browser.find_element_by_css_selector(
                        'button#ember297.dropdown-outside.drop-up.btn.btn-white.dropdown-btn.ember-view').click()
                    browser.find_element_by_css_selector('div#ember259.text-ellipsis.ember-view').click()
                    browser.find_element_by_css_selector(
                        'button#ember297.dropdown-outside.drop-up.btn.btn-white.dropdown-btn.ember-view').click()

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
            else:
                print('error for extracting')
        else:
            print('Report for Louisiana {} is already exist'.format(day))

        browser.close()
        browser.quit()
    def get_oklahoma(self):
        ## just have the percentage
        url = "https://looker-dashboards.ok.gov/embed/dashboards/42"
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.implicitly_wait(5)
        data = browser.find_elements_by_css_selector('tspan.highcharts-data-label')
        data = [e.text for e in data if e.text and e.text[0] >= '0' and e.text[0] <= '9']
        #total_pdf = browser.find_element_by_xpath('//*[@id="dashboard"]/div/div[2]/div/div/div/div/div[2]/div[2]/div/lk-dashboard-text/div/div/div[4]/div/p/a')
        # find the total deaths from the summary pdf
        #total_pdf = browser.find_element_by_xpath('//*[@id="dashboard"]/div/div[2]/div/div/div/div/div[2]/div[2]/div/lk-dashboard-text/div/div/div[4]/div/p/a').click()
            #.get_attribute(
            #'href')
        #browser.find_element_by_xpath('//*[@id="dashboard"]/div/div[2]/div/div/div/div/div[2]/div/div/lk-dashboard-text/div/div/div[4]/div/p[1]/a').get_attribute('href')
        ## TODO: find the element to get the pdf_url
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
            ## TODO:extract total death data from the pdf, use this date as the day
            doc = fitz.Document(
                "pdfs/oklahoma/{}.pdf".format(day)
            )
            # find the page
            lines = doc.getPageText(0).splitlines()
            total = int(lines[2])
            age_data = {}
        # ['65+ 79.14%', '50-64 17.27%', '36-49 2.16%', '18-35 1.44%', '05-17 0.00%', '00-04 0.00%'] 5.13
            for i in data:
               age_data[i.split()[0]] = int(round(total * float(i.split()[1][0:-1])* 0.01, 0))
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/oklahoma.json".format(day), "w") as f:
                json.dump(age_data, f)
        else:
            print('Report for Oklahoma {} is already exist'.format(day))

        browser.close()
        browser.quit()
    def get_nd(self):
        url = "https://www.health.nd.gov/diseases-conditions/coronavirus/north-dakota-coronavirus-cases"
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
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
        else:
            print('Report for North Dakota{} is already exist'.format(day))
        browser.close()
        browser.quit()
    def get_az(self):
        ##TODO: get the day from the web
        #        url = "https://www.azdhs.gov/preparedness/epidemiology-disease-control/infectious-disease-epidemiology/covid-19/dashboards/index.php"
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
            age_data[lines[4]] = lines[9]
            age_data[lines[0]] = lines[6]
            age_data[lines[1]] = lines[7]
            age_data[lines[2]] = lines[8]
            age_data[lines[3]] = lines[5]
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            if not os.access("data/{}/arizona.json".format(day), os.F_OK):
                with open("data/{}/arizona.json".format(day), "w") as f:
                    json.dump(age_data, f)
            else:
                print('Data for Arizona {} is already exist'.format(day))
        else:
            print('Data for Arizona {} is already exist'.format(day))
        #import urllib.request
        #urllib.request.urlretrieve(url, "pdfs/arizona/{}.pdf".format(day))

        #url = "https://www.azdhs.gov/preparedness/epidemiology-disease-control/infectious-disease-epidemiology/covid-19/dashboards/index.php"
        #chromed = "D:\chromedriver.exe"
        #browser = webdriver.Chrome(executable_path=chromed)  # Get local session of firefox
        # https://public.tableau.com/vizql/w/DPHIdahoCOVID-19Dashboard_V2/v/Story1/viewData/sessions/D09BE74481DD4BE0952A3845F3AE1670-0:0/views/13810090252421852225_1824451516651397827?maxrows=200&viz=%7B%22worksheet%22%3A%22Age%20Groups%22%2C%22dashboard%22%3A%22Table%20Dashboard%20(w%2Fdeath%20place)%22%2C%22storyboard%22%3A%22Story%201%22%2C%22story-point-id%22%3A9%7D
        #browser.get(url)
        #r = requests.get(url)
        #day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        #browser.implicitly_wait(5)
        #browser.find_element_by_css_selector('i.fas.fa-chart-bar.fa-stack-1x.fa-inverse').click()
        #browser.maximize_window()
        
        ## TODO: extract the img
        ## TODO: extract update day img
        #browser.close()
        #browser.quit()

    def get_kansas(self):
        
        #Need to get the pdf
        
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        #url = "https://www.coronavirus.kdheks.gov/160/COVID-19-in-Kansas"
        url = 'https://public.tableau.com/views/COVID-19TableauVersion2/CaseSummary?:embed=y&:showVizHome=no&:host_url=https%3A%2F%2Fpublic.tableau.com%2F&:embed_code_version=3&:tabs=no&:toolbar=yes&:animate_transition=yes&:display_static_image=no&:display_spinner=no&:display_overlay=yes&:display_count=yes&:loadOrderID=0'
        #url = 'https://public.tableau.com/views/COVID-19TableauVersion2/DeathSummary?%3Aembed=y&%3AshowVizHome=no&%3Ahost_url=https%3A%2F%2Fpublic.tableau.com%2F&%3Aembed_code_version=3&%3Atabs=no&%3Atoolbar=yes&%3Aanimate_transition=yes&%3Adisplay_static_image=no&%3Adisplay_spinner=no&%3Adisplay_overlay=yes&%3Adisplay_count=yes&%3AloadOrderID=0'
        browser.get(url)
        # get day
        browser.implicitly_wait(5)
        day = browser.find_element_by_xpath('//*[@id="tabZoneId16"]/div/div/div/div[1]/div/span/div[3]/span[2]').text.split()[0]
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/kansas.json".format(day), os.F_OK):
            # change to death page
            browser.find_element_by_xpath('//*[@id="tabZoneId216"]/div/div/div/div/div').click()
            ## download the pdf page
        else:
            print('Report for Kansas {} is already exist'.format(day))

        browser.close()
        browser.quit()
        
        doc = fitz.Document("pdfs/kansas/{}.pdf".format(day))
        lines = doc.getPageText(0).splitlines()

        ## find key word to point to the age data table
        for num, l in enumerate(lines):
            if "Deaths\tby\tAge\tGroup" in l:
                line_num = num
                break
        age_data = {}
        age_data['35-44'] = lines[line_num - 1]
        age_data['45-54'] = lines[line_num - 2]
        age_data['55-64'] = lines[line_num - 3]
        age_data['65-74'] = lines[line_num - 4]
        age_data['75-84'] = lines[line_num - 5]
        age_data['85+'] = lines[line_num - 6]

        path = "data/{}".format(day)
        if not os.path.exists(path):
            os.mkdir(path)
        with open("data/{}/kansas.json".format(day), "w") as f:
            json.dump(age_data, f)


            
            
            
         '''   
            if browser.execute_script("return document.readyState") == "complete":

        ## https://public.tableau.com/thumb/views/COVID-19TableauVersion2/CaseSummary.pdf

        data = browser.find_elements_by_css_selector('span')
        data = [e for e in data if e.get_attribute("style")]
        day = '2020-05-18'
        if not os.access("data/{}/kansas.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
            ### TODO: get the
                age_data = {}
                age_data['35-44'] = 4
                age_data['45-54'] = 7
                age_data['55-64'] = 25
                age_data['65-74'] = 30
                age_data['75-84'] = 39
                age_data['85+'] = 68

                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/kansas.json".format(day), "w") as f:
                    json.dump(age_data, f)
            else:
                print('error for extracting')
        else:
            print('Report for Kansas {} is already exist'.format(day))

        browser.close()
        browser.quit()
    '''
    def get_nc(self):
        ## do manually, download the pdf
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        #browser.get("https://covid19.ncdhhs.gov/dashboard#by-age")
        ###  from 2020-05-20 change the web....   can download
        url ='https://covid19.ncdhhs.gov/dashboard/cases'
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
            age_data['18-24'] = round(0.01 * float(lines[end_num - 2][0:-1])* total)
            age_data['25-49'] = round(0.01 * float(lines[end_num - 1][0:-1]) * total)
            age_data['50-64'] = round(0.01 * float(lines[end_num - 6][0:-1])* total)
            age_data['65-74'] = round(0.01 * float(lines[end_num - 5][0:-1]) * total)
            age_data['75+'] = round(0.01 * float(lines[end_num - 4][0:-1]) * total)
            age_data['total'] = total
            doc.close()
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/NorthCarolina.json".format(day), "w") as f:
                json.dump(age_data, f)

        else:
            print('Report for NorthCarolina {} is already exist'.format(day))
        browser.close()
        browser.quit()

        ## find key word to point to the age data table

        #case_pdf = 'https://public.tableau.com/views/NCDHHS_COVID-19_Dashboard_Cases/NCDHHS_Dashboard_Cases2.pdf?:showVizHome=no'
        #browser.get(url)
        #browser.implicitly_wait(5)
        #browser.find_element_by_xpath('//*[@id="[Parameters].[Parameter 3]_2"]/div[2]').click()
        
        #day = browser.find_element_by_xpath('//*[@id="node-103"]/div/div[1]/div/div/p[1]').text.split('.,')[-1]
        #day = parsedate(day).strftime("%Y-%m-%d")
        #if not os.access("data/{}/NorthCarolina.json".format(day), os.F_OK):
        #    browser.implicitly_wait(5)
        #    #ifbrowser.execute_script("return document.readyState") == "complete":
        #    total = int(browser.find_element_by_xpath('//*[@id="node-103"]/div/div[1]/div/div/table/tbody/tr/td[2]').text)
        #    browser.implicitly_wait(5)
        #    browser.maximize_window()
        #    browser.implicitly_wait(5)
        #    #data = browser.find_element_by_xpath('//*[@id="ui-accordion-ui-id-1-panel-3"]/section/p[5]/img')
        #    #data_web = data.get_attribute("src")
        #    data = browser.find_elements_by_css_selector('img')
        #    data_web = [e.get_attribute('src') for e in data if e.get_attribute('alt') == 'COVID-19 Deaths by Age'][0]

        #    path = "pngs/NorthCarolina"
        #    if not os.path.exists(path):
        #        os.mkdir(path)
        #    response = requests.get(data_web)
        #    with open("pngs/NorthCarolina/{}.png".format(day), "wb") as f:
        #        for data in response.iter_content(128):
        #            f.write(data)
            #image1 = Image.open(r"pngs/NorthCarolina/{}.png".format(day))
            #im1 = image1.convert('RGB')
            #im1.save(r'pdfs/NorthCarolina/{}.pdf'.format(day))
        #   path = "data/{}".format(day)
            




    #age_data = {}
    #day = '2020-05-21'
    #total = 716
    #age_data['0-17'] = 0
    #age_data['18-24'] = 1
    #age_data['25-49'] = 28
    #age_data['50-64'] = 83
    #age_data['65-74'] = 150
    #age_data['75+'] = 454

    #age_data['total'] = total

    #path = "data/{}".format(day)
    #if not os.path.exists(path):
    #    os.mkdir(path)
    #with open("data/{}/NorthCarolina.json".format(day), "w") as f:
    #    json.dump(age_data, f)
    #'''

    #'''
    def get_sc(self):
        ## TODO: find the .pdf
        url = "https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19"
        r = requests.get(url)
        day = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        # in reported deaths, find the proportion and the url
        browser.get('https://public.tableau.com/views/EpiProfile/DemoStory?:embed=y&:showVizHome=no&:host_url=https%3A%2F%2Fpublic.tableau.com%2F&:embed_code_version=3&:tabs=no&:toolbar=yes&:animate_transition=yes&:display_static_image=no&:display_spinner=no&:display_overlay=yes&:display_count=yes&publish=yes&:loadOrderID=0')
        #browser.get('https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19')
        if not os.access("data/{}/SouthCarolina.json".format(day), os.F_OK):
            browser.implicitly_wait(5)
            browser.find_element_by_css_selector('span.tabFlipboardNavNext.tab-widget.ArrowLarge').click()
    #
    #            #######  download manully
        else:
            print('Report for SouthCarolina {} is already exist'.format(day))


       if not os.access("data/{}/SouthCarolina.json".format(day), os.F_OK):
            doc = fitz.Document("pdfs/sc/{}.pdf".format(day))
            lines = doc.getPageText(1).splitlines()
            for num, l in enumerate(lines):
                if "Confirmed\tDeaths" in l:
                    total_num = num - 1
                    break

            for num, l in enumerate(lines):
                if "Reported\tCOVID-19\tDeaths,\tby\tWeek\tof\tReport\t" in l:
                    data_num = num
                    break
            age_data = {}
            total = int(lines[total_num])
            data_lines = lines[data_num + 1:]
            age_data['21-30'] = round(0.01 * float(data_lines[18][0:-1])*total)
            age_data['31-40'] = round(0.01 * float(data_lines[19][0:-1]) * total)
            age_data['41-50'] = round(0.01 * float(data_lines[20][0:-1]) * total)
            age_data['51-60'] = round(0.01 * float(data_lines[21][0:-1]) * total)
            age_data['61-70'] = round(0.01 * float(data_lines[15][0:-1]) * total)
            age_data['71-80'] = round(0.01 * float(data_lines[16][0:-1]) * total)
            age_data['81+'] = round(0.01 * float(data_lines[17][0:-1]) * total)
            doc.close()
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/SouthCarolina.json".format(day), "w") as f:
                json.dump(age_data, f)
            browser.close()
            browser.quit()

    #            data = browser.find_element_by_xpath('//*[@id="title10223277918472557951_1535545040336048298"]/div[1]/div/span/div/span')
    #            # get the total deaths
    #            total_idx = re.search( r'(=.*)', data.text).span()
    #            total = data.text[total_idx[0] + 1 : total_idx[1] - 2]
    #            total = int(total)
    #            age_data = {}
    #            age_data['21-30'] = round(0.005*total)
    #            age_data['31-40'] = round(0.005 * total)
    #            age_data['41-50'] = round(0.028 * total)
    #            age_data['51-60'] = round(0.088 * total)
    #            age_data['61-70'] = round(0.221 * total)
    #            age_data['71-80'] = round(0.303 * total)
    #            age_data['81+'] = round(0.351 * total)
    #            path = "data/{}".format(day)
    #            if not os.path.exists(path):
    #                os.mkdir(path)
    #            with open("data/{}/SouthCarolina.json".format(day), "w") as f:
    #                json.dump(age_data, f)

    #             browser.save_screenshot('pngs/SouthCarolina/{}.png'.format(day))
    #         else:
    #            print('error for extracting')
    #    else:
    #        print('Report for SouthCarolina {} is already exist'.format(day))
    #    browser.close()
    #    browser.quit()
    #'''

    def get_mississippi(self):
        r = requests.get("https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19")
        ## the reports are always published 1 day later (possibly!)
        #data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get("https://msdh.ms.gov/msdhsite/_static/14,0,420.html#Mississippi")

        day = " ".join(['2020', " ".join(browser.find_element_by_xpath('//*[@id="article"]/div/h3[1]').text.split()[-2:])])
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("pngs/Mississippi/{}.png".format(day), os.F_OK):
            data_web = 'https://msdh.ms.gov/msdhsite/_static/images/graphics/covid19-chart-age-' + str(day[5:]) + '.png'
            #if browser.execute_script("return document.readyState") == "complete":
            ## the xpath of the figure will change
                #data_web = browser.find_element_by_xpath('//*[@id="article"]/div/p[16]/img').get_attribute("src")
                #data_web = 'images/graphics/covid19-chart-age-05-15.png'
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

 #   '''
age_data = {}
age_data['<18'] = 0
age_data['18-29'] = 2
age_data['30-39'] = 10
age_data['40-49'] = 21
age_data['50-59'] = 47
age_data['60-69'] = 138
age_data['70-79'] = 172
age_data['80-89'] = 150
age_data['90+'] = 85
 
path = "data/{}".format(day)
if not os.path.exists(path):
    os.mkdir(path)
with open("data/{}/mississippi.json".format(day), "w") as f:
    json.dump(age_data, f)

#'''

    def get_missouri(self):

        url = "https://health.mo.gov/living/healthcondiseases/communicable/novel-coronavirus/results.php"
        ## change web from 2020-05-21
        url = 'https://mophep.maps.arcgis.com/apps/opsdashboard/index.html#/0c6d8b9da4494eb1bcc0c7e2187e48aa'
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        day = requests.get(url).headers['Date']
        day = "/".join(day.split(',')[1].split()[0:3])
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/missouri.json".format(day), os.F_OK):
            data = browser.find_elements_by_css_selector('g.amcharts-graph-column')
            data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label')]
            age_data = {}
            for i in range(len(data)):
                age_data[' '.join(data[i].split()[0:-1])] = data[i].split()[-1]
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/missouri.json".format(day), "w") as f:
                json.dump(age_data, f)
        else:
            print('Report for Missouri {} is already exist'.format(day))
        browser.close()
        browser.quit()
        #day = browser.find_element_by_xpath('//*[@id="main-content"]/p[5]').text.split(",")[-1]
        #day = parsedate(" ".join(['2020',day])).strftime('%Y-%m-%d')
        #if not os.access("data/{}/missouri.json".format(day), os.F_OK):
        #    browser.implicitly_wait(5)
        #    if browser.execute_script("return document.readyState") == "complete":
        #        browser.find_element_by_xpath('//*[@id="accordion"]/div[6]/a/div').click()
        #        age_data = {}
        #        for i in range(8):
        #            path1 = '//*[@id="collapsedeathages"]/div/div/table/tbody/tr[' + str(i + 1) + ']/td[' + str(1) + ']'
        #            path2 = '//*[@id="collapsedeathages"]/div/div/table/tbody/tr[' + str(i + 1) + ']/td[' + str(2) + ']'
        #            data1 = browser.find_element_by_xpath(path1)
        #            data2 = browser.find_element_by_xpath(path2)
        #            age_data[data1.text] = data2.text



    def get_kentucky(self):
        url = "https://kygeonet.maps.arcgis.com/apps/opsdashboard/index.html#/543ac64bc40445918cf8bc34dc40e334"
        r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        #day = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        # 5 pm BST update
        day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        ## //*[@id="ember57"]/div/div/svg/g[7]/g/g/g[1]
        browser.implicitly_wait(5)
        data = browser.find_elements_by_css_selector('g.amcharts-graph-column')
        # data contain the cases and deaths
        browser.implicitly_wait(5)
        data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label')]
        browser.implicitly_wait(5)
        if not os.access("data/{}/kentucky.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                # begin at data[9]
                age_data = {}
                data = data[9:15]
                for i in data:
                    age_data[i.split()[0]] = i.split()[1]
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/kentucky.json".format(day), "w") as f:
                    json.dump(age_data, f)
            else:
                print('error for extracting')
        else:
            print('Report for kentucky {} is already exist'.format(day))

        browser.close()
        browser.quit()
    def get_delware(self):
        ## TODO: get the update day
        url = "https://myhealthycommunity.dhss.delaware.gov/about/acceptable-use"
        #r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        #day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
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
            else:
                print('error for extracting')
        else:
            print('Report for Delaware {} is already exist'.format(day))

        browser.close()
        browser.quit()
    def get_vermont(self):
        url = "https://vcgi.maps.arcgis.com/apps/opsdashboard/index.html#/6128a0bc9ae14e98a686b635001ef7a7"
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
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
            else:
                print('error for extracting')
        else:
            print('Report for Vermont {} is already exist'.format(day))
        browser.close()
        browser.quit()

        ###################################################
        ## install Pillow
        from PIL import Image

        ##################################################


    def get_california(self):
        url = 'https://public.tableau.com/views/COVID-19PublicDashboard/Covid-19Public?%3Aembed=y&%3Adisplay_count=no&%3AshowVizHome=no'
        url = 'https://www.cdph.ca.gov/Programs/CID/DCDC/Pages/COVID-19/Race-Ethnicity.aspx'
        #soup = BeautifulSoup(url)
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
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
                print('error for extracting')
        browser.close()
        browser.quit()

#browser.maximize_window()
        #day = browser.find_element_by_xpath('//*[@id="title8860806102834544352_18161636954798804938"]/div[1]/div/span/div/span[2]').text
        #day = parsedate(day).strftime('%Y-%m-%d')
        #if not os.access("pngs/California/{}.png".format(day), os.F_OK):
        #    if browser.execute_script("return document.readyState") == "complete":
                # change to the death web
                #browser.find_element_by_xpath('//*[@id="tableau_base_widget_ParameterControl_0"]/div/div[2]/span/div[1]').click()
                # the xpath will change
                #browser.find_element_by_xpath('//*[@id="tab-menuItem24"]/div').click()
                #button = browser.find_elements_by_css_selector('span.tabMenuItemName')
                #[e for e in button if e.text == 'Deaths'][0].click()
                #browser.implicitly_wait(5)
                #data = browser.find_element_by_xpath('//*[@id="tabZoneId257"]/div/div/div/div[1]')

                #path = "pngs/California"
                #if not os.path.exists(path):
                #    os.mkdir(path)
                #browser.implicitly_wait(5)
                #browser.save_screenshot('pngs/California/{}.png'.format(day))
                #left = data.location['x']
                #top = data.location['y']
                #right = data.location['x'] + data.size['width']
                #bottom = data.location['y'] + data.size['height']

                #im = Image.open('pngs/California/{}.png'.format(day))
                #im = im.crop((left, top, right, bottom))
                #im.save('pngs/California/{}.png'.format(day))



    
    
    

    def get_illinois(self):
        ## TODO: extract
        url = 'https://www.dph.illinois.gov/covid19/covid19-statistics'

        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.implicitly_wait(5)
        day = parsedate(browser.find_element_by_xpath('//*[@id="updatedDate"]').text).strftime('%Y-%m-%d')
        if not os.access("pngs/Illinois/{}.png".format(day), os.F_OK):
            browser.find_element_by_xpath('//*[@id="liAgeChartDeaths"]/a').click()
            browser.maximize_window()
            
                  
            
            if browser.execute_script("return document.readyState") == "complete":
                # get the death page
                data = browser.find_element_by_id('pieAge')
                #if not os.access("data/{}/  .json".format(day), os.F_OK):
                #    if browser.execute_script("return document.readyState") == "complete":
                browser.maximize_window()
                browser.implicitly_wait(5)
                path = "pngs/Illinois"
                if not os.path.exists(path):
                    os.mkdir(path)
                browser.save_screenshot('pngs/Illinois/{}.png'.format(day))
                left = data.location['x']
                top = data.location['y']
                right = data.location['x'] + data.size['width']
                bottom = data.location['y'] + data.size['height']

                im = Image.open('pngs/Illinois/{}.png'.format(day))
                im = im.crop((left, top, right, bottom))
                im.save('pngs/Illinois/{}.png'.format(day))
            else:
                print('error for extracting')
        else:
            print('Report for Illinois {} is already exist'.format(day))

        browser.close()
        browser.quit()

#age_data = {}
#day = '2020-05-21'
#age_data['<20'] = 3
#age_data['20-29'] = 18
#age_data['30-39'] = 72
#age_data['40-49'] = 157
#age_data['50-59'] = 387
#age_data['60-69'] = 813
#age_data['70-79'] = 1113
#age_data['80+'] = 2044

#browser.save_screenshot('pngs/Illinois/{}.png'.format(day))
#path = "data/{}".format(day)
#if not os.path.exists(path):
#    os.mkdir(path)
#with open("data/{}/illinois.json".format(day), "w") as f:
#    json.dump(age_data, f)
#    '''

    def get_indiana(self):
        #url = 'https://www.coronavirus.in.gov/'
        url = 'https://www.coronavirus.in.gov/map/test.htm'
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.implicitly_wait(5)
        #browser.find_element_by_xpath('//*[@id="prefix-overlay-header"]/button').click()
        day = browser.find_element_by_xpath('//*[@id="root"]/div[1]/div/div[1]/div[2]/p[1]/b[1]').text.split(',')[0]
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/indiana.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":

                total = browser.find_element_by_xpath('//*[@id="main-content"]/div[2]/div[5]/div/h2').text
                total = int(''.join(total.split(',')))
                # change to death page
                browser.find_element_by_xpath('//*[@id="demographics-charts-tab-demographics-deaths"]').click()
                browser.implicitly_wait(5)
                data = browser.find_elements_by_css_selector('text')
                # delete the '%'
                data = [e.text[0:-1] for e in data if e.get_attribute('x') == '80'][1:10]
                time.sleep(5)
                group = browser.find_elements_by_css_selector('tspan')
                group = [e.text for e in group if e.get_attribute('x') == '72'][0:9]
                time.sleep(5)
                age_data = {}
                for i in range(len(data)):
                    age_data[group[i]] = round(float(data[i]) * 0.01 * total)
                time.sleep(5)
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/indiana.json".format(day), "w") as f:
                    json.dump(age_data, f)
            else:
                print('error for extracting')
        else:
            print('Report for indiana {} is already exist'.format(day))

        browser.close()
        browser.quit()
    def get_maryland(self):
        ## update
        url = 'https://coronavirus.maryland.gov/'
        day = parsedate("/".join(requests.get(url).headers['Date'].split()[1:4])).strftime('%Y-%m-%d')
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.implicitly_wait(5)
        if not os.access("data/{}/maryland.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                age_data = {}
                for i in range(9):
                    group = browser.find_element_by_xpath('//*[@id="ember89"]/div/table[2]/tbody/tr[' + str(i + 2) + ']/td[1]').text
                    data = browser.find_element_by_xpath('//*[@id="ember89"]/div/table[2]/tbody/tr[' + str(i + 2) + ']/td[3]').text
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
    #AgeExtractor().get_massachusetts()

    AgeExtractor().get_louisiana()
    #AgeExtractor().get_oklahoma()
    #AgeExtractor().get_nd()
    #AgeExtractor().get_az()
    #AgeExtractor().get_nc()
    #AgeExtractor().get_mississippi()
    #AgeExtractor().get_missouri()
    #AgeExtractor().get_kentucky()
    #AgeExtractor().get_delware()
    #AgeExtractor().get_vermont()
    #AgeExtractor().get_california()
    #AgeExtractor().get_indiana()
    #AgeExtractor().get_maryland()
