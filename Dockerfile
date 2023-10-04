# Base image https://hub.docker.com/u/rocker/
FROM rocker/shiny:latest

# system libraries of general use
## install debian packages
RUN apt-get update -qq && apt-get -y --no-install-recommends install \
    libxml2-dev \
    libcairo2-dev \
    libpq-dev \
    libssh2-1-dev \
    unixodbc-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    gdal-bin \
    libgdal-dev \
    python3 \
    python3-pip \
    curl \
    libudunits2-dev

## update system libraries
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean

## update system libraries
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir pysheds numpy fiona geojson elevation 

# copy necessary files
## renv.lock file
COPY /augur-discharge/renv.lock ./renv.lock
## app folder
COPY /augur-discharge ./app

# install renv & restore packages
RUN Rscript -e 'install.packages("renv")'
RUN Rscript -e 'renv::restore()'

# expose port
EXPOSE 3838

# run app on container start
CMD ["R", "-e", "shiny::runApp('/app', host = '0.0.0.0', port = 3838)"]
