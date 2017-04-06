# Start with the r-base Docker image for R.
FROM r-base

LABEL maintainer "lambe.v@husky.neu.edu"

# Add the native dependencies for the R packages.
RUN apt-get update
RUN rm -rf /var/lib/apt/lists/*

# Add the R packages.
RUN echo "r <- getOption('repos'); r['CRAN'] <- 'http://cran.us.r-project.org'; options(repos = r);" > ~/.Rprofile
RUN Rscript -e "install.packages('stringr')"
RUN Rscript -e "install.packages('forecast')"
RUN Rscript -e "install.packages('caret')"
RUN Rscript -e "install.packages('ROCR')"
RUN Rscript -e "install.packages('randomForest')"

# Add the R script we want to include in the image.
COPY ./classification.R /home/docker/classification.R

# Set the user and working directory.
USER docker
WORKDIR /home/docker

# Run the script
CMD ["Rscript", "classification.R"]
