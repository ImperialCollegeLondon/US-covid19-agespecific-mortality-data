. ./config.sh
# states="Alabama Alaska Arizona Arkansas California Colorado Connecticut Delaware Florida Georgia Hawaii Idaho Illinois Indiana Iowa Kansas Kentucky Louisiana Maine Maryland Massachusetts Michigan Minnesota Mississippi Missouri Montana Nebraska Nevada New_Hampshire New_Jersey New_Mexico New_York North_Carolina North_Dakota Ohio Oklahoma Oregon Pennsylvania Rhode_Island South_Carolina South_Dakota Tennessee Texas Utah Vermont Virginia Washington West_Virginia Wisconsin Wyoming"
# countries="US GB IT DE ES FR"

mkdir -p pdfs/${date}/
# mkdir -p ../data/GoogleMobility/data/

curl -s -o pdfs/${date}/florida_daily_report.pdf https://floridadisaster.org/globalassets/covid19/dailies/covid-19-data---daily-report-${florida_date}.pdf