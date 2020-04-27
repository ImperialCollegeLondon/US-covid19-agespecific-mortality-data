import os
import argparse
from dateutil.parser import parse

import fitz
import pandas as pd

parser = argparse.ArgumentParser()

parser.add_argument('--date', type=str, required=True, help='Date of data publication to process')
parser.add_argument('--death-start', type=int, required=True, help='Page on which the death data starts')
parser.add_argument('--death-end', type=int, required=True, help='Page on which the death data ends')
# parser.add_argument('--cases-start', type=int, required=True, help='Page on which the cases data starts')
# parser.add_argument('--cases-end', type=int, required=True, help='Page on which the cases data ends')


args = parser.parse_args()

doc = fitz.Document(f"pdfs/{args.date}/florida_daily_report.pdf")

# Parse the death data.

table = []

# Loop over deaths pages.
for page in range(args.death_start, args.death_end):
    id_locs = []
    ids = []

    last_digit_age = True

    lines = doc.getPageText(page).splitlines()

    # Loop over the lines to find the locations of the starts of the table lines.
    for loc, line in enumerate(lines):
        # case Id column are integers.
        if line.isdigit():
            # Age is also a digit, ignore every other digit.
            if last_digit_age:
                id_locs.append(loc)
                ids.append(int(line))
                last_digit_age = False
            else:
                last_digit_age = True

    id_locs.append(len(lines))

    # Loop over the lines in the table and extract the data.
    for id_start, id_end in zip(id_locs[:-1], id_locs[1:]):
        values = lines[id_start:id_end]
        # Remove the last column if it is the "Deaths verified today" column.
        if values[-1] == 'Yes':
            values = values[:-1]
        # Clip out the desired columns.
        values = values[:5] + values[-2:]
        table.append(values)

columns = ['death', 'county', 'age', 'gender', 'travel_related', 'juristiction', 'date_case_counted']

# Make a pandas table.
pd_table = pd.DataFrame(table)
pd_table.columns = columns

# Dump to csv.
os.makedirs(f"data/{args.date}/florida/", exist_ok=True)
pd_table.to_csv(f"data/{args.date}/florida/line_data_deaths.csv", index=False)

# # Sometimes date is missing. 
# def is_date(string, fuzzy=False):
#     """
#     Return whether the string can be interpreted as a date.

#     :param string: str, string to check for date
#     :param fuzzy: bool, ignore unknown tokens in string if True
#     """
#     try: 
#         parse(string, fuzzy=fuzzy)
#         return True

#     except ValueError:
#         return False

# # Loop over cases pages.
# table = []

# for page in range(args.cases_start, args.cases_end):
#     id_locs = []
#     ids = []

#     last_digit_age = True

#     lines = doc.getPageText(page).splitlines()

#     # Loop over the lines to find the locations of the starts of the table lines.
#     for loc, line in enumerate(lines):
#         # case Id column are integers.
#         if line.isdigit():
#             # Age is also a digit, ignore every other digit.
#             if last_digit_age:
#                 id_locs.append(loc)
#                 ids.append(int(line))
#                 last_digit_age = False
#             else:
#                 last_digit_age = True

#     # Loop over the lines in the table and extract the data.
#     for id_start, id_end in zip(id_locs[:-1], id_locs[1:]):
#         values = lines[id_start:id_end]
#         # Remove the last column if it is the "Deaths verified today" column.
#         if values[-1] == 'Yes':
#             values = values[:-1]
#         # Clip out the desired columns.
#         values = values[:5] + values[-2:]
#         table.append(values)

# columns = ['death', 'county', 'age', 'gender', 'travel_related', 'juristiction', 'date_case_counted']

# # Make a pandas table.
# pd_table = pd.DataFrame(table)
# pd_table.columns = columns

# # Dump to csv.
# os.makedirs(f"data/{args.date}/florida/", exist_ok=True)
# pd_table.to_csv(f"data/{args.date}/florida/line_data_cases.csv", index=False)