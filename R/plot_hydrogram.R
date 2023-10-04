plot_hydrogram <- function(catchment, soil_type, land_type, 
                land_factors, catchment_area, length_watercourse,
                basin_gradient, cc_period, area_rain){
  
  rt = rain(catchment)
  yr10_rain = as.numeric(rt[,"yr10"][1] * rt[,cc_period][1])
  yr30_rain = as.numeric(rt[,"yr30"][1] * rt[,cc_period][1])
  yr100_rain = as.numeric(rt[,"yr100"][1] * rt[,cc_period][1])
  duration_storm = 120 # minutes
  
  landuse_factor = land_type["Farmland",] / 100 * land_factors[c("Farmland"), soil_type] +
    land_type["Pasture",] / 100 * land_factors[c("Pasture"), soil_type] +
    land_type["Forest",] / 100 * land_factors[c("Forest"), soil_type] +
    land_type["Settlement",] / 100 * land_factors[c("Settlement"), soil_type] +
    land_type["Debris",] / 100 * land_factors[c("Debris"), soil_type]
  
  # Precipitation relevant to runoff
  rain_runoff = data.frame("yr10"= 0.7 * area_rain / 100 * yr10_rain * landuse_factor / 100, 
                           "yr30" = 0.7 * area_rain / 100 * yr30_rain * landuse_factor / 100,
                           "yr100" = 0.7 * area_rain / 100 * yr100_rain * landuse_factor / 100)
  
  # Hietogram
  h_f = c(0.18,0.46,0.23,0.13) 
  
  # Time from start of rain to maximum outflow [h]
  T_p = (duration_storm / 2 + 0.6 * 0.02 * length_watercourse^0.77 * basin_gradient^(-.385)) / 60
  
  # Unit peakflow [m^3 / s]
  Q_p = 0.208 * catchment_area / T_p
  Q_r = seq(0,3, by = 0.1)
  Q = c(Q_r[Q_r <= 1] * Q_p, Q_p - ((Q_r[Q_r > 1] - 1) / 2 * Q_p))
  
  # Time variables
  time_flow = Q_r * T_p
  time_step = seq(0,4.5, by=0.5)
  time_hydro = c(0.0, 0.3, 0.5, 0.8, 1.1, 1.4, 2.2, 2.7, 3.3, 3.8, 4.4, 4.9, 5.5) 
  sel_id <- c(1,5,8,13,17,21,25,29,1,1) # not clear how this is selected
  
  # Hydrograph
  
  hydrogram <- array(NA, dim = c(length(time_hydro),length(rain_runoff)))
  for (j in 1:length(rain_runoff)) {
    p_array <- array(NA, dim = c(length(time_hydro),length(time_step)))
    for (i in 1:length(time_step)) {
      p_array[i,i] <- Q[sel_id[i]] * h_f[1] * unlist(rain_runoff[j])
      p_array[i+1,i] <- Q[sel_id[i]] * h_f[2] * unlist(rain_runoff[j])
      p_array[i+2,i] <- Q[sel_id[i]] * h_f[3] * unlist(rain_runoff[j])
      p_array[i+3,i] <- Q[sel_id[i]] * h_f[4] * unlist(rain_runoff[j])
    }
    hydrogram[,j] <- rowSums(p_array,na.rm=T) * 0.9
  }

  pl_data <- data.frame("time" = time_hydro, 
                        "yr10" = hydrogram[,1],
                        "yr30" = hydrogram[,2],
                        "yr100" = hydrogram[,3]) 
  
  pl_data_melted = tidyr::gather(pl_data, "variable","value",-time)
  
  colors <- c("#41b6c4", "#2c7fb8", "#253494")
  xlimits <- c(min(pl_data$time),max(pl_data$time))
  legend_labels <- c("Frequent (10 year)","Rare (30 year)","Extreme (100 year)")
  title <- c("")
  
  plt <- pl_data_melted %>%
    ggplot(aes(x=time)) +
   # ggtitle(title) +
    scale_color_manual(name ='', values = colors, breaks = c("yr10", "yr30","yr100"), labels = legend_labels) + 
    geom_line(aes(y = value, color = variable), alpha=0.4) +
    scale_x_continuous(limits = xlimits, expand = c(0,0), name = "Time [h]") +
    theme_light() + 
    guides(fill = "none") + 
    theme(plot.title = element_text(size=10),
          legend.text = element_text(size=10),
          axis.text.x = element_text(size = 10),
          axis.text.y = element_text(size = 10),
          axis.title.y = element_text(size = 10)) +
    scale_alpha(guide = 'none')  
  
  font <- list(
    size = 12,
    color = "black",
    family = "helvetica"
  )
  
  label <- list(
    bordercolor = "transparent",
    font = font
  )
  
  p <- plotly::ggplotly(plt, orientation = "h", tooltip =c("value","variable")) %>% 
    plotly::config(displayModeBar = F, displaylogo = FALSE) %>%
    plotly::layout(autosize = T, hoverlabel=label, font = font, title = title, 
                   yaxis = list(title = "Flow [m<sup>3</sup>/s]"),
                   xaxis = list(showgrid = FALSE),
                   legend = list(x = 0.65, y = 0.95, font = list(size = 12) , bgcolor = 'rgba(0,0,0,0)'),
                   showgrid = FALSE)
  
  p$x$data[[1]]$text <- paste0(round(pl_data$yr10, digits = 0), " [m<sup>3</sup>/s]")
  p$x$data[[2]]$text <- paste0(round(pl_data$yr100, digits = 0), " [m<sup>3</sup>/s]")
  p$x$data[[3]]$text <- paste0(round(pl_data$yr30, digits = 0), " [m<sup>3</sup>/s]")
  p$x$data[[1]]$name <- "Frequent (10 year)"
  p$x$data[[2]]$name <- "Extreme (100 year)"
  p$x$data[[3]]$name <- "Rare (30 year)"
  
  p
}