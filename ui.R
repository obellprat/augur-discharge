# ------------------------------------------------
#
# AUGUR+ DEMONSTRATOR APP
#
# Author: Omar Bellprat, MeteoSwiss
# Contact: bellprat@climate.expert
# Date: 06.08.2022
#
# ------------------------------------------------

# DEFINE GLOBAL VARIABLES AND LIBRARIES
# ------------------------------------------------

# PREPARE UI
# ------------------------------------------------

# ------------------------------- Dashboard Header

header <- dashboardHeader(
  title = "AUGUR Discharge"
)

# ------------------------------- Dashboard Sidebar

sidebar <- dashboardSidebar(
  collapsed = TRUE,
  htmlOutput("about"),
  br(),
  selectInput(
    label = i18n$t("Change language"),
    inputId='selected_language',
    choices = i18n$get_languages(),
    selected = "es",
    width = 200),
  sidebarMenu()
  )

# ------------------------------- Dashboard Body

body <- dashboardBody(
  shiny.i18n::usei18n(i18n),
  tags$style(type = "text/css", "#map {height: calc(80vh) !important;}; "),
  tags$head(tags$style(HTML(".main-sidebar .shiny-bound-input {margin-left: 10px; margin-right: 10px; }"))), #change the font size to 20
  tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "augur.css")),
  
  # ------------------------------- Discharge Calculation
  
  fluidRow(br(),
           box(
             title = i18n$t("Map"),
             leafletOutput("map"),
             collapsible = TRUE,
             status = "primary",
             solidHeader = TRUE,
             absolutePanel(top = 150, right = 40, width=150, align = "right",
                           actionButton("catchment", label = i18n$t("Delineate Catchment")))),
           box(
             title = i18n$t("Hydrogram"),
             plotlyOutput("hydrogram", height = "40vh"),
             collapsible = TRUE,
             status = "primary",
             solidHeader = TRUE),
           tabBox(
             title = i18n$t("Catchment Properties"), side = "right",
             tabPanel(i18n$t("Parameters"),
                      fluidRow(
                        column(4,
                               selectInput("soil_type", width="200px",
                                           label = h5(i18n$t("Soil Type")),
                                           c("Deep (> 0.4m)" = "Deep",
                                             "Sandy (< 0.4m)" = "Sandy",
                                             "Superficial (moderate clay)" = "Superficial",
                                             "High clay content" = "Clay")),
                               numericInput("catchment_area", width="200px", label = h5(HTML(paste0(i18n$t("Catchment Area")," [km<sup>2</sup>]"))), value = default_area)),
                        column(4,
                               selectInput("basin_gradient", width="200px",
                                           label = h5(i18n$t("Slope Gradient")),
                                           c("Flat (8%)" = 0.08,
                                             "Moderate (30%)" = 0.3,
                                             "Steep (70%)" = 0.7),
                                           selected = 0.3),
                               numericInput("length_watercourse", width="200px", label = h5(i18n$t("Main river length [m]")), value = default_length)),
                        column(4,
                               selectInput("cc_period", width="200px",
                                           label = h5(i18n$t("Climate Change Period")),
                                           c("2022" = "pr",
                                             "2030" = "2030",
                                             "2050" = "2050",
                                             "2090" = "2090"),
                                           selected = 1),
                               br(),
                               actionButton("calculate", label = i18n$t("Compute Discharge")))
                        
                      )),
             tabPanel(i18n$t("Land cover"),
                      column(4,
                             numericInput("farmland", width="200px", label = h5(i18n$t("Farmland [%]")), value = 50),
                             numericInput("pasture", width="200px", label = h5(i18n$t("Pasture [%]")), value = 40)),
                      column(4,
                             numericInput("forest", width="200px", label = h5(i18n$t("Forest [%]")), value = 5),
                             numericInput("settlement", width="200px", label = h5(i18n$t("Settlement [%]")), value = 5)),
                      column(4,
                             numericInput("debris", width="200px", label = h5(i18n$t("Debris [%]")), value = 0)),
                             br(),br(),br(),br(),br(),br(),br(),br(),br())
             )))

ui <- dashboardPage(skin="blue",             
                    title = "AUGUR+",
                    header,
                    sidebar,
                    body
)
