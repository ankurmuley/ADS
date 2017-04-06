# Import the libraries we use.
library(RCurl)
library(xml2)
library(httr)
library(stringr)
#setwd("C:/Users/Admin/Documents/DataScience/Midterm")
source("config.R")
setwd("./data")

# Check that we have either a session cookie, or a username and password.
have_credentials = FALSE
login_required = TRUE
if (exists("session_cookie") && !is.na(session_cookie) && (nchar(session_cookie) > 1)) {
    print("have a session cookie!")
    login_required = FALSE
    have_credentials = TRUE
}

if (!have_credentials) {
    # No session cookie, so username and password are required.
    if (exists("login_username") && !is.na(login_username) && (nchar(login_username) > 1)) {
        print("have a login username!")
        if (exists("login_password") && !is.na(login_password) && (nchar(login_password) > 1)) {
            print("have a login password!")
            have_credentials = TRUE
        }
    }
}

if (!have_credentials) {
    print("don't have sufficient credentials to login")
}

if (login_required) {
    # Go to the login page.
    login_url <- "https://freddiemac.embs.com/FLoan/secure/auth.php"
    login_parameters <- list(username=login_username, password=login_password)
    login_response <- POST(login_url, body=login_parameters, encode='form')

    if (login_response$status_code != 200) {
        print("error occurred accepting the Terms and Conditions")
    }

    # httr will automatically send the session cookie with requests to the same domain.
    # But later on we don't know if the user provided a session cookie, so we always include it.
    session_cookie <- ""
    fm_cookies = cookies(login_response)
    for (i in nrow(fm_cookies)) {
        current_cookie_name = fm_cookies[i, 'name']
        if (current_cookie_name == 'PHPSESSID') {
            session_cookie <- fm_cookies[i, 'value']
            print(session_cookie)
        }
    }

    # Get past the terms and conditions page.
    terms_url <- "https://freddiemac.embs.com/FLoan/Data/download.php"
    terms_parameters <- list(accept="Yes", action="acceptTandC", acceptSubmit="Continue")
    terms_response <- POST(terms_url, body=terms_parameters, encode='form')

    if (terms_response$status_code != 200) {
        print("error occurred accepting the Terms and Conditions")
    }
}

# Now we can download the dataset.
base_url <- "https://freddiemac.embs.com/FLoan/Data"
download_page_url <- paste(base_url, "download.php", sep='/')
sprintf("Download page URL: %s", download_page_url)

response <- GET(download_page_url, set_cookies('PHPSESSID' = session_cookie))

if (response$status_code != 200) {
    print("error occurred")
}

html_content <- content(response, "text")
html_response = read_html(html_content, base_url = base_url)

# Get all the tags.
anchor_tags <- xml_find_all(html_response, ".//a")
anchor_href <- xml_attr(anchor_tags, 'href')
anchor_filenames <- xml_text(anchor_tags)

# Create a dataframe to associate the URLs with the filenames...seems easiest way to do this.
df = data.frame(href=anchor_href, filename=anchor_filenames)
df

origination_samples <- ""
performance_samples <- ""
historical_samples <- ""
historical_time_samples <- ""
for (i in 1:nrow(df)) {
    current_filename = as.character(df[i, "filename"])
    current_file_url = paste(base_url, df[i, "href"], sep='/')
    m <- paste(current_filename, current_file_url, sep=' ')

    # Only download and process the sample files.
    if (startsWith(current_filename, 'sample') || startsWith(current_filename, 'historical_data1_Q')) {
        print(sprintf("Checking for data: %s", m))
        zipfile_path = paste(".", current_filename, sep='/')

        # Only download if the file doesn't exist.
        if (!file.exists(zipfile_path)) {
            # Download the file (may take a while).
            print(sprintf("Downloading: %s", m))

            file_response <- GET(current_file_url, set_cookies('PHPSESSID' = session_cookie))

            # Write the content of the download to a binary file.
            print(sprintf("Writing content to: %s", zipfile_path))
            writeBin(content(file_response, "raw"), zipfile_path)
        }
        else {
            print(sprintf("%s already exists", zipfile_path))
        }

        # Get the listing of files in the archive.
        archive_file_list <- unzip(zipfile_path, list=TRUE)
        print(archive_file_list)

        # Capture the names of the origination and performance files for later.
        unzip_archive <- FALSE
        for (j in 1:nrow(archive_file_list['Name'])) {
            sample_file_name <- archive_file_list[j, 'Name']
            print(sample_file_name)

            if (startsWith(sample_file_name, "sample_orig")) {
                if (0 == str_length(origination_samples)) {
                    origination_samples <- sample_file_name
                }
                else {
                    origination_samples <- paste(origination_samples, sample_file_name, sep=' ')
                }

                # Samples are small enough to unzip.
                unzip_archive <- TRUE
            }
            else if (startsWith(sample_file_name, "sample_svcg")) {
                if (0 == str_length(performance_samples)) {
                    performance_samples <- sample_file_name
                }
                else {
                    performance_samples <- paste(performance_samples, sample_file_name, sep=' ')
                }

                # Samples are small enough to unzip.
                unzip_archive <- TRUE
            }
            else if (startsWith(sample_file_name, "historical_data1_time_Q")) {
                if (0 == str_length(historical_time_samples)) {
                    historical_time_samples <- sample_file_name
                }
                else {
                    historical_time_samples <- paste(historical_time_samples, sample_file_name, sep=' ')
                }

                # Historical data files are too large to unzip unless we need them.
                unzip_archive <- FALSE
            }
            else if (startsWith(sample_file_name, "historical_data1_Q")) {
                if (0 == str_length(historical_samples)) {
                    historical_samples <- sample_file_name
                }
                else {
                    historical_samples <- paste(historical_samples, sample_file_name, sep=' ')
                }

                # Historical data files are too large to unzip unless we need them.
                unzip_archive <- FALSE
            }
        }

        if (unzip_archive) {
            # Unzip the files from the archive.
            # Don't extract files that have already been extracted (overwrite=FALSE).
            unzip(zipfile_path, overwrite=FALSE)
        }
    }
}

print(origination_samples)
print(performance_samples)
print(historical_samples)
print(historical_time_samples)

origination_files <- strsplit(origination_samples, ' ', fixed=TRUE)
print(origination_files)

performance_files <- strsplit(performance_samples, ' ', fixed=TRUE)
print(performance_files)

historical_files <- strsplit(historical_samples, ' ', fixed=TRUE)
print(historical_files)

historical_time_files <- strsplit(historical_time_samples, ' ', fixed=TRUE)
print(historical_time_files)


# Try the User Guide sample code for originations files.
origclass <- c('integer', 'integer', 'character', 'integer', 'character', 'real', 'integer', 'character', 'real', 'integer','integer','integer', 'real', 'character', 'character', 'character', 'character', 'character', 'character', 'character', 'character', 'integer', 'integer', 'character', 'character', 'character')

origfile_Qnyyyy <- read.table("sample_orig_1999.txt", sep="|", header=FALSE, colClasses=origclass )

names(origfile_Qnyyyy)=c('fico', 'dt_first_pi', 'flag_fthb', 'dt_matr', 'cd_msa', 'mi_pct', 'cnt_units', 'occpy_sts', 'cltv', 'dti', 'orig_upb', 'ltv', 'int_rt', 'channel', 'ppmt_pnlty', 'prod_type', 'st', 'prop_type', 'zipcode', 'id_loan', 'loan_purpose', 'orig_loan_term', 'cnt_borr', 'seller_name', 'servicer_name', 'flag_sc')


# Try the User Guide sample code for performance files.
svcgclass <- c('character', 'integer', 'real', 'character', 'integer', 'integer', 'character', 'character', 'character', 'integer', 'real', 'real', 'integer', 'integer', 'character', 'integer', 'integer', 'integer', 'integer', 'integer', 'integer', 'real', 'real')

svcgfile_Qnyyyy <- read.table("sample_svcg_1999.txt", sep="|", header=FALSE, colClasses=svcgclass)

names(svcgfile_Qnyyyy)=c('id_loan', 'svcg_cycle', 'current_upb', 'delq_sts', 'loan_age', 'mths_remng', 'repch_flag', 'flag_mod', 'cd_zero_bal', 'dt_zero_bal', 'current_int_rt', 'non_int_brng_upb', 'dt_lst_pi', 'mi_recoveries', 'net_sale_proceeds', 'non_mi_recoveries', 'expenses', 'legal_costs', 'maint_pres_costs', 'taxes_ins_costs', 'misc_costs', 'actual_loss', 'modcost')
