# Extract and send BlackMarble Data to s3

# [GEO-DATASET] / [GEO-LEVEL] / [UNIT] / [NTL DATASET] / [NTL TIME LEVEL] / [FILE FORMAT]

library(tidyverse)
library(blackmarbler)
library(aws.s3)
library(sf)
library(here)
library(haven)
library(lubridate)
library(arrow)
library(exactextractr)
library(raster)

N_TRIES <- 10

# Function to try again after errors -------------------------------------------
try_often <- function(expr, max_retries = 10) {
  attempt <- 0
  success <- FALSE
  result <- NULL
  
  while (attempt < max_retries && !success) {
    attempt <- attempt + 1
    message(paste("Attempt", attempt, "of", max_retries))
    
    tryCatch({
      result <- eval.parent(substitute(expr))  # Evaluate the expression
      success <- TRUE  # Mark success if no error occurs
      message("Success!")
    }, error = function(e) {
      if (grepl("401", e$message) | grepl("502", e$message)) {
        message(e$message)
        message("Retrying!")
      } else {
        stop("An unexpected error occurred: ", e$message)
      }
    })
    
    Sys.sleep(5)
  }
  
  return(result)
}


# Keys -------------------------------------------------------------------------
nasa_bearer <- read_csv("~/Dropbox/bearer_bm.csv") %>% pull(token)

#### Set AWS Keys for s# Bucket
api_keys <- read.csv("~/Dropbox/World Bank/Webscraping/Files for Server/api_keys.csv", stringsAsFactors=F)

Sys.setenv("AWS_ACCESS_KEY_ID" = api_keys$Key[(api_keys$Service %in% "AWS_ACCESS_KEY_ID") & (api_keys$Account %in% "robmarty3@gmail.com")],
           "AWS_SECRET_ACCESS_KEY" = api_keys$Key[(api_keys$Service %in% "AWS_SECRET_ACCESS_KEY") & (api_keys$Account %in% "robmarty3@gmail.com")],
           "AWS_DEFAULT_REGION" = "us-east-2")

# Extract data -----------------------------------------------------------------

# Loop base dataset - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
for(geo_dataset_i in c("gadm_410")){
  
  # Loop ADM level - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
  for(geo_level_i in c("ADM_0", "ADM_1", "ADM_2")){
    
    units_vec <- here("data-to-s3", "data", geo_dataset_i, geo_level_i) %>%
      list.files(pattern = "*.geojson") %>%
      str_replace_all(".geojson", "")
    
    units_vec <- units_vec[units_vec != "ATA"] # Antarctica
    units_vec <- units_vec[units_vec != "TKL"] # Tokelau
    units_vec <- units_vec[units_vec != "WSM"] # Tokelau
    units_vec <- units_vec[units_vec != "WLF"] # Tokelau
    units_vec <- units_vec[units_vec != "TON"] # Tokelau
    
    # Loop unit - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    for(unit_i in units_vec){
      
      roi_i_sf <- readRDS(here("data-to-s3", "data", geo_dataset_i, geo_level_i, paste0(unit_i, ".Rds")))
      roi_i_sf <- roi_i_sf %>% st_make_valid()
      
      # Loop NTL dataset - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      for(ntl_dataset_i in c("blackmarble")){
        
        # Loop time-step type - - - - - - - - - - - - - - - - - - - - - - - - - 
        for(ntl_time_level_i in c("annual")){ # , "monthly", "daily"
          
          #### Create dates to query
          ## Annual
          if( (ntl_dataset_i == "blackmarble") & (ntl_time_level_i == "annual")){
            #dates_vec <- 2021:2023
            dates_vec <- 2023
          } 
          
          ## Monthly
          if( (ntl_dataset_i == "blackmarble") & (ntl_time_level_i == "monthly")){
            
            # dates_vec <- seq.Date(from = ymd("2012-01-01"),
            #                       to = Sys.Date(),
            #                       by = "month") %>%
            #   as.character()
            dates_vec <- seq.Date(from = ymd("2023-01-01"),
                                  to = ymd("2023-12-01"),
                                  by = "month") %>%
              as.character()
          } 
          
          ## Daily
          if( (ntl_dataset_i == "blackmarble") & (ntl_time_level_i == "daily")){
            
            dates_vec <- seq.Date(from = ymd("2012-01-01"),
                                  to = Sys.Date(),
                                  by = "day") %>%
              as.character()
            dates_vec <- dates_vec[1:3]
          } 
          
          #### Grab file names already queried
          if(F){
            files_in_s3_list <- get_bucket(bucket = "wb-blackmarble", 
                                           prefix = paste0(geo_dataset_i, "/", geo_level_i, "/", unit_i, "/", ntl_dataset_i, "/", ntl_time_level_i, "/"))
            files_in_s3 <- sapply(files_in_s3_list, function(x) x$Key) %>% 
              as.vector()
          }
          
          files_in_s3 <- list.files("~/Desktop/stata_ntl_data",
                                    recursive = T,
                                    pattern = "*.parquet")
          
          # Loop date - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
          for(date_i in dates_vec){
            
            s3_path_date_i <- paste0(geo_dataset_i, "/", geo_level_i, "/", unit_i, "/", ntl_dataset_i, "/", ntl_time_level_i, "/", date_i, ".parquet")
          
            if(!(s3_path_date_i %in% files_in_s3)){ 
              print(unit_i)
              
              # Make folders in s3 -----------------------------------------------
              # put_object(file = raw(),
              #            object = paste0(geo_dataset_i, "/"),
              #            bucket = "wb-blackmarble")
              # 
              # put_object(file = raw(),
              #            object = paste0(geo_dataset_i, "/", geo_level_i, "/"),
              #            bucket = "wb-blackmarble")
              # 
              # put_object(file = raw(),
              #            object = paste0(geo_dataset_i, "/", geo_level_i, "/", unit_i, "/"),
              #            bucket = "wb-blackmarble")
              # 
              # put_object(file = raw(),
              #            object = paste0(geo_dataset_i, "/", geo_level_i, "/", unit_i, "/", ntl_dataset_i, "/"),
              #            bucket = "wb-blackmarble")
              # 
              # put_object(file = raw(),
              #            object = paste0(geo_dataset_i, "/", geo_level_i, "/", unit_i, "/", ntl_dataset_i, "/", ntl_time_level_i, "/"),
              #            bucket = "wb-blackmarble")
              
              #### LOCAL - FOR TESTING
              dir.create("~/Desktop/stata_ntl_data")
              dir.create(paste0("~/Desktop/stata_ntl_data/", geo_dataset_i, "/"))
              dir.create(paste0("~/Desktop/stata_ntl_data/", geo_dataset_i, "/", geo_level_i, "/"))
              dir.create(paste0("~/Desktop/stata_ntl_data/", geo_dataset_i, "/", geo_level_i, "/", unit_i, "/"))
              dir.create(paste0("~/Desktop/stata_ntl_data/", geo_dataset_i, "/", geo_level_i, "/", unit_i, "/", ntl_dataset_i, "/"))
              dir.create(paste0("~/Desktop/stata_ntl_data/", geo_dataset_i, "/", geo_level_i, "/", unit_i, "/", ntl_dataset_i, "/", ntl_time_level_i, "/"))
              
              
              # Extract and add file to s3 ---------------------------------------
              
              #### Query data
              if( (ntl_dataset_i == "blackmarble") & (ntl_time_level_i == "annual")){
                dates_vec <- 2021:2023
              } 
              
              if(ntl_dataset_i == "blackmarble"){
                
                if(ntl_time_level_i == "annual"){
                  
                  ntl_r <- try_often(
                    bm_raster(roi_sf = roi_i_sf,
                              product_id = "VNP46A4",
                              date = date_i,
                              bearer = nasa_bearer,
                              variable = "NearNadir_Composite_Snow_Free",
                              h5_dir = here("data-to-s3", "data", "blackmarble_rasters", "annual")),
                    N_TRIES)
                  
                  qual_r <- try_often(
                    bm_raster(roi_sf = roi_i_sf,
                              product_id = "VNP46A4",
                              date = date_i,
                              bearer = nasa_bearer,
                              variable = "NearNadir_Composite_Snow_Free_Quality",
                              h5_dir = here("data-to-s3", "data", "blackmarble_rasters", "annual")),
                    N_TRIES)
                  
                }
                
                if(ntl_time_level_i == "monthly"){
                  ntl_r <- try_often(
                    bm_raster(roi_sf = roi_i_sf,
                              product_id = "VNP46A3",
                              date = date_i,
                              bearer = nasa_bearer,
                              variable = "NearNadir_Composite_Snow_Free",
                              h5_dir = here("data-to-s3", "data", "blackmarble_rasters", "monthly")),
                    N_TRIES)
                  
                  qual_r <- try_often(
                    bm_raster(roi_sf = roi_i_sf,
                              product_id = "VNP46A3",
                              date = date_i,
                              bearer = nasa_bearer,
                              variable = "NearNadir_Composite_Snow_Free_Quality",
                              h5_dir = here("data-to-s3", "data", "blackmarble_rasters", "monthly")),
                    N_TRIES)
                }
                
                if(ntl_time_level_i == "daily"){
                  ntl_r <- try_often(
                    bm_raster(roi_sf = roi_i_sf,
                              product_id = "VNP46A2",
                              date = date_i,
                              bearer = nasa_bearer,
                              variable = "DNB_BRDF-Corrected_NTL", # Gap_Filled_
                              h5_dir = here("data-to-s3", "data", "blackmarble_rasters", "daily")),
                    N_TRIES)
                  
                  qual_r <- try_often(
                    bm_raster(roi_sf = roi_i_sf,
                              product_id = "VNP46A2",
                              date = date_i,
                              bearer = nasa_bearer,
                              variable = "Mandatory_Quality_Flag",
                              h5_dir = here("data-to-s3", "data", "blackmarble_rasters", "daily")),
                    N_TRIES)
                }
                
                if(!is.null(ntl_r)){
                  
                  tmp_r <- ntl_r
                  tmp_r[] <- 1
                  tmp_r <- mask(tmp_r, roi_i_sf)
                  
                  roi_i_sf$ntl_sum    <- exact_extract(ntl_r,        roi_i_sf, "sum")
                  roi_i_sf$ntl_mean   <- exact_extract(ntl_r,        roi_i_sf, "mean")
                  roi_i_sf$ntl_median <- exact_extract(ntl_r,        roi_i_sf, "median")
                  
                  roi_i_sf$n_na       <- exact_extract(is.na(ntl_r), roi_i_sf, "sum")
                  roi_i_sf$n_pixel    <- exact_extract(tmp_r,        roi_i_sf, "sum")
                  roi_i_sf$qual_0_sum <- exact_extract(qual_r == 0,  roi_i_sf, "sum")
                  roi_i_sf$qual_1_sum <- exact_extract(qual_r == 1,  roi_i_sf, "sum")
                  roi_i_sf$qual_2_sum <- exact_extract(qual_r == 2,  roi_i_sf, "sum")
                  
                  roi_i_df <- roi_i_sf %>%
                    st_drop_geometry() %>%
                    dplyr::mutate(prop_na = n_na / n_pixel,
                                  prop_quality_0 = qual_0_sum / n_pixel,
                                  prop_quality_1 = qual_1_sum / n_pixel,
                                  prop_quality_2 = qual_2_sum / n_pixel) %>%
                    dplyr::select(-c(n_na, n_pixel, qual_0_sum, qual_1_sum, qual_2_sum))
                  
                  
                  if(F){
                    s3write_using(roi_i_df, 
                                  FUN = write_dta,
                                  bucket = "wb-blackmarble",
                                  object = paste0(geo_dataset_i, "/", geo_level_i, "/", unit_i, "/", ntl_dataset_i, "/", ntl_time_level_i, "/", date_i, ".dta"))
                    
                    # Parquet should be last, as we check whether the parquet file
                    # exists before using the file
                    s3write_using(roi_i_df, 
                                  FUN = write_parquet,
                                  bucket = "wb-blackmarble",
                                  object = paste0(geo_dataset_i, "/", geo_level_i, "/", unit_i, "/", ntl_dataset_i, "/", ntl_time_level_i, "/", date_i, ".parquet"))
                  }
                  
                  write_dta(roi_i_df,
                            paste0("~/Desktop/stata_ntl_data/", 
                                   geo_dataset_i, "/", geo_level_i, "/", unit_i, "/", ntl_dataset_i, "/", ntl_time_level_i, "/", date_i, ".dta"))
                  
                  write_parquet(roi_i_df,
                                paste0("~/Desktop/stata_ntl_data/", 
                                       geo_dataset_i, "/", geo_level_i, "/", unit_i, "/", ntl_dataset_i, "/", ntl_time_level_i, "/", date_i, ".parquet"))
                  
                }
                
                closeAllConnections()
                
              }
              
            }
          } # End: date_i
        } # End: ntl_time_level_i
      } # End: ntl_dataset_i
    } # End: unit_i
  } # End: geo_level_i
} # End: geo_dataset_i



