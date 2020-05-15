# need install selenium
from selenium import webdriver
from selenium.common.exceptions import NoSuchElementException
from selenium.webdriver.common.action_chains import ActionChains
import time
import re
import os
from datetime import date
import json
import requests
from dateutil.parser import parse as parsedate
import base64
from os.path import basename, join
from glob import glob
from PIL import Image


class AgeExtractor:
    def __init__(self):
        self.today = date.today().strftime("%Y-%m-%d")
    def get_louisiana(self):
        url = "https://www.arcgis.com/apps/opsdashboard/index.html#/69b726e2b82e408f89c3a54f96e8f776"
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        #browser.get("http://ldh.la.gov/coronavirus/") # Load page
        #url = "http://ldh.la.gov/coronavirus/"
        browser.get(url)
        browser.implicitly_wait(5) # Let the page load
        # find the update day
        find_day = browser.find_element_by_xpath('//*[@id="ember159"]')
        day_idx = re.search( r':.*/2020', find_day.text).span()
        day = find_day.text[day_idx[0]+1 : day_idx[1]]
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("data/{}/louisiana.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                    ## get the bottom to select the figure
                    board = browser.find_element_by_id('ember294').click()
                    board = browser.find_element_by_id('ember251').click()
                    board = browser.find_element_by_id('ember294').click()

                    board = browser.find_elements_by_css_selector('g.amcharts-graph-column')#.amcharts-graph-graphAuto1_1589372672251')
                    data = [e.get_attribute('aria-label') for e in board if e.get_attribute('aria-label') and 'Deaths' in e.get_attribute('aria-label')]
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
            print('Report for Louisiana{} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_idaho(self):
        ##  TODO:

        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)  # Get local session of chrome
        url = 'https://public.tableau.com/views/DPHIdahoCOVID-19Dashboard_V2/Story1?%3Aembed=y&%3AshowVizHome=no&%3Adisplay_count=y&%3Adisplay_static_image=y&%3AbootstrapWhenNotified=true'
        browser.get(url)
        day_url = 'https://public.tableau.com/profile/idaho.division.of.public.health#!/vizhome/DPHIdahoCOVID-19Dashboard_V2/Story1'

        #r = requests.get('https://public.tableau.com/vizql/w/DPHIdahoCOVID-19Dashboard_V2/v/Story1/viewData/sessions/D09BE74481DD4BE0952A3845F3AE1670-0:0/views/13810090252421852225_1824451516651397827?maxrows=200&viz=%7B%22worksheet%22%3A%22Age%20Groups%22%2C%22dashboard%22%3A%22Table%20Dashboard%20(w%2Fdeath%20place)%22%2C%22storyboard%22%3A%22Story%201%22%2C%22story-point-id%22%3A9%7D')
        #day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        ## download csv file

        browser.execute_script("document.getElementsByClassName('tabStoryPointContent')[5].click()")
        #data_summary = "https://public.tableau.com/vizql/w/DPHIdahoCOVID-19Dashboard_V2/v/Story1/viewData/sessions/8EC22492895145A2A4EEDFB5904F59AF-0:0/views/13810090252421852225_1824451516651397827?maxrows=200&viz=%7B%22worksheet%22%3A%22Age%20Groups%22%2C%22dashboard%22%3A%22Table%20Dashboard%20(w%2Fdeath%20place)%22%2C%22storyboard%22%3A%22Story%201%22%2C%22story-point-id%22%3A9%7D"
        ## cannot find the id
        right_click = browser.find_element_by_id("xxxx")
        ActionChains(browser).context_click(right_click).perform()

        """"
        day = '2020-05-13'
        age_data = {}
        age_data['<18'] = 0
        age_data['18-29'] = 0
        age_data['30-39'] = 0
        age_data['40-49'] = 0
        age_data['50-59'] = 2
        age_data['60-69'] = 9
        age_data['70-79'] = 12
        age_data['80+'] = 45
        path = "data/{}".format(day)
        if not os.path.exists(path):
            os.mkdir(path)
        with open("data/{}/idaho.json".format(day), "w") as f:
            json.dump(age_data, f)
        """
        #canvas = browser.find_element_by_xpath('//*[@id="view13810090252421852225_1824451516651397827"]/div[1]/div[2]/canvas[2]')
        # get the canvas as a PNG base64 string
        #canvas_base64 = browser.execute_script("return arguments[0].toDataURL('image/png').substring(21);", canvas)

        # decode
        #canvas_png = base64.b64decode(canvas_base64)

        # save to a file
        ## TODO: find a way to download the canvas
        #path = "figures/Ldaho"
        #if not os.path.exists(path):
        #    os.mkdir(path)
        #with open(r"figures/Idaho/{}.png".format(day), "wb") as f:
            #for data in canvas_png.iter_content(128):
        #     f.write(canvas_png)


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
            if browser.execute_script("return document.readyState") == "complete":
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
            else:
                print('error for extracting')
        else:
            print('Report for North Dakota{} is already exist'.format(day))
        browser.close()
        browser.quit()




    def get_az(self):
        ##TODO: get the day from the web
        #         url = "https://www.azdhs.gov/preparedness/epidemiology-disease-control/infectious-disease-epidemiology/covid-19/dashboards/index.php"
        day = '2020-05-15'
        if not os.access("data/{}/arizona.json".format(day), os.F_OK):
            url = 'https://tableau.azdhs.gov/views/COVID-19Deaths/Deaths/sheet.pdf'
            with open("pdfs/arizona/{}.pdf".format(day), "wb") as f:
                response = requests.get(url)
                f.write(response.content)
        #import urllib.request
        #urllib.request.urlretrieve(url, "pdfs/arizona/{}.pdf".format(day))
        '''''
        url = "https://www.azdhs.gov/preparedness/epidemiology-disease-control/infectious-disease-epidemiology/covid-19/dashboards/index.php"
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)  # Get local session of firefox
        # https://public.tableau.com/vizql/w/DPHIdahoCOVID-19Dashboard_V2/v/Story1/viewData/sessions/D09BE74481DD4BE0952A3845F3AE1670-0:0/views/13810090252421852225_1824451516651397827?maxrows=200&viz=%7B%22worksheet%22%3A%22Age%20Groups%22%2C%22dashboard%22%3A%22Table%20Dashboard%20(w%2Fdeath%20place)%22%2C%22storyboard%22%3A%22Story%201%22%2C%22story-point-id%22%3A9%7D
        browser.get(url)
        #r = requests.get(url)
        #day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        browser.implicitly_wait(5)
        browser.find_element_by_css_selector('i.fas.fa-chart-bar.fa-stack-1x.fa-inverse').click()
        browser.maximize_window()
        
        ## TODO: extract the img
        ## TODO: extract update day img
        day = '2020-05-14'
        age_data = {}
        age_data['<20'] = 1
        age_data['20-44'] = 24
        age_data['45-54'] = 31
        age_data['55-64'] = 71
        age_data['65+'] = 497
        path = "data/{}".format(day)
        if not os.path.exists(path):
            os.mkdir(path)
        with open("data/{}/arizona.json".format(day), "w") as f:
            json.dump(age_data, f)
        
        browser.close()
        browser.quit()

        '''''



    def get_oklahma(self):
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
        path = "pdfs/oklahma"
        if not os.path.exists(path):
            os.mkdir(path)
        with open("pdfs/oklahma/" + day + ".pdf", "wb") as f:
            response = requests.get(pdf_url)
            f.write(response.content)
        ## TODO:extract total death data from the pdf, use this date as the day
        doc = fitz.Document(
            "pdfs/oklahma/{}.pdf".format(day)
        )
        # find the page
        lines = doc.getPageText(0).splitlines()
        total = int(lines[2])
        if not os.access("data/{}/oklandoma.json".format(day), os.F_OK):
            age_data = {}
        # ['65+ 79.14%', '50-64 17.27%', '36-49 2.16%', '18-35 1.44%', '05-17 0.00%', '00-04 0.00%'] 5.13
            for i in data:
               age_data[i.split()[0]] = int(round(total * float(i.split()[1][0:-1])* 0.01, 0))
            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/oklandoma.json".format(day), "w") as f:
                json.dump(age_data, f)
        else:
            print('Report for Oklandoma{} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_kansas(self):
        # don't know the day
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        url = "https://www.coronavirus.kdheks.gov/160/COVID-19-in-Kansas"
        #url = "https://public.tableau.com/views/COVID-19TableauVersion2/DeathSummary?%3Aembed=y&%3AshowVizHome=no&%3Ahost_url=https%3A%2F%2Fpublic.tableau.com%2F&%3Aembed_code_version=3&%3Atabs=no&%3Atoolbar=yes&%3Aanimate_transition=yes&%3Adisplay_static_image=no&%3Adisplay_spinner=no&%3Adisplay_overlay=yes&%3Adisplay_count=yes&%3AloadOrderID=0"
        url = "https://public.tableau.com/views/COVID-19TableauVersion2/CaseSummary?:embed=y&:showVizHome=no&:host_url=https%3A%2F%2Fpublic.tableau.com%2F&:embed_code_version=3&:tabs=no&:toolbar=yes&:animate_transition=yes&:display_static_image=no&:display_spinner=no&:display_overlay=yes&:display_count=yes&:loadOrderID=0"
        url = 'https://public.tableau.com/views/COVID-19TableauVersion2/DeathSummary?%3Aembed=y&%3AshowVizHome=no&%3Ahost_url=https%3A%2F%2Fpublic.tableau.com%2F&%3Aembed_code_version=3&%3Atabs=no&%3Atoolbar=yes&%3Aanimate_transition=yes&%3Adisplay_static_image=no&%3Adisplay_spinner=no&%3Adisplay_overlay=yes&%3Adisplay_count=yes&%3AloadOrderID=0'
        browser.get(url)
        # get day
        browser.implicitly_wait(5)
        day = browser.find_element_by_xpath('//*[@id="tabZoneId16"]/div/div/div/div[1]/div/span/div[3]/span[2]').text.split()[0]
        day = parsedate(day).strftime('%Y-%m-%d')
        ## https://public.tableau.com/thumb/views/COVID-19TableauVersion2/CaseSummary.pdf
        data = browser.find_elements_by_css_selector('span')
        data = [e for e in data if e.get_attribute("style")]
        day = '2020-05-13'
        if not os.access("data/{}/kansas.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
            ### TODO: get the
                age_date = {}
                age_date['35-44'] = 5
                age_date['45-54'] = 7
                age_date['55-64'] = 25
                age_date['65-74'] = 30
                age_date['75-84'] = 39
                age_date['85+'] = 66

                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/kansas.json".format(day), "w") as f:
                    json.dump(age_date, f)
            else:
                print('error for extracting')
        else:
            print('Report for Kansas {} is already exist'.format(day))

        browser.close()
        browser.quit()

    def get_nc(self):
        ## figure
        r = requests.get(
            "https://covid19.ncdhhs.gov/dashboard#by-age"
        )
        ## the reports are always published 1 day later (possibly!)
        # data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        ## TODO: check if we need to update
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get("https://covid19.ncdhhs.gov/dashboard#by-age")
        browser.implicitly_wait(5)
        day = browser.find_element_by_xpath('//*[@id="node-103"]/div/div[1]/div/div/p[1]').text.split('.,')[-1]
        day = parsedate(day).strftime("%Y-%m-%d")
        if not os.access("data/{}/NorthCarolina.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                total = int(browser.find_element_by_xpath('//*[@id="node-103"]/div/div[1]/div/div/table/tbody/tr/td[2]').text)
                browser.implicitly_wait(5)
                browser.maximize_window()
                #data = browser.find_element_by_xpath('//*[@id="ui-accordion-ui-id-1-panel-3"]/section/p[5]/img')
                #data_web = data.get_attribute("src")
                data = browser.find_elements_by_css_selector('img')
                data_web = [e.get_attribute('src') for e in data if e.get_attribute('alt') == 'COVID-19 Deaths by Age'][0]

                path = "figures/NorthCarolina"
                if not os.path.exists(path):
                    os.mkdir(path)
                response = requests.get(data_web)
                with open("figures/NorthCarolina/{}.png".format(day), "wb") as f:
                    for data in response.iter_content(128):
                        f.write(data)
                path = "data/{}".format(day)
                data = {}
                data['total'] = total
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/NorthCarolina.json".format(day), "w") as f:
                    json.dump(data,f)
            else:
                print('error for extracting')
        else:
            print('Report for NorthCarolina {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_sc(self):
        url = "https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19"
        r = requests.get(url)
        day = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        # in reported deaths, find the proportion and the url
        browser.get('https://public.tableau.com/views/EpiProfile/DemoStory?:embed=y&:showVizHome=no&:host_url=https%3A%2F%2Fpublic.tableau.com%2F&:embed_code_version=3&:tabs=no&:toolbar=yes&:animate_transition=yes&:display_static_image=no&:display_spinner=no&:display_overlay=yes&:display_count=yes&publish=yes&:loadOrderID=0')
        #browser.get('https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19')
        if not os.access("data/{}/SouthCarolina.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                browser.find_element_by_css_selector('span.tabFlipboardNavNext.tab-widget.ArrowLarge').click()
                data = browser.find_element_by_xpath('//*[@id="title10223277918472557951_1535545040336048298"]/div[1]/div/span/div/span')
                # get the total deaths
                total_idx = re.search( r'(=.*)', data.text).span()
                total = data.text[total_idx[0] + 1 : total_idx[1] - 2]
                total = int(total)

                age_data = {}
                age_data['21-30'] = round(0.005*total)
                age_data['31-40'] = round(0.003 * total)
                age_data['41-50'] = round(0.032 * total)
                age_data['51-60'] = round(0.084 * total)
                age_data['61-70'] = round(0.221 * total)
                age_data['71-80'] = round(0.300 * total)
                age_data['81+'] = round(0.355 * total)
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/SouthCarolina.json".format(day), "w") as f:
                    json.dump(age_data, f)
            else:
                print('error for extracting')
        else:
            print('Report for SouthCarolina {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_mississippi(self):

        ##  TODO:add date time, not the web updated time, not the same
        r = requests.get("https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19")
        ## the reports are always published 1 day later (possibly!)
        #data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get("https://msdh.ms.gov/msdhsite/_static/14,0,420.html#Mississippi")

        day = " ".join(['2020', " ".join(browser.find_element_by_xpath('//*[@id="article"]/div/h3[1]').text.split()[-2:])])
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("figures/Mississippi/{}.png".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
        ## the xpath of the figure will change
                data_web = browser.find_element_by_xpath('//*[@id="article"]/div/p[16]/img').get_attribute("src")
                path = "figures/Mississippi"
                if not os.path.exists(path):
                    os.mkdir(path)
                response = requests.get(data_web)
                with open("figures/Mississippi/{}.png".format(day), "wb") as f:
                    for data in response.iter_content(128):
                        f.write(data)
            else:
                print('error for extracting')
        else:
            print('Report for Mississippi {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_missouri(self):

        url = "https://health.mo.gov/living/healthcondiseases/communicable/novel-coronavirus/results.php"
        #r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        #day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        day = browser.find_element_by_xpath('//*[@id="main-content"]/p[5]').text.split(",")[-1]
        day = parsedate(" ".join(['2020',day])).strftime('%Y-%m-%d')
        if not os.access("data/{}/missouri.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                browser.find_element_by_xpath('//*[@id="accordion"]/div[6]/a/div').click()
                age_data = {}
                for i in range(8):
                    path1 = '//*[@id="collapsedeathages"]/div/div/table/tbody/tr[' + str(i + 1) + ']/td[' + str(1) + ']'
                    path2 = '//*[@id="collapsedeathages"]/div/div/table/tbody/tr[' + str(i + 1) + ']/td[' + str(2) + ']'
                    data1 = browser.find_element_by_xpath(path1)
                    data2 = browser.find_element_by_xpath(path2)
                    age_data[data1.text] = data2.text
                path = "data/{}".format(day)
                if not os.path.exists(path):
                    os.mkdir(path)
                with open("data/{}/missouri.json".format(day), "w") as f:
                    json.dump(age_data, f)
            else:
                print('error for extracting')
        else:
            print('Report for Missouri {} is already exist'.format(day))
        browser.close()
        browser.quit()

    def get_ioawa(self):
        url = "https://coronavirus.iowa.gov/pages/case-counts"

        r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        #day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        if not os.access("data/{}/kansas.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":

        ActionChains(browser).move_by_offset(30,282).context_click().perform()

        age_data = {}
        total = 336
        day = '2020-05-14'
        age_data['18-40'] = 0.0209 * total
        age_data['41-60'] = 0.1015 * total
        age_data['61-80'] = 0.406 * total
        age_data['>80'] = 0.4716 * total
        path = "data/{}".format(day)
        if not os.path.exists(path):
            os.mkdir(path)
        with open("data/{}/ioawa.json".format(day), "w") as f:
            json.dump(age_data, f)
        browser.close()
        browser.quit()

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
        data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label')]
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
        day = browser.find_element_by_xpath('//*[@id="outcomes"]/div/div[2]/div[1]/div/div[1]/div/span').text.split(':')[1]
        day = parsedate(day).strftime("%Y-%m-%d")
        if not os.access("data/{}/delaware.json".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                age_data = {}
                for i in range(6):
                    path1 = browser.find_element_by_xpath('//*[@id="outcomes"]/div/div[2]/div[1]/div/div[2]/div/div[2]/div/table/tbody/tr[' + str(i + 1) + ']/td[1]')
                    path2 = browser.find_element_by_xpath('//*[@id="outcomes"]/div/div[2]/div[1]/div/div[2]/div/div[2]/div/table/tbody/tr['+ str(i + 1) + ']/td[2]')
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
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.implicitly_wait(5)
        browser.maximize_window()
        day = browser.find_element_by_xpath('//*[@id="title8860806102834544352_18161636954798804938"]/div[1]/div/span/div/span[2]').text
        day = parsedate(day).strftime('%Y-%m-%d')
        if not os.access("figures/California/{}.png".format(day), os.F_OK):
            if browser.execute_script("return document.readyState") == "complete":
                # change to the death web
                browser.find_element_by_xpath('//*[@id="tableau_base_widget_ParameterControl_0"]/div/div[2]/span/div[1]').click()
                browser.find_element_by_xpath('//*[@id="tab-menuItem24"]/div').click()
                browser.implicitly_wait(5)
                #data = browser.find_element_by_xpath('//*[@id="tabZoneId257"]/div/div/div/div[1]')
                path = "figures/California"
                if not os.path.exists(path):
                    os.mkdir(path)
                browser.save_screenshot('figures/California/{}.png'.format(day))
                #left = data.location['x']
                #top = data.location['y']
                #right = data.location['x'] + data.size['width']
                #bottom = data.location['y'] + data.size['height']

                #im = Image.open('figures/California/{}.png'.format(day))
                #im = im.crop((left, top, right, bottom))
                #im.save('figures/California/{}.png'.format(day))
            else:
                print('error for extracting')
        else:
            print('Report for California {} is already exist'.format(day))

        browser.close()
        browser.quit()


    '''
    # already have
    def get_col(self):
        day_url = "https://covid19.colorado.gov/data/case-data"
        day = requests.get(day_url).headers['Last-Modified']
        day = '/'.join(day.split(',')[1].split()[0:3])
        day = parsedate(day).strftime('%Y-%m-%d')
        ##  ?? Today?
        # get the google drive
        url = "https://drive.google.com/drive/folders/1bBAC7H-pdEDgPxRuU_eR36ghzc0HWNf1"
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.implicitly_wait(5)
        browser.find_element_by_xpath(
            '//*[@id="drive_main_page"]/div[2]/div[1]/div[1]/div/div/div[2]/div/div/div[2]/div/div[2]/div/div[3]').click()
        browser.find_element_by_xpath(
            '//*[@id=":2h"]/div/c-wiz/div[2]/c-wiz/div[1]/c-wiz/div/div/div[2]/div/div[2]').click()
        data_name = browser.find_element_by_xpath(
            '//*[@id=":2h"]/div/c-wiz/div[2]/c-wiz/div[1]/c-wiz/div/c-wiz/div[1]/c-wiz/c-wiz/div/c-wiz[1]/div/div/div/div[2]/div[2]/div').text
        day = data_name.split('_')[-1].split('.')[0]
        existing = list(
            map(basename, glob('data/{}/colorado.csv'.format(day)))
        )

        if data_name not in existing:
            browser.find_element_by_xpath(
                '//*[@id=":2h"]/div/c-wiz/div[2]/c-wiz/div[1]/c-wiz/div/c-wiz/div[1]/c-wiz/c-wiz/div/c-wiz[1]/div/div/div/div[6]/div/span').click()

        ##

        
        day_url =  "https://covid19.colorado.gov/data/case-data"

        url = "https://public.tableau.com/views/COVID19_CaseSummary_TP/COVID-19CaseSummary-TP?:embed=y&:showVizHome=no&:host_url=https%3A%2F%2Fpublic.tableau.com%2F&:embed_code_version=3&:tabs=no&:toolbar=yes&:animate_transition=yes&:display_static_image=no&:display_spinner=no&:display_overlay=yes&:display_count=yes&publish=yes&:loadOrderID=0"
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.implicitly_wait(5)
        # r = requests.get(url).headers['Last-Modified'] : 4.28
        data = browser.find_element_by_xpath('//*[@id="view86241192239202246_3261385895376696909"]')


        path = 'figures/Colorado'
        if not os.path.exists(path):
            os.mkdir(path)
        data_fig = data.screenshot_as_base64
        data_fig = data.screenshot_as_base64()



        data_location = data.location
        data_size = data.size
        left = data.location['x']
        top = data.location['y']
        right = data.location['x'] + data.size['width']
        bottom = data.location['y'] + data.size['height']
        path = "figures/Colorado"
        if not os.path.exists(path):
            os.mkdir(path)
        response = requests.get(data_web)
        with open("figures/Colorado/{}.png".format(day), "wb") as f:
            for data in response.iter_content(128):
                f.write(data)
        browser.get_screenshot_as_file('/Screenshots/foo.png')
        im = Image.open('button.png')
        im = im.crop((left, top, right, bottom))
        im.save('button.png')
        """
        browser.close()
        browser.quit()
        '''


    def get_illinois(self):
        ## TODO: extract
        url = 'https://www.dph.illinois.gov/covid19/covid19-statistics'

        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.implicitly_wait(5)
        # get the death page
        browser.find_element_by_xpath('//*[@id="liAgeChartDeaths"]/a').click()

        data = browser.find_element_by_id('pieAge')
        browser.maximize_window()
        browser.implicitly_wait(5)
        path = "figures/Illinois"
        if not os.path.exists(path):
            os.mkdir(path)
        browser.save_screenshot('figures/Illinois/{}.png'.format(day))
        left = data.location['x']
        top = data.location['y']
        right = data.location['x'] + data.size['width']
        bottom = data.location['y'] + data.size['height']

        im = Image.open('figures/Illinois/{}.png'.format(day))
        im = im.crop((left, top, right, bottom))
        im.save('figures/Illinois/{}.png'.format(day))


        browser.close()
        browser.quit()

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
                data = browser.find_elements_by_css_selector('text')
                # delete the '%'
                data = [e.text[0:-1] for e in data if e.get_attribute('x') == '80'][1:10]
                browser.implicitly_wait(5)
                group = browser.find_elements_by_css_selector('tspan')
                group = [e.text for e in group if e.get_attribute('x') == '72'][0:9]
                browser.implicitly_wait(5)
                age_data = {}
                for i in range(len(data)):
                    age_data[group[i]] = round(float(data[i]) * 0.01 * total)
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

    ''''
    # exists
    def get_mi(self):
        url = 'https://www.michigan.gov/coronavirus/0,9753,7-406-98163_98173---,00.html'
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.implicitly_wait(5)
        day = browser.find_element_by_xpath('//*[@id="main"]/div[3]/div[2]/div[1]/div[1]/div/p[2]/strong').text.split()[3]
        day = parsedate(day[1:-2]+'20').strftime('%Y-%m-%d')
        ## cannot find the age deaths

        browser.close()
        browser.quit()
    '''

if __name__ == "__main__":
    AgeExtractor().get_louisiana()
    AgeExtractor().get_idaho()
    #AgeExtractor().get_sc()
    AgeExtractor().get_mppi()