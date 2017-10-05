# IN
# Import the modules we use.
from bs4 import BeautifulSoup
from bs4 import SoupStrainer
import datetime
import numpy as np
import pandas as pd
import re
import requests
import sys

# Import the configuration file.
import edgar_config


# Create logfile.
logfile = open("edgar-logfile.txt", "w")
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
#cik = "51143"
#accession = "0000051143-13-000007"
cik = edgar_config.cik
accession = edgar_config.accession
filings = ["10-Q", "10-K"]

if cik is None or cik == "":
    log_entry("Required parameter 'cik' is missing: check the edgar_config.py file")
    sys.exit()

if accession is None or accession == "":
    log_entry("Required parameter 'accession' is missing: check the edgar_config.py file")
    sys.exit()

log_entry("Using CIK: " + str(cik))
log_entry("Using Accession number: " + str(accession))

# Useful constants.
site = "https://www.sec.gov"

# Derived values.
numeric_accession = re.sub("-", "", accession)
#print(numeric_accession)

url = "{site}/Archives/edgar/data/{CIK}/{numeric_accession}/{accession}-index.htm".format(
    site=site,
    CIK=cik,
    numeric_accession=numeric_accession,
    accession=accession)
log_entry("URL for index page: " + url)


# IN
response = requests.get(url)

# Exit when the page can't be retrieved.
if response.status_code >= 400:
    log_entry("Unexpected status code: " + response.status_code)
    sys.exit()


content = response.content
#print(content[0:200])


# IN
# Create the HTML parser - only search for table tags.
only_table_tags = SoupStrainer("table")
parser = BeautifulSoup(content, "html.parser", parse_only=only_table_tags)


# IN
# Find the table with a property
#     summary="Document Format Files"
document_format_files_table = parser.find_all("table", summary="Document Format Files")[0]
#print(document_format_files_table)


# IN
# For now, let's assume that the format stays roughly the same (columns stay in the same locations).
# A more robust method of parsing might be to convert the table to a dataframe.

rows = parser.find_all("tr")
#print(rows)

# Find the relative URL to the filing document.
document_relative_url = None
for r in rows:
    cells = parser.find_all("td")
    # print(cells)
    doc_type = cells[3].string
    # print(doc_type)
    if doc_type in filings:
        # print(cells[2])
        # print(cells[2].a)
        # print(cells[2].a.string)
        # print(cells[2].a['href'])
        document_relative_url = cells[2].a['href']

#print(document_relative_url)

# Create the full URL.
document_url = site + document_relative_url
#print(document_url)


# IN
# Get the filing document.
filing_response = requests.get(document_url)
#print(filing_response.status_code)

# TODO: error handling when the page can't be retrieved.

filing_content = filing_response.content
#print(filing_content[0:200])


# IN
# Create another HTML parser - only search for table tags.
filing_parser = BeautifulSoup(filing_content, "html.parser", parse_only=only_table_tags)
filing_tables = filing_parser.find_all("table")


# IN
# Have a look at the tables in the filing document.
#print(type(filing_tables))
#print(len(filing_tables))


# IN
# Function for saving data from a single table to a CSV file.
#
# filename - for saving the table as a CSV
# t - the table
#
# Removes any rows or columns that contain no data, and puts an empty string in cells that have no value.
# If there are rows with different numbers of columns, the table is considered to be inconsistent and
# won't be saved.
#
# If the table has no rows or no columns after stripping empty rows/columns, it won't be saved.
#
# TODO: find the most frequent number of columns for the rows and use all rows with that number of columns?
#
# returns True if the table was saved, otherwise False
def save_table_to_csv(filename, t):
    log_entry("filename = " + filename)

    column_count = 0
    row_count = 0
    columns = []
    column_counts = []
    consistent_table = True
    custom_headers = False

    rows = t.find_all("tr")
    row_count = len(rows)

    #a = np.array(column_counts)
    #counts = np.bincount(a)
    #print np.argmax(counts)

    # Find the shape of the table.
    for r in rows:
        # It's best if there's a header row with explicit column names.
        header_cells = r.find_all("th")
        if 0 == column_count:
            column_count = len(header_cells)

        for h in header_cells:
            log_entry("found header: " + h.string.strip())
            log_entry("found header: " + h.get_text().strip())
            columns.append(h.string.strip())
            custom_headers = True

        # If there are no header elements, just use a normal row.
        data_cells = r.find_all("td")
        row_columns = len(data_cells)
        if 0 == column_count:
            column_count = row_columns
        elif row_columns != column_count:
            # Inconsistent table, the number of columns isn't the same for all rows.
            log_entry("found " + str(row_columns) + " columns in this row instead of " + str(column_count))
            consistent_table = False
            break

    log_entry("consistent? " + str(consistent_table))
    log_entry("custom headers? " + str(custom_headers))
    log_entry("found " + str(row_count) + " rows")
    log_entry("found " + str(column_count) + " columns")

    if not consistent_table:
        log_entry("table is inconsistent, returning now")
        return False

    if len(columns) == 0:
        # found no column headers, so use integers
        columns = range(0, column_count)

    log_entry("columns are: " + str(columns))

    # Create the dataframe.
    data = pd.DataFrame(columns=columns, index=range(0, row_count))

    # Now insert the data into the dataframe.
    current_row = 0
    for r in rows:
        # Get each cell and put it into the dataframe.
        # Skip the header by only considering 'td' elements.
        # print(r)

        data_cells = r.find_all("td")
        current_column = 0
        for dc in data_cells:
            value = dc.get_text().strip()
            #print("data[{row}, {column}] = {value}".format(row=current_row, column=current_column, value=value))
            if value is not "":
                data.iat[current_row, current_column] = value
            current_column += 1

        current_row += 1

    #print(data)

    # Strip any columns that contain no data.
    data.dropna(axis=1, how='all', inplace=True)

    # Strip any rows that contain no data.
    data.dropna(axis=0, how='all', inplace=True)

    # If we didn't find custom column names, use consecutive integers.
    if not custom_headers:
        data.columns = range(0,len(data.columns))
        #print(data)

    # Replace any remaining NA values with empty strings.
    data.fillna(value="", axis=0, inplace=True)
    #print(data)

    # Check that the data frame has at least one row and one column.
    if data.shape[0] == 0:
        log_entry("data frame has no rows, returning")
        return False
    elif data.shape[1] == 0:
        log_entry("data frame has no columns, returning")
        return False

    # Write the dataframe to a CSV file and return.
    log_entry("Table is consistent and contains data, writing to: " + filename)
    data.to_csv(filename, encoding='utf-8')
    return True


# IN
# Iterate over the tables, saving them to CSV files.
index = 1
for t in filing_tables:
    filename = "table" + str(index) + ".csv"
    save_table_to_csv(filename, t)
    index += 1

# Clean up the logfile.
logfile.close()
