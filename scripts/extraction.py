
from selenium import webdriver
import time
import re
import os
from datetime import date
import json

class AgeExtractor:
    def __init__(self):
        self.today = date.today().strftime("%Y-%m-%d")
    def find_data(self):
        ##  TODO:
        #existing_assets = list(map(basename, glob("data/louisiana/*.json")))
        #pa=re.compile(r'\w+')
        chromed = "D:\chromedriver.exe"
        browser = webdriver.Chrome(executable_path=chromed) # Get local session of firefox
        #browser.get("http://ldh.la.gov/coronavirus/") # Load page
        browser.get("https://www.arcgis.com/apps/opsdashboard/index.html#/69b726e2b82e408f89c3a54f96e8f776")
        time.sleep(20) # Let the page load
        # find the update day
        find_day = browser.find_element_by_xpath('//*[@id="ember159"]')
        day_idx = re.search( r':.*/2020', find_day.text).span()
        day = find_day.text[day_idx[0]+1 : day_idx[1]]
        aa = day.split('/')
        day = "-".join([aa[2], aa[0], aa[1]])
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


if __name__ == "__main__":
    AgeExtractor().find_data()