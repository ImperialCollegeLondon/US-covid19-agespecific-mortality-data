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

class AgeExtractor:
    def __init__(self):
        self.today = date.today().strftime("%Y-%m-%d")
    def get_lo(self):
        ##  TODO:
        #existing_assets = list(map(basename, glob("data/louisiana/*.json")))
        #pa=re.compile(r'\w+')
        url = "https://www.arcgis.com/apps/opsdashboard/index.html#/69b726e2b82e408f89c3a54f96e8f776"
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed) # Get local session of firefox
        #browser.get("http://ldh.la.gov/coronavirus/") # Load page
        browser.get("https://www.arcgis.com/apps/opsdashboard/index.html#/69b726e2b82e408f89c3a54f96e8f776")
        browser.implicitly_wait(5) # Let the page load
        # find the update day
        find_day = browser.find_element_by_xpath('//*[@id="ember159"]')
        day_idx = re.search( r':.*/2020', find_day.text).span()
        day = find_day.text[day_idx[0]+1 : day_idx[1]]
        day = parsedate(day).strftime('%Y-%m-%d')
        try:
            ## get the bottom to select the figure
            board = browser.find_element_by_id('ember294').click()
            board = browser.find_element_by_id('ember251').click()
            board = browser.find_element_by_id('ember294').click()

            board = browser.find_elements_by_css_selector('g.amcharts-graph-column')#.amcharts-graph-graphAuto1_1589372672251')
            data = [e.get_attribute('aria-label') for e in board if e.get_attribute('aria-label') and 'Deaths' in e.get_attribute('aria-label')]
            age_data ={}
            for a in data:
                age_data[" ".join(a.split()[1:-1])] = a.split()[-1]

            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/louisiana.json".format(day), "w") as f:
                json.dump(age_data, f)
        except:
            print(
                "Warning: Report for Massachusetts {} is not available".format(
                    day
                )
            )

        browser.close()
        browser.quit()

    def get_id(self):
        ##  TODO:
        # existing_assets = list(map(basename, glob("data/louisiana/*.json")))
        # pa=re.compile(r'\w+')
        #url = ("https://public.tableau.com/profile/idaho.division.of.public.health#!/vizhome/DPHIdahoCOVID-19Dashboard_V2/Story1")
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)  # Get local session of chrome
        # https://public.tableau.com/vizql/w/DPHIdahoCOVID-19Dashboard_V2/v/Story1/viewData/sessions/D09BE74481DD4BE0952A3845F3AE1670-0:0/views/13810090252421852225_1824451516651397827?maxrows=200&viz=%7B%22worksheet%22%3A%22Age%20Groups%22%2C%22dashboard%22%3A%22Table%20Dashboard%20(w%2Fdeath%20place)%22%2C%22storyboard%22%3A%22Story%201%22%2C%22story-point-id%22%3A9%7D
        url = 'https://public.tableau.com/views/DPHIdahoCOVID-19Dashboard_V2/Story1?%3Aembed=y&%3AshowVizHome=no&%3Adisplay_count=y&%3Adisplay_static_image=y&%3AbootstrapWhenNotified=true'
        browser.get(url)
        #r = requests.get('https://public.tableau.com/vizql/w/DPHIdahoCOVID-19Dashboard_V2/v/Story1/viewData/sessions/D09BE74481DD4BE0952A3845F3AE1670-0:0/views/13810090252421852225_1824451516651397827?maxrows=200&viz=%7B%22worksheet%22%3A%22Age%20Groups%22%2C%22dashboard%22%3A%22Table%20Dashboard%20(w%2Fdeath%20place)%22%2C%22storyboard%22%3A%22Story%201%22%2C%22story-point-id%22%3A9%7D')
        #day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        ## download csv file

        ## TODO: make sure the updated day

        browser.execute_script("document.getElementsByClassName('tabStoryPointContent')[5].click()")
        #data_summary = "https://public.tableau.com/vizql/w/DPHIdahoCOVID-19Dashboard_V2/v/Story1/viewData/sessions/8EC22492895145A2A4EEDFB5904F59AF-0:0/views/13810090252421852225_1824451516651397827?maxrows=200&viz=%7B%22worksheet%22%3A%22Age%20Groups%22%2C%22dashboard%22%3A%22Table%20Dashboard%20(w%2Fdeath%20place)%22%2C%22storyboard%22%3A%22Story%201%22%2C%22story-point-id%22%3A9%7D"
        ## cannot find the id
        right_click = browser.find_element_by_id("xxxx")
        ActionChains(browser).context_click(right_click).perform()


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
        data = browser.find_elements_by_css_selector('rect.highcharts-point')
        data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label')]
        # data from 24 to 33
        data = data[24:33]
        age_data = {}
        for i in data:
            age_data[i.split(',')[0].split('.')[1]] = i.split(',')[1].split('.')[0]
        path = "data/{}".format(day)
        if not os.path.exists(path):
            os.mkdir(path)
        with open("data/{}/NorthDakota.json".format(day), "w") as f:
            json.dump(age_data, f)

        browser.close()
        browser.quit()




    def get_az(self):
        url = "https://www.azdhs.gov/preparedness/epidemiology-disease-control/infectious-disease-epidemiology/covid-19/dashboards/index.php"
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)  # Get local session of firefox
        # https://public.tableau.com/vizql/w/DPHIdahoCOVID-19Dashboard_V2/v/Story1/viewData/sessions/D09BE74481DD4BE0952A3845F3AE1670-0:0/views/13810090252421852225_1824451516651397827?maxrows=200&viz=%7B%22worksheet%22%3A%22Age%20Groups%22%2C%22dashboard%22%3A%22Table%20Dashboard%20(w%2Fdeath%20place)%22%2C%22storyboard%22%3A%22Story%201%22%2C%22story-point-id%22%3A9%7D
        browser.get(url)
        r = requests.get(url)
        #day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        browser.implicitly_wait(5)
        browser.find_element_by_css_selector('i.fas.fa-chart-bar.fa-stack-1x.fa-inverse').click()
        ## TODO: extract the img
        ## TODO: extract update day img
        browser.close()
        browser.quit()




    def get_ok(self):
        ## just have the percentage
        url = "https://looker-dashboards.ok.gov/embed/dashboards/42"
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)

        data = browser.find_elements_by_css_selector('tspan.highcharts-data-label')
        data = [e.text for e in data if e.text and e.text[0] >= '0' and e.text[0] <= '9']
        #total_pdf = browser.find_element_by_xpath('//*[@id="dashboard"]/div/div[2]/div/div/div/div/div[2]/div[2]/div/lk-dashboard-text/div/div/div[4]/div/p/a')
        total_pdf = browser.find_element_by_xpath(
            '//*[@id="dashboard"]/div/div[2]/div/div/div/div/div[2]/div[2]/div/lk-dashboard-text/div/div/div[4]/div/p/a').click()
            #.get_attribute(
            #'href')
        browser.find_element_by_xpath('//*[@id="dashboard"]/div/div[2]/div/div/div/div/div[2]/div/div/lk-dashboard-text/div/div/div[4]/div/p[1]/a').get_attribute('href')
        ## TODO: find the element to get the pdf_url
        pdf_url = 'https://storage.googleapis.com/ok-covid-gcs-public-download/covid19_cases_summary.pdf'

        r = requests.get(pdf_url).headers['Last-Modified']
        day = parsedate(r).strftime('%Y-%m-%d')
        path = "pdfs/oklandoma"
        if not os.path.exists(path):
            os.mkdir(path)
        with open("pdfs/oklandoma/" + day + ".pdf", "wb") as f:
            response = requests.get(pdf_url)
            f.write(response.content)
        ## TODO:extract total death data from the pdf, use this date as the day
        doc = fitz.Document(
            "pdfs/oklandoma/{}.pdf".format(day)
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
        with open("data/{}/oklandoma.json".format(day), "w") as f:
            json.dump(age_data, f)

        browser.close()
        browser.quit()

    def get_ka(self):
        # don't know the day
        browser = webdriver.Chrome(executable_path=chromed)
        url = "https://www.coronavirus.kdheks.gov/160/COVID-19-in-Kansas"
        url = "https://public.tableau.com/views/COVID-19TableauVersion2/DeathSummary?%3Aembed=y&%3AshowVizHome=no&%3Ahost_url=https%3A%2F%2Fpublic.tableau.com%2F&%3Aembed_code_version=3&%3Atabs=no&%3Atoolbar=yes&%3Aanimate_transition=yes&%3Adisplay_static_image=no&%3Adisplay_spinner=no&%3Adisplay_overlay=yes&%3Adisplay_count=yes&%3AloadOrderID=0"
        browser.get(url)
        # get day
        data = browser.find_elements_by_css_selector('span')
        data = [e for e in data if e.get_attribute("style")]

        age_date = {}
        age_data['35-44'] = 5
        age_data['45-54'] = 5
        age_data['55-64'] = 24
        age_date['65-74'] = 29
        age_date['75-84'] = 35
        age_date['85+'] = 66

        path = "data/{}".format(day)
        if not os.path.exists(path):
            os.mkdir(path)
        with open("data/{}/kansas.json".format(day), "w") as f:
            json.dump(age_data, f)


        browser.close()
        browser.quit()

    def get_nc(self):
        ## figure
        r = requests.get(
            "https://covid19.ncdhhs.gov/dashboard#by-age"
        )
        ## the reports are always published 1 day later (possibly!)
        data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        ## TODO: check if we need to update
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get("https://covid19.ncdhhs.gov/dashboard#by-age")
        day = browser.find_element_by_xpath('//*[@id="node-103"]/div/div[1]/div/div/p[1]').text.split('.,')[-1]
        day = parsedate(day).strftime("%Y-%m-%d")
        total = int(browser.find_element_by_xpath('//*[@id="node-103"]/div/div[1]/div/div/table/tbody/tr/td[2]').text)
        data = browser.find_element_by_xpath('//*[@id="ui-accordion-ui-id-1-panel-3"]/section/p[5]/img')
        data_web = data.get_attribute("src")
        path = "figures/NorthCarolina"
        if not os.path.exists(path):
            os.mkdir(path)
        response = requests.get(data_web)
        with open("figures/NorthCarolina/{}.png".format(data_date), "wb") as f:
            for data in response.iter_content(128):
                f.write(data)
        path = "data/{}".format(data_date)
        data = {}
        data['total'] = total
        if not os.path.exists(path):
            os.mkdir(path)
        with open("data/{}/NorthCarolina.json".format(data_date), "w") as f:
            json.dump(data,f)

        browser.close()
        browser.quit()

    def get_sc(self):
        url = "https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19"
        r = requests.get(url)
        data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")

        browser = webdriver.Chrome(executable_path=chromed)
        # in reported deaths, find the proportion and the url
        browser.get('https://public.tableau.com/views/EpiProfile/DemoStory?:embed=y&:showVizHome=no&:host_url=https%3A%2F%2Fpublic.tableau.com%2F&:embed_code_version=3&:tabs=no&:toolbar=yes&:animate_transition=yes&:display_static_image=no&:display_spinner=no&:display_overlay=yes&:display_count=yes&publish=yes&:loadOrderID=0')
        #browser.get('https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19')
        browser.find_element_by_css_selector('span.tabFlipboardNavNext.tab-widget.ArrowLarge').click()
        data = browser.find_element_by_xpath('//*[@id="title10223277918472557951_1535545040336048298"]/div[1]/div/span/div/span')
        total_idx = re.search( r'(=.*)', data.text).span()
        total = data.text[total_idx[0] + 1 : total_idx[1] - 2]
        total = int(total)
        # get the percentage
        #dd = browser.find_element_by_xpath('//*[@id="view10223277918472557951_1535545040336048298"]')
        #ActionChains(browser).move_to_element(dd).move_by_offset(600, 270).click().release().perform()

        #JS = 'return document.getElementsByClassName("tvScrollContainer tvmodeRectSelect")[0].toDataURL("image/png");'
        # 执行 JS 代码并拿到图片 base64 数据
        #im_info = browser.execute_script('JS')  # 执行js文件得到带图片信息的图片数据
        #im_base64 = im_info.split(',')[1]  # 拿到base64编码的图片信息
        #im_bytes = base64.b64decode(im_base64)  # 转为bytes类型
        #path = "figures/SouthCarolina"
        #if not os.path.exists(path):
        #    os.mkdir(path)
        #with open("figures/SouthCarolina/{}.png".format(data_date), "wb") as f:
        #    f.write(im_bytes)

        import execjs
        # 执行本地的js
        '''
        def get_js():
            # f = open("D:/WorkSpace/MyWorkSpace/jsdemo/js/des_rsa.js",'r',encoding='UTF-8')
            f = open("https://public.tableau.com/sidecar/scripts.js", 'r', encoding='UTF-8')
            line = f.readline()
            htmlstr = ''
            while line:
                htmlstr = htmlstr + line
                line = f.readline()
            return htmlstr

        jsstr = get_js()
        '''
        age_data = {}
        age_data['21-30'] = round(0.006*total)
        age_data['31-40'] = round(0.003 * total)
        age_data['41-50'] = round(0.028 * total)
        age_data['51-60'] = round(0.082 * total)
        age_data['61-70'] = round(0.22 * total)
        age_data['71-80'] = round(0.304 * total)
        age_data['81+'] = round(0.358 * total)
        path = "data/{}".format(day)
        if not os.path.exists(path):
            os.mkdir(path)
        with open("data/{}/SouthCarolina.json".format(day), "w") as f:
            json.dump(age_data, f)

        browser.close()
        browser.quit()

    def get_mppi(self):

        ##  TODO:add date time, not the web updated time, not the same
        r = requests.get("https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19")
        ## the reports are always published 1 day later (possibly!)
        #data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")

        browser = webdriver.Chrome(executable_path=chromed)
        browser.get("https://msdh.ms.gov/msdhsite/_static/14,0,420.html#Mississippi")

        day = " ".join(['2020', " ".join(browser.find_element_by_xpath('//*[@id="article"]/div/h3[1]').text.split()[-2:])])
        day = parsedate(day).strftime('%Y-%m-%d')
        data_web = browser.find_element_by_xpath('//*[@id="article"]/div/p[14]/img').get_attribute("src")
        path = "figures/Mississippi"
        if not os.path.exists(path):
            os.mkdir(path)
        response = requests.get(data_web)
        with open("figures/Mississippi/{}.png".format(day), "wb") as f:
            for data in response.iter_content(128):
                f.write(data)
        browser.close()
        browser.quit()

    def get_mour(self):

        url = "https://health.mo.gov/living/healthcondiseases/communicable/novel-coronavirus/results.php"
        #r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        #day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        day = browser.find_element_by_xpath('//*[@id="main-content"]/p[5]').text.split(",")[-1]
        day = parsedate(" ".join(['2020',day])).strftime('%Y-%m-%d')
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
        browser.close()
        browser.quit()

    def get_lowa(self):
        url = "https://coronavirus.iowa.gov/pages/case-counts"

        r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        #day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.implicitly_wait(5)
        ActionChains(browser).move_by_offset(30,282).context_click().perform()

        age_data = {}
        total = 318
        day = '2020-05-13'
        age_data['18-40'] = 0.0221 * total
        age_data['41-60'] = 0.1041 * total
        age_data['61-80'] = 0.4069 * total
        age_data['>80'] = 0.4669 * total
        path = "data/{}".format(day)
        if not os.path.exists(path):
            os.mkdir(path)
        with open("data/{}/lowa.json".format(day), "w") as f:
            json.dump(age_data, f)
        browser.close()
        browser.quit()

    def get_kdph(self):
        url = "https://kygeonet.maps.arcgis.com/apps/opsdashboard/index.html#/543ac64bc40445918cf8bc34dc40e334"
        r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        #day = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")
        # 5 pm BST update
        day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")

        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        ## //*[@id="ember57"]/div/div/svg/g[7]/g/g/g[1]
        data = browser.find_elements_by_css_selector('g.amcharts-graph-column')
        # data contain the cases and deaths
        data = [e.get_attribute('aria-label') for e in data if e.get_attribute('aria-label')]
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

        browser.close()
        browser.quit()

    def get_del(self):
        ## TODO: get the update day
        url = "https://myhealthycommunity.dhss.delaware.gov/about/acceptable-use"
        #r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        #day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.find_element_by_xpath('//*[@id="accept"]').click()
        browser.find_element_by_xpath('/html/body/main/div/div/div[2]/section/form/button').click()
        day = browser.find_element_by_xpath('//*[@id="outcomes"]/div/div[2]/div[1]/div/div[1]/div/span').text.split(':')[1]
        day = parsedate(day).strftime("%Y-%m-%d")
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
        browser.close()
        browser.quit()

    def get_ver(self):
        url = "https://vcgi.maps.arcgis.com/apps/opsdashboard/index.html#/6128a0bc9ae14e98a686b635001ef7a7"
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        #r = requests.get(url).headers['Last-Modified'] : 4.28
        day = browser.find_element_by_xpath('//*[@id="ember78"]/div/p/strong').text.split(',')[0]
        day = parsedate(day).strftime("%Y-%m-%d")
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
        browser.close()
        browser.quit()






if __name__ == "__main__":
    AgeExtractor().get_lo()
    AgeExtractor().get_nc()
    #AgeExtractor().get_sc()
    AgeExtractor().get_mppi()