# Make Hexagon Logo

if(T){
  
  # Setup ----------------------------------------------------------------------
  library(blackmarbler)
  library(hexSticker)
  library(ggplot2)
  library(tidyverse)
  library(raster)
  library(sf)
  library(magick)
  
  bearer <- read_csv("~/Dropbox/bearer_bm.csv") %>%
    pull(token)
  
  # Make ROI -------------------------------------------------------------------
  loc_sf <- data.frame(id = 1,
                       lat = 39.10968435276649, 
                       lon = -84.51499766385844)
  
  loc_sf <- st_as_sf(loc_sf,
                     coords = c("lon", "lat"),
                     crs = 4326) %>%
    st_buffer(dist = 300*1000) # 410
  
  r <- bm_raster(roi_sf = loc_sf,
                 product_id = "VNP46A4",
                 date = 2021,
                 bearer = bearer)
  r <- raster(r)
  
  #### Prep data
  r_df <- rasterToPoints(r, spatial = TRUE) %>% as.data.frame()
  names(r_df) <- c("value", "x", "y")
  
  ## Remove very low values of NTL; can be considered noise 
  r_df$value[r_df$value <= 1] <- 0
  
  ## Distribution is skewed, so log
  r_df$value_adj <- log(r_df$value+1)
  
  ##### Map 
  p <- ggplot() +
    geom_raster(data = r_df, 
                aes(x = x, y = y, 
                    fill = value_adj)) +
    scale_fill_gradient2(low = "#000A33",
                         mid = "yellow",
                         high = "firebrick",
                         midpoint = 4) +
    coord_quickmap() + 
    theme_void() +
    theme(legend.position = "none")
  
  sticker(p, 
          package="blackmarble-stata", 
          spotlight = F,
          #l_alpha = 1, #0.15,
          p_size=16, #7 
          p_y = 1.40,
          p_family = "sans",
          p_fontface = "italic",
          s_x=1, 
          s_y=0.8, 
          s_width=2.8, 
          s_height=2.8,
          p_color = "white",
          h_fill = "black",
          h_color = "black",
          white_around_sticker = T,
          l_y = 1.4,
          l_x = 0.93,
          l_width = 3,
          l_height = 3,
          filename="~/Documents/Github/blackmarble-stata/man/figures/logo.png")
  
  #### Slightly crop
  # Load the image
  img <- image_read("~/Documents/Github/blackmarble-stata/man/figures/logo.png")
  
  # Get image dimensions
  info <- image_info(img)
  width <- info$width
  height <- info$height
  
  # Define crop margins (adjust as needed, e.g., 5 pixels on each side)
  crop_width <- width - 0
  crop_height <- height - 6
  offset_x <- 0
  offset_y <- 3
  
  # Perform the crop
  cropped_img <- image_crop(img, geometry_area(crop_width, crop_height, offset_x, offset_y))
  
  # Save the cropped image (overwrite or save with a new name)
  image_write(cropped_img, path = "~/Documents/Github/blackmarble-stata/man/figures/logo.png")

  
 
}