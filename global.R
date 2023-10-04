rm(list = ls())

library(shiny)
library(shinydashboard)
library(tidyr)
library(leaflet)
library(leaflet.extras)
library(plotly)
library(raster)
library(ncdf4)
library(shinyMatrix)
library(shinyalert)
library(sf)
library(RColorBrewer)
library(shiny.i18n)  
library(htmlwidgets)

# if (Sys.info()[[4]] == "omars-macbook-air.home") {
#   setwd("~/Documents/AUGUR/shiny-server/AugurDischarge")
# } else if (Sys.info()[[4]] == "AUGUR") {
#   setwd("/srv/shiny-server/AugurDischarge")
# }

options(shiny.port = 3838)

# DEFINE GLOBAL VARIABLES
# ------------------------------------------------

default_lon <- 7.909126; default_lat <- 46.89544

default_area <- 16; default_length <- 7620
default_area_rain <- 106.61 * default_area^(-0.289) # Parameterized rain covered area from Georg


# SET LANGUAGE TRANSLATION
# ------------------------------------------------

i18n <- shiny.i18n::Translator$new(translation_json_path='www/translation.json')
i18n$set_translation_language('en')
shiny.i18n::usei18n(i18n)

#################################################
# AUGUR - Heavy Rain Functions
#################################################


# Load return period data CHIRPS
r1 <- raster::brick("./Data/ret.10.chirps.lm.nc")
r2 <- raster::brick("./Data/ret.20.chirps.lm.nc")
r3 <- raster::brick("./Data/ret.30.chirps.lm.nc")
r4 <- raster::brick("./Data/ret.50.chirps.lm.nc")
r5 <- raster::brick("./Data/ret.100.chirps.lm.nc")
cc1 <- raster::brick("./Data/cmip6_2030_atlas.nc")
cc2 <- raster::brick("./Data/cmip6_2050_atlas.nc")
cc3 <- raster::brick("./Data/cmip6_2090_atlas.nc")

rain <- function(sp){
  rv1 <- max(round(unlist(raster::extract(r1,sp))))
  rv2 <- max(round(unlist(raster::extract(r2,sp))))
  rv3 <- max(round(unlist(raster::extract(r3,sp))))
  rv4 <- max(round(unlist(raster::extract(r4,sp))))
  rv5 <- max(round(unlist(raster::extract(r5,sp))))
  pv <- 1
  cv1 <- max(round(unlist(raster::extract(cc1,sp)))) / 100 + 1
  cv2 <- max(round(unlist(raster::extract(cc2,sp)))) / 100 + 1
  cv3 <- max(round(unlist(raster::extract(cc3,sp)))) / 100 + 1
  
  data_out <- cbind(rv1,rv2,rv3,rv4,rv5,pv,cv1,cv2,cv3)
  colnames(data_out) <- c("yr10","yr20","yr30","yr50","yr100","pr","2030","2050","2090")
  return(data_out)
}


#################################################
# AUGUR+ - River Discharge 
#################################################

# DEFAULT CALIBRATION VALUES
# ------------------------------------------------

land_factors = rbind(c(35,40,43,46),
                     c(37,37,40,82),
                     c(20,48,70,100),
                     c(59,73,100,60), 
                     c(8,10,15,25))

rownames(land_factors) = c("Farmland", "Pasture", "Forest", "Settlement", "Debris")
colnames(land_factors) = c("Deep","Sandy","Superficial","Clay")

land_type = matrix(c(50,40,5,5,0))
rownames(land_type) = c("Farmland", "Pasture", "Forest", "Settlement", "Debris")
colnames(land_type) = c("Percentage [%]")


# LOAD GLOBAL ACCUMULATED AREA DATA FROM HYDROSHEDS
# ------------------------------------------------

aca <- raster("./Data/hyd_glo_aca_15s.tif", drivers="netCDF")

# DEFAULT CATCHMENT DATA
# ------------------------------------------------

catchment <- st_read(paste0("./Data/catchment.shp"))
branches <- st_read(paste0("./Data/branches.geojson"))

# GLOBAL PLOTTING VARIABLES
# ------------------------------------------------

font <- list(
  size = 12,
  color = "black",
  family = "helvetica"
)

label <- list(
  bordercolor = "transparent",
  font = font
)

icon_sel <- makeAwesomeIcon(
  iconColor = "#FFFFFF",
  library = "fa",
  icon = "circle",
  markerColor = "orange"
)

