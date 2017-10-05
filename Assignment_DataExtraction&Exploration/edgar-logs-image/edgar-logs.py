# IN
# Import the modules we use.
import datetime
import io
import numpy as np
import os
import pandas as pd
import re
import requests
import sys
import zipfile

# Import the configuration.
import edgar_logs_config

# Create logfile.
logfile = open("edgar-logs-logfile.txt", "w")
def log_entry(s):
    #print('Date now: %s' % datetime.datetime.now())

    timestamp = '[%s] ' % datetime.datetime.now()
    log_line = timestamp + str(s)
    logfile.write(log_line)
    logfile.flush()

    # Also write to standard output as a convenience.
    print(log_line)

# IN
# User provided inputs.
# year = "2003"
year = edgar_logs_config.year
if year is None or year == "":
    log_entry("Required parameter 'year' is missing: check the edgar_logs_config.py file")
    sys.exit()

# Useful constants.
site = "https://www.sec.gov/data/edgar-log-file-data-set.html"
log_entry("Using base site URL: " + site)

link = "https://www.sec.gov/files/edgar{year}.html".format(year=year)
log_entry("Looking for link: " + link)

# IN
response = requests.get(site)

# Exit when the page can't be retrieved.
if response.status_code >= 400:
    log_entry("Unexpected status code: " + response.status_code)
    sys.exit()

content = response.content
#print(content[0:200])

# Check whether the given year appears on the EDGAR log page and exit if it doesn't.
check_text = "files/edgar{year}.html".format(year=year)
if str(content).find(check_text) != -1:
    log_entry("Year " + str(year) + " is valid")
else:
    log_entry("Year " + str(year) + " is not valid")
    sys.exit()

# IN
# Months in the year and the quarter to which a month belongs are constants.
months_dict = [{"month":"01", "quarter":1}, {"month":"02", "quarter":1}, {"month":"03", "quarter":1},
              {"month":"04", "quarter":2}, {"month":"05", "quarter":2}, {"month":"06", "quarter":2},
              {"month":"07", "quarter":3}, {"month":"08", "quarter":3}, {"month":"09", "quarter":3},
              {"month":"10", "quarter":4}, {"month":"11", "quarter":4}, {"month":"12", "quarter":4}]

filenames = []

for m in months_dict:
    url = "http://www.sec.gov/dera/data/Public-EDGAR-log-file-data/{year}/Qtr{quarter}/log{year}{month}01.zip".format(
        year=year, month=m['month'], quarter = str(m['quarter']))
    filenames.append({'url':url,'filename':"log" + str(year) + m['month'] + "01.zip"})

log_entry("Formed filenames: " + str(filenames))


# IN
column_names = ['ip','date','time','zone','cik','accession','doc','code','filesize','idx',
         'norefer','noagent','find','crawler','browser']

column_types = {'ip':np.object, 'date':np.object, 'time':np.object, 'zone':np.object,
                'cik':np.object, 'accession':np.object, 'doc':np.object, 'code':np.object,
                'filesize':np.object, 'idx':np.object, 'norefer':np.int32, 'noagent':np.int32,
                'find':np.object, 'crawler':np.object, 'browser':np.object}

# CIK, filesize, code, idx, find and crawler should be ints, but they have missing values.

def process_monthly_file(item):
    url = item['url']
    zip_filename = item['filename']
    csv_filename = zip_filename.replace('zip', 'csv')

    log_entry('Processing: ' + zip_filename)

    # Download and save the ZIP file (if we haven't already).
    if not os.path.isfile(csv_filename):
        log_entry('Downloading: ' + zip_filename)
        r = requests.get(url)
        z = zipfile.ZipFile(io.BytesIO(r.content))
        z.extractall()
    else:
        log_entry('Already downloaded: ' + csv_filename)

    # Read the data into a dataframe and return it.
    # Here we are using a TextFileReader, which is iterable with chunks of 1000 rows.
    tp = pd.read_csv(csv_filename, header=0, names=column_names, dtype=column_types, iterator=True, chunksize=1000)
    df = pd.concat(tp, ignore_index=True)

    # Missing values in these columns are set to 0.0 and then converted to an int.
    convert_columns = ['cik', 'code', 'filesize', 'idx', 'find', 'crawler']
    for c in convert_columns:
        log_entry('Replacing missing ' + c + ' values with 0 and converting to integer')
        df[c].fillna(0.0, inplace=True)
        df[c] = df[c].astype(float)
        df[c] = df[c].astype(int)

    # Missing values in browser are set to ''.
    log_entry('Replacing missing browsers with empty string')
    df['browser'].fillna('', inplace=True)

    return df


# IN
#dataframes = []
for f in filenames:
    monthly_df = process_monthly_file(f)
    print(monthly_df.head(5))
    print(monthly_df.info())
    print(monthly_df.shape)

    if not monthly_df.empty:
        log_entry("Summary stats for filesize: " + monthly_df['date'][0])
        log_entry('\n' + str(monthly_df['filesize'].describe(include=[np.number])))

        log_entry("Summary stats for categoricals: IP, time, accession, doc, browser: " + monthly_df['date'][0])
        log_entry('\n' + str(monthly_df[['ip', 'time', 'accession', 'doc', 'browser']].describe(include=[object])))

        log_entry("Value counts for browser: " + monthly_df['date'][0])
        log_entry('\n' + str(monthly_df['browser'].value_counts()))
    else:
        log_entry("dataframe from file " + str(f) + " was empty")

    #dataframes.append(monthly_df)


# Clean up the logfile.
logfile.close()
