import json
from os import system


def get_nyc(): 
    # system("curl 'https://api.github.com/repos/nychealth/coronavirus-data/commits?page=1&per_page=1000' > data/nyc/nyc_commits.json")
    with open('data/nyc/nyc_commits_2.json', "rb") as json_file: 
        data = json.load(json_file) 

    commit_hist = [(f["sha"], f["commit"]["author"]["date"][:10]) for f in data] 
    commit_hist.reverse() 
    commit_hist_latest = {} 
    # now only take the latest commit daily 
    for commit in commit_hist: 
        commit_hist_latest[commit[1]] = commit[0] 
    print(commit_hist_latest.keys()) 
    for date in commit_hist_latest.keys(): 
        system("wget --no-check-certificate -O data/nyc/nyc_{}.csv https://raw.githubusercontent.com/nychealth/coronavirus-data/{}/by-age.csv".format(date, commit_hist_latest[date])) 

if __name__ == "__main__":
    get_nyc()