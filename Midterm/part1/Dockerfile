# Start with the r-base Docker image for R.
FROM r-base

LABEL maintainer "lambe.v@husky.neu.edu"

# Add the native dependencies for the R packages.
RUN apt-get update
RUN apt-get -y install libssl-dev
RUN apt-get -y install libcurl4-openssl-dev
RUN apt-get -y install libxml2-dev
RUN rm -rf /var/lib/apt/lists/*

# Add the R packages.
RUN echo "r <- getOption('repos'); r['CRAN'] <- 'http://cran.us.r-project.org'; options(repos = r);" > ~/.Rprofile
RUN Rscript -e "install.packages('RCurl')"
RUN Rscript -e "install.packages('xml2')"
RUN Rscript -e "install.packages('httr')"
RUN Rscript -e "install.packages('stringr')"

# Add the R script we want to include in the image.
COPY ./midterm_casestudy_data.R /home/docker/midterm_casestudy_data.R

# Set the user and working directory.
USER docker
WORKDIR /home/docker

# Run the script
CMD ["Rscript", "midterm_casestudy_data.R"]
