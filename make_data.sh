. ./config.sh
source venv/bin/activate

# Make output dir
mkdir -p data/${date}

# Florida
python scripts/florida.py --date ${date} --death-start ${florida_death_page_start} --death-end ${florida_death_page_end} # --cases-start ${florida_cases_page_start} --cases-end ${florida_cases_page_end}

cd data
rm -rf latest
cp -r ${date} latest
