
server <- function(input, output, session) {
  selected <- reactiveValues(xy = cbind(default_lon, default_lat))
  
  # ------------------------------- Discharge Calculation
  
  output$map <- renderLeaflet({
    
    #################################################
    # Leaflet Map
    #################################################
    
    leaflet(options = leafletOptions(minZoom = 4, maxZoom = 17)) %>%
      setView(lng = 7.92,
              lat = 46.91,
              zoom = 13) %>%
      addSearchOSM(options = searchOptions(collapsed = FALSE,position = "bottomright")) %>%
      addProviderTiles("OpenTopoMap", group = i18n$t("Topographic")) %>%
      addProviderTiles("Esri.WorldImagery", group = i18n$t("Satellite")) %>%
      addProviderTiles("CartoDB.Positron", group = i18n$t("Street")) %>%
      addLayersControl(baseGroups = c(i18n$t("Satellite"), i18n$t("Topographic"), i18n$t("Street")),
                       options = layersControlOptions(collapsed = FALSE)) %>%
      addAwesomeMarkers(
        lat = default_lat,
        lng = default_lon,
        layerId = "selid",
        icon = icon_sel) %>% 
      addPolygons(data = catchment, 
                  weight = 3,
                  color = "orange",
                  opacity = 1,
                  layerId = "catchment") %>%
      addPolylines(data = branches,
                   weight = 1,
                   color = "orange",
                   opacity = 1)  %>%
      htmlwidgets::onRender("function(el, x) {
        $('input.search-input')[0].placeholder = 'Search place ... '
        }")
  })
  
  iniplot <- plot_hydrogram(cbind(default_lon, default_lat), "Deep", land_type, 
                            land_factors, default_area, default_length, 0.08, cc_period = "pr", default_area_rain)
  
  output$hydrogram <- renderPlotly(iniplot)
  
  observeEvent(input$map_click, {
    click = input$map_click
    selected$xy <- cbind(click$lng,click$lat)
    proxy <- leafletProxy('map')
    proxy %>% addAwesomeMarkers(
      lat = click$lat,
      lng = click$lng,
      layerId = "selid",
      icon = icon_sel) 
  })
  
  #################################################
  # Catchment Delineation
  #################################################
  
  observeEvent(input$catchment, {
    if (raster::extract(aca,selected$xy)*0.01 > 500) {
      shinyalert("Catchment size is likely too big", "The hydrological method is only valid for catchment sizes of approximately 300 square kilometers. Select a different location.", type = "error")
    
    } else {
      
      if (input$selected_language == "en"){
        prog_message <- "Delineating catchment  ..."
      } else if (input$selected_language == "es"){
        prog_message <- "Delimintando cuenca  ..."
      } else if (input$selected_language == "de"){
        prog_message <- "Eingrenzung Einzuggsbegiet  ..."
      }
      
      withProgress(message = prog_message, {
        tmpdir <- tempdir()
        dem_file <- tempfile(pattern = "dem", tmpdir = tempdir(), fileext = ".tif")
        dist_file <- tempfile(pattern = "dist", tmpdir = tempdir(), fileext = ".txt")
        branches_file <- tempfile(pattern = "branches", tmpdir = tempdir(), fileext = ".geojson")
        catchment_file <- tempfile(pattern = "catchment", tmpdir = tempdir(), fileext = ".shp")
        
        west = selected$xy[1] - 0.3
        south = selected$xy[2] - 0.3
        east = selected$xy[1] + 0.3
        north = selected$xy[2] + 0.3
        print(paste0("eio clip -o ", dem_file," --bounds ",  west, " ", south, " ", east, " ", north))
        system(paste0("eio clip -o ", dem_file," --bounds ",  west, " ", south, " ", east, " ", north))
        incProgress(0.3)
        
        print(paste0("python3 Py/catchment.py ", dem_file, " ", dist_file, " ", branches_file, " ", catchment_file, " ", 
                      selected$xy[1], " ", selected$xy[2]))
        system(paste0("python3 Py/catchment.py ", dem_file, " ", dist_file, " ", branches_file, " ", catchment_file, " ", 
                      selected$xy[1], " ", selected$xy[2]))
        
        catchment <- st_read(catchment_file)
        area <- max(as.numeric(st_area(catchment) / 10^6))
      
        updateNumericInput(session, "catchment_area", value = round(area,0))
        
        properties <- read.table(dist_file)
        dist <- properties[1,]
        selected$xy <- cbind(properties[2,],properties[3,])
        
        updateNumericInput(session, "length_watercourse", value = dist)
        
        branches <- st_read(branches_file)
        
        proxy <- leafletProxy('map')
        clearShapes(proxy)
        proxy %>% addPolygons(data=catchment, 
                              weight = 3,
                              color = "orange",
                              opacity = 1,
                              layerId = "catchment") %>%
          addPolylines(data=branches,
                       weight = 1,
                       color = "orange",
                       opacity = 1) %>% 
          addAwesomeMarkers(
            lat = selected$xy[2],
            lng = selected$xy[1],
            layerId = "selid",
            icon = icon_sel) 
      })
    }
  })
  
  #################################################
  # Calculate Discharge
  #################################################
  
  observeEvent(input$calculate, {
    soil_type <- isolate(input$soil_type)
    catchment_area <- isolate(input$catchment_area)
    area_rain <- 106.61 * catchment_area^(-0.289) # Parameterized rain covered area from Georg
    length_watercourse <- isolate(input$length_watercourse)
    basin_gradient <- isolate(as.numeric(input$basin_gradient))
    cc_period <- isolate(input$cc_period)
    land_type["Farmland",] <- isolate(input$farmland)
    land_type["Pasture",] <- isolate(input$pasture)
    land_type["Forest",] <- isolate(input$forest)
    land_type["Settlement",] <- isolate(input$settlement)
    land_type["Debris",] <- isolate(input$debris)
    
    if (input$catchment_area > 300) {
      shinyalert("Catchment size too big", "The hydrological method is only valid for catchment sizes of approximately 300 square kilometers", type = "warning")
      output$hydrogram <- renderPlotly(plot_hydrogram(catchment, soil_type, land_type, 
                                                      land_factors, catchment_area, length_watercourse, basin_gradient, cc_period, area_rain))
    } else if (sum(land_type) != 100) {
      shinyalert("Land types wrongly specified", "The percentages of the land types need so sum to 100 %", type = "error")
    } else {
      output$hydrogram <- renderPlotly(plot_hydrogram(catchment, soil_type, land_type, 
                                                      land_factors, catchment_area, length_watercourse, basin_gradient, cc_period, area_rain))
    }
  })
  
  #################################################
  # Language Translation
  #################################################
  
  observeEvent(input$selected_language, {
    
    if (input$selected_language == "es") {
      
      updateSelectInput(session, "soil_type",
                        choices = c("Profundo (> 0.4m)" = "Deep",
                                    "Arenoso (< 0.4m)" = "Sandy",
                                    "Superficial (arcilla moderada)" = "Superficial", 
                                    "Alto contenido de arcilla" = "Clay")) 
      
      updateSelectInput(session, "basin_gradient",
                        choices = c("Plano (8%)"= 0.08,
                                    "Moderado (30%)" = 0.3 ,
                                    "Empinada (70%)" = 0.7))
      
      
    } else if (input$selected_language == "de") {
      
      updateSelectInput(session, "soil_type",
                        choices = c("Tief (> 0.4 m)" = "Deep",
                                    "Sandig (< 0.4m)" = "Sandy",
                                    "Oberflächlich (mäßiger Ton)" = "Superficial", 
                                    "Hoher Tongehalt" = "Clay")) 
      
      updateSelectInput(session, "basin_gradient",
                        choices = c("Flach (8%)" = 0.08,
                                    "Mäßig (30%)" = 0.3,
                                    "Steil (70%)" = 0.7))
    } else if (input$selected_language == "en") {
      
      updateSelectInput(session, "soil_type",
                        choices = c("Deep (> 0.4 m)" = "Deep",
                                    "Sandy (< 0.4m)" = "Sandy",
                                    "Superficial (mäßiger Ton)" = "Superficial", 
                                    "High clay" = "Clay")) 
      
      updateSelectInput(session, "basin_gradient",
                        choices = c("Flat (8%)" = 0.08,
                                    "Moderate (30%)" = 0.3,
                                    "Steep (70%)" = 0.7))
    }
    
    update_lang(session, input$selected_language)
  })  
  
  output$about <- renderText(
    includeHTML(paste0("www/about_",input$selected_language,".html"))
  )
}