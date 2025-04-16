library(leaflet)
library(sf)
library(shiny)
library(dplyr)

# Set working directory and read the litchi data
setwd('.')
litchi_data <- read.csv('litchi_template.csv')

# Step 1: Create an interactive map to pick a point
ui <- fluidPage(
  leafletOutput("mymap"),
  verbatimTextOutput("coordinates"),
  tableOutput("grid_table")
)

server <- function(input, output, session) {
  # Reactive value to store the grid data frame
  grid_df <- reactiveVal()
  
  # Initial map centered somewhere
  output$mymap <- renderLeaflet({
    leaflet(height = '100%') %>%
      addProviderTiles(providers$Esri.WorldImagery) %>% 
      setView(lng = 152.9631, lat = -28.8136, zoom = 10) # Example coordinates
  })
  
  # Click event to get the coordinates
  observeEvent(input$mymap_click, {
    click <- input$mymap_click
    lng <- click$lng
    lat <- click$lat
    
    output$coordinates <- renderPrint({
      paste("Longitude: ", lng, " Latitude: ", lat)
    })
    
    # Step 2: Reproject the point to EPSG:28356
    point_sf <- st_sfc(st_point(c(lng, lat)), crs = 4326)
    point_reprojected <- st_transform(point_sf, crs = 28356)
    
    # Extract coordinates
    coords <- st_coordinates(point_reprojected)
    
    # Step 3: Create the fishnet grid at 50m intervals
    grid_size <- 50
    n <- 10  # Number of rows and columns in the grid
    
    xmin <- coords[1] - (n/2)*grid_size
    xmax <- coords[1] + (n/2)*grid_size
    ymin <- coords[2] - (n/2)*grid_size
    ymax <- coords[2] + (n/2)*grid_size
    
    grid <- st_make_grid(
      st_bbox(c(xmin = xmin, ymin = ymin, xmax = xmax, ymax = ymax)), 
      cellsize = c(grid_size, grid_size),
      what = "centers"
    )
    
    # Reorder points in the specified pattern
    coords_grid <- st_coordinates(grid)
    
    # Convert coordinates to data frame for easier manipulation
    coords_df <- as.data.frame(coords_grid)
    coords_df$col <- as.integer((coords_df$X - xmin) / grid_size) + 1
    coords_df$row <- as.integer((coords_df$Y - ymin) / grid_size) + 1
    
    # Order by columns first and then apply the snake-like pattern within each column
    coords_df <- coords_df[order(coords_df$col, coords_df$row), ]
    coords_df$row <- ave(coords_df$row, coords_df$col, FUN = function(x) ifelse(x[1] %% 2 == 1, x, rev(x)))
    
    # Final reordering
    coords_df <- coords_df[order(coords_df$col, coords_df$row), ]
    
    # Convert reordered coordinates back to sf object
    reordered_grid <- st_as_sf(coords_df, coords = c("X", "Y"), crs = 28356)
    reprojected_grid <- st_transform(reordered_grid, crs = 4326)
    
    # Save the grid as a data frame
    grid_df(as.data.frame(st_coordinates(reprojected_grid)))
    
    # Add grid points to the map
    leafletProxy("mymap") %>%
      clearMarkers() %>%
      addCircleMarkers(data = st_transform(reordered_grid, crs = 4326), 
                       radius = 2, 
                       color = "red")
  })
  
  # Observe changes in the grid data frame and print it to the console
  observe({
    if (!is.null(grid_df())) {
      grid <- grid_df()
      
      # Rename columns
      colnames(grid) <- c("longitude", "latitude")
      
      # Combine with litchi_data
      combined_data <- cbind(grid, litchi_data)
      
      # Reorder columns to start with latitude and longitude
      combined_data <- combined_data[, c("latitude", "longitude", setdiff(names(combined_data), c("latitude", "longitude")))] %>% 
        arrange(order) %>% 
        select(!order)
      
      # Print the combined data frame
      print(combined_data)
      
      # Save to CSV file
      filename <- paste0("output_", Sys.time(), ".csv")
      filename <- gsub("[: ]", "_", filename)  # Replace invalid characters in filename
      write.csv(combined_data, file = filename, row.names = FALSE)
    }
  })
  
}

shinyApp(ui, server)
