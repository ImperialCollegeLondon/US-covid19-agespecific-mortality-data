import requests
import re
import json
from os.path import join
from glob import glob

print("Extracting New Mexico")
# Gather all available URLs
url = "https://cv.nmhealth.org/newsroom/"
r = requests.get(url)
text = r.text
urls = []
for x in re.split(r'<a href=', text):
    if "/new-mexico-covid-19-update-" in x:
        link = (re.split(r'>', x))[0]
        link = (re.split(r'"', link))[1]
        urls.append(link)
urls = list(dict.fromkeys(urls))

# gather data that already exists into a list of dates
processed_dates = glob("data/nm/*.json")

for x in urls:
    # get current date
    date = x.partition("org/")[2].partition("/new")[0].replace('/','-')
    # check if this is already processed
    if join("data/nm", date + ".json") in processed_dates:
        continue
    
    print("Processing new data on ", date)
    m = requests.get(x)
    mtext = m.text
    deaths = mtext.partition("related to COVID-19:")[2].partition("The number of deaths")[0]
    x20 = deaths.count('20s')
    x30 = deaths.count('30s')
    x40 = deaths.count('40s')
    x50 = deaths.count('50s')
    x60 = deaths.count('60s')
    x70 = deaths.count('70s')
    x80 = deaths.count('80s') + deaths.count('90s') + deaths.count('100s')
    
    data = {"0-19 years": "0", "20-29 years": "0", "30-39 years": "0", "40-49 years": "0", "50-59 years": "0", "60-69 years": "0", "70-79 years": "0", "80+ years": "0"}

    if x20>0:
        data["20-29 years"] = x20
    if x30>0:
        data["30-39 years"] = x30
    if x40>0:
        data["40-49 years"] = x40
    if x50>0:
        data["50-59 years"] = x50
    if x60>0:
        data["60-69 years"] = x60
    if x70>0:
        data["70-79 years"] = x70
    if x80>0:
        data["80+ years"] = x80
        
    if not "remains at" in mtext:
        data["0-19 years"] = "0"

    cum_deaths = mtext.partition("The number of deaths of New Mexico residents related to COVID-19 remains at ")[2].partition(".")[0]
    cum_deaths_new = mtext.partition("The number of deaths of New Mexico residents related to COVID-19 is now at ")[2].partition(".")[0]
        
    if (cum_deaths_new > cum_deaths) and (urls.index(x) < len(urls)-1):
            y = urls[urls.index(x) + 1]
            n = requests.get(y)
            ntext = n.text
            cum_deaths_old1 = ntext.partition("The number of deaths of New Mexico residents related to COVID-19 remains at ")[2].partition(".")[0]
            cum_deaths_old2 = ntext.partition("The number of deaths of New Mexico residents related to COVID-19 is now at ")[2].partition(".")[0]
            daily_deaths = int(cum_deaths_new) - int(max(cum_deaths_old1, cum_deaths_old2))
            x0 = daily_deaths - (x20 + x30 + x40 + x50 + x60 + x70 +x80)
            data["0-19 years"] = x0


    with open(join("data/nm", "{}.json".format(date)), 'a') as outfile:
        json.dump(data, outfile)

print("New Mexico Completed")