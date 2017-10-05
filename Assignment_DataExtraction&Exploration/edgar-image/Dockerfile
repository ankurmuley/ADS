# Start with the dataquest python3 starter image.
FROM dataquestio/python3-starter:latest

LABEL maintainer "lambe.v@husky.neu.edu"

# Add the Python script we want to include in the image.
COPY edgar.py /home/ds/edgar.py

# Set the user and working directory.
USER ds
WORKDIR /home/ds

# Run the script
ENTRYPOINT ["/opt/ds/bin/python3", "/home/ds/edgar.py"]
