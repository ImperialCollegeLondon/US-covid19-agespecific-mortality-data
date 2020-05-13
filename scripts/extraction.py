# need install selenium
from selenium import webdriver
from selenium.common.exceptions import NoSuchElementException
import time
import re
import os
from datetime import date
import json
import requests
from dateutil.parser import parse as parsedate


class AgeExtractor:
    def __init__(self):
        self.today = date.today().strftime("%Y-%m-%d")
    def get_lo(self):
        ##  TODO:
        #existing_assets = list(map(basename, glob("data/louisiana/*.json")))
        #pa=re.compile(r'\w+')
        url = "https://health.mo.gov/living/healthcondiseases/communicable/novel-coronavirus/results.php"
        r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")

        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed) # Get local session of firefox
        #browser.get("http://ldh.la.gov/coronavirus/") # Load page
        browser.get("https://www.arcgis.com/apps/opsdashboard/index.html#/69b726e2b82e408f89c3a54f96e8f776")
        time.sleep(20) # Let the page load
        # find the update day
        #find_day = browser.find_element_by_xpath('//*[@id="ember159"]')
        #day_idx = re.search( r':.*/2020', find_day.text).span()
        #day = find_day.text[day_idx[0]+1 : day_idx[1]]
        #aa = day.split('/')
        #day = "-".join([aa[2], aa[0], aa[1]])
        #if day + '.json' not in existing_assets:
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
            #age_data["< 18"] = data[1].split()[-1]
            #age_data["18 - 29"] = data[2].split()[-1]
            #age_data["30 - 39"] = data[3].split()[-1]
            #age_data["40 - 49"] = data[4].split()[-1]
            #age_data["50 - 59"] = data[5].split()[-1]
            #age_data["60 - 69"] = data[6].split()[-1]
            #age_data["70+"] = data[7].split()[-1]
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

    def get_ld(self):
        ##  TODO:
        # existing_assets = list(map(basename, glob("data/louisiana/*.json")))
        # pa=re.compile(r'\w+')
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed)  # Get local session of firefox
        # https://public.tableau.com/vizql/w/DPHIdahoCOVID-19Dashboard_V2/v/Story1/viewData/sessions/D09BE74481DD4BE0952A3845F3AE1670-0:0/views/13810090252421852225_1824451516651397827?maxrows=200&viz=%7B%22worksheet%22%3A%22Age%20Groups%22%2C%22dashboard%22%3A%22Table%20Dashboard%20(w%2Fdeath%20place)%22%2C%22storyboard%22%3A%22Story%201%22%2C%22story-point-id%22%3A9%7D
        browser.get("https://public.tableau.com/profile/idaho.division.of.public.health#!/vizhome/DPHIdahoCOVID-19Dashboard_V2/Story1")
        request = requests.get('https://public.tableau.com/vizql/w/DPHIdahoCOVID-19Dashboard_V2/v/Story1/viewData/sessions/D09BE74481DD4BE0952A3845F3AE1670-0:0/views/13810090252421852225_1824451516651397827?maxrows=200&viz=%7B%22worksheet%22%3A%22Age%20Groups%22%2C%22dashboard%22%3A%22Table%20Dashboard%20(w%2Fdeath%20place)%22%2C%22storyboard%22%3A%22Story%201%22%2C%22story-point-id%22%3A9%7D')
        request.text

        # if day + '.json' not in existing_assets:
        try:
            ## get the bottom to select the figure
            board = browser.find_elements_by_css_selector('div.tabScrollerContentWindow.scrollable')
            data = [e.get_attribute('aria-label') for e in board if
                    e.get_attribute('aria-label') and 'Deaths' in e.get_attribute('aria-label')]
            age_data = {}

            path = "data/{}".format(day)
            if not os.path.exists(path):
                os.mkdir(path)
            with open("data/{}/louisiana.json".format(day), "w") as f:
                json.dump(age_data, f)


        browser.close()
        browser.quit()
    def get_ok(self):
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed) # Get local session of firefox
        #browser.get("http://ldh.la.gov/coronavirus/") # Load page
        browser.get("https://looker-dashboards.ok.gov/embed/dashboards/42")
        browser.close()
        browser.quit()

    def get_ko(self):
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get("https://www.coronavirus.kdheks.gov/160/COVID-19-in-Kansas")
        board = browser.find_element_by_css_selector("div.tab-custom-button")

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
        data = browser.find_element_by_xpath('//*[@id="ui-accordion-ui-id-1-panel-3"]/section/p[5]/img')
        data_web = data.get_attribute("src")
        path = "figures/NorthCarolina"
        if not os.path.exists(path):
            os.mkdir(path)
        response = requests.get(data_web)
        with open("figures/NorthCarolina/{}.png".format(data_date), "wb") as f:
            for data in response.iter_content(128):
                f.write(data)
        browser.close()
        browser.quit()

    def get_sc(self):
        r = requests.get("https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19")
        ## the reports are always published 1 day later (possibly!)
        data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")

        browser = webdriver.Chrome(executable_path=chromed)
        # in reported deaths, find the proportion and the url
        browser.get('https://public.tableau.com/views/EpiProfile/DemoStory?:embed=y&:showVizHome=no&:host_url=https%3A%2F%2Fpublic.tableau.com%2F&:embed_code_version=3&:tabs=no&:toolbar=yes&:animate_transition=yes&:display_static_image=no&:display_spinner=no&:display_overlay=yes&:display_count=yes&publish=yes&:loadOrderID=0')
        #browser.get('https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19')
        browser.find_element_by_css_selector('span.tabFlipboardNavNext.tab-widget.ArrowLarge').click()
        data = browser.find_element_by_xpath('//*[@id="title10223277918472557951_1535545040336048298"]/div[1]/div/span/div/span')
        total_idx = re.search( r'(=.*)', data.text).span()
        total = data.text[total_idx[0] + 1 : total_idx[1] - 2]
        # get the percentage
        from selenium.webdriver.common.action_chains import ActionChains
        dd = browser.find_element_by_xpath('//*[@id="view10223277918472557951_1535545040336048298"]')
        ActionChains(browser).move_to_element(dd).move_by_offset(600, 270).click().release().perform()

        JS = 'return document.getElementsByClassName("tvScrollContainer tvmodeRectSelect")[0].toDataURL("image/png");'
        # 执行 JS 代码并拿到图片 base64 数据
        im_info = browser.execute_script('JS')  # 执行js文件得到带图片信息的图片数据
        im_base64 = im_info.split(',')[1]  # 拿到base64编码的图片信息
        im_bytes = base64.b64decode(im_base64)  # 转为bytes类型
        path = "figures/SouthCarolina"
        if not os.path.exists(path):
            os.mkdir(path)
        with open("figures/SouthCarolina/{}.png".format(data_date), "wb") as f:
            f.write(im_bytes)

        import execjs
        # 执行本地的js

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


        browser.close()
        browser.quit()

    def get_mppi(self):
        r = requests.get("https://www.scdhec.gov/infectious-diseases/viruses/coronavirus-disease-2019-covid-19/sc-demographic-data-covid-19")
        ## the reports are always published 1 day later (possibly!)
        data_date = parsedate(r.headers["Last-Modified"]).strftime("%Y-%m-%d")

        browser = webdriver.Chrome(executable_path=chromed)

        browser.get("https://msdh.ms.gov/msdhsite/_static/14,0,420.html#Mississippi")
        data_web = browser.find_element_by_xpath('//*[@id="article"]/div/p[14]/img').get_attribute("src")
        path = "figures/Mississippi"
        if not os.path.exists(path):
            os.mkdir(path)
        response = requests.get(data_web)
        with open("figures/Mississippi/{}.png".format(data_date), "wb") as f:
            for data in response.iter_content(128):
                f.write(data)
        browser.close()
        browser.quit()

    def get_mour(self):

        url = "https://health.mo.gov/living/healthcondiseases/communicable/novel-coronavirus/results.php"
        r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
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
        day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.close()
        browser.quit()

    def get_kdph(self):
        url = "https://kygeonet.maps.arcgis.com/apps/opsdashboard/index.html#/543ac64bc40445918cf8bc34dc40e334"
        r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        ## //*[@id="ember57"]/div/div/svg/g[7]/g/g/g[1]
        browser.close()
        browser.quit()

    def get_del(self):
        url = "https://myhealthycommunity.dhss.delaware.gov/locations/state"
        r = requests.get(url)
        ## the reports are always published 1 day later (possibly!)
        day = parsedate(r.headers["Date"]).strftime("%Y-%m-%d")
        browser = webdriver.Chrome(executable_path=chromed)
        browser.get(url)
        browser.find_element_by_xpath('//*[@id="accept"]').click()
        browser.find_element_by_xpath('/html/body/main/div/div/div[2]/section/form/button').click()
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


if __name__ == "__main__":
    AgeExtractor().get_lo()
    AgeExtractor().get_nc()
    #AgeExtractor().get_sc()
    AgeExtractor().get_mppi()