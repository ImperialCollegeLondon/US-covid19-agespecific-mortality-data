import os
import requests
import re
import json
from os.path import join
from glob import glob
import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager, ChromeType

# New Mexico Extraction
print("Extracting New Mexico")
# Gather all available URLs
url = "https://cv.nmhealth.org/newsroom/"
r = requests.get(url)
text = r.text
urls = []
for x in re.split(r"<a href=", text):
    if "/new-mexico-covid-19-update-" in x:
        link = (re.split(r">", x))[0]
        link = (re.split(r'"', link))[1]
        urls.append(link)
urls = list(dict.fromkeys(urls))

# gather data that already exists into a list of dates
processed_dates = glob("data/nm/*.json")

for x in urls[:-1]:
    # get current date
    date = x.partition("org/")[2].partition("/new")[0].replace("/", "-")
    # check if this is already processed
    if join("data/nm", date + ".json") in processed_dates:
        continue

    print("Processing new data on ", date)
    m = requests.get(x)
    mtext = m.text
    deaths = mtext.partition("related to COVID-19:")[2].partition(
        "The number of deaths"
    )[0]
    x20 = deaths.count("20s")
    x30 = deaths.count("30s")
    x40 = deaths.count("40s")
    x50 = deaths.count("50s")
    x60 = deaths.count("60s")
    x70 = deaths.count("70s")
    x80 = deaths.count("80s") + deaths.count("90s") + deaths.count("100s")

    data = {
        "0-19 years": "0",
        "20-29 years": "0",
        "30-39 years": "0",
        "40-49 years": "0",
        "50-59 years": "0",
        "60-69 years": "0",
        "70-79 years": "0",
        "80+ years": "0",
    }

    if x20 > 0:
        data["20-29 years"] = str(x20)
    if x30 > 0:
        data["30-39 years"] = str(x30)
    if x40 > 0:
        data["40-49 years"] = str(x40)
    if x50 > 0:
        data["50-59 years"] = str(x50)
    if x60 > 0:
        data["60-69 years"] = str(x60)
    if x70 > 0:
        data["70-79 years"] = str(x70)
    if x80 > 0:
        data["80+ years"] = str(x80)

    # if not "remains at" in mtext:
    #    data["0-19 years"] = "0"

    cum_deaths = mtext.partition(
        "The number of deaths of New Mexico residents related to COVID-19 remains at "
    )[2].partition(".")[0]
    cum_deaths_new = mtext.partition(
        "The number of deaths of New Mexico residents related to COVID-19 is now at "
    )[2].partition(".")[0]

    if (cum_deaths_new > cum_deaths) and (urls.index(x) < len(urls) - 1):
        y = urls[urls.index(x) + 1]
        n = requests.get(y)
        ntext = n.text
        cum_deaths_old1 = ntext.partition(
            "The number of deaths of New Mexico residents related to COVID-19 remains at "
        )[2].partition(".")[0]
        cum_deaths_old2 = ntext.partition(
            "The number of deaths of New Mexico residents related to COVID-19 is now at "
        )[2].partition(".")[0]
        daily_deaths = int(cum_deaths_new.replace(",", "")) - int(
            max(cum_deaths_old1, cum_deaths_old2).replace(",", "")
        )
        x0 = daily_deaths - (x20 + x30 + x40 + x50 + x60 + x70 + x80)
        data["0-19 years"] = str(x0)

    with open(join("data/nm", "{}.json".format(date)), "a") as outfile:
        json.dump(data, outfile)

print("New Mexico Completed")

from datetime import date, timedelta

# Pennsylvania extraction
print("Extracting Pennsylvania")
url = "https://padoh.maps.arcgis.com/apps/opsdashboard/index.html#/5662e22517b644ba874ca51fa7b61c94"
options = Options()
options.add_argument("headless")

day = (date.today() - timedelta(1)).strftime("%Y-%m-%d")
browser = webdriver.Chrome(
    ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install(), options=options
)
browser.get(url)
browser.implicitly_wait(15)  # Let the page load

if not os.access("data/{}/pennsylvania.json".format(day), os.F_OK):
    browser.implicitly_wait(15)
    browser.maximize_window()
    time.sleep(10)
    time.sleep(2)
    browser.implicitly_wait(1)
    browser.implicitly_wait(1)
    browser.switch_to.default_content()
    browser.switch_to.frame("ember46")
    browser.implicitly_wait(20)
    time.sleep(2)
    board = browser.find_elements_by_css_selector(
        "g.amcharts-graph-column"
    )  # .amcharts-graph-graphAuto1_1589372672251')
    data = [
        e.get_attribute("aria-label") for e in board if e.get_attribute("aria-label")
    ]

    age_data = {
        "20-29": 0,
        "30-39": 0,
        "40-49": 0,
        "50-59": 0,
        "60-69": 0,
        "70-79": 0,
        "80-89": 0,
        "90-99": 0,
        "100+": 0,
    }

    data = [x for x in data if "Count" in x]

    for i in range(len(data)):
        num = data[i].split()
        age_data[num[1]] = num[-1]

    path = "data/{}".format(day)
    if not os.path.exists(path):
        os.mkdir(path)
    with open("data/{}/pennsylvania.json".format(day), "w") as f:
        json.dump(age_data, f)
    print("\n------ Processed Pennsylvania {} ------\n".format(day))
    print(age_data)

else:
    print("Report for Pennsylvania {} already exists".format(day))

browser.switch_to.default_content()
browser.close()
browser.quit()

print("Pennsylvania Completed")
