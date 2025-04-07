# Prep GADM 410

library(tidyverse)
library(sf)
library(aws.s3)
library(here)

geo_dataset_i <- "gadm_410"

#### Set AWS Keys for s# Bucket
api_keys <- read.csv("~/Dropbox/World Bank/Webscraping/Files for Server/api_keys.csv", stringsAsFactors=F)

Sys.setenv("AWS_ACCESS_KEY_ID" = api_keys$Key[(api_keys$Service %in% "AWS_ACCESS_KEY_ID") & (api_keys$Account %in% "robmarty3@gmail.com")],
           "AWS_SECRET_ACCESS_KEY" = api_keys$Key[(api_keys$Service %in% "AWS_SECRET_ACCESS_KEY") & (api_keys$Account %in% "robmarty3@gmail.com")],
           "AWS_DEFAULT_REGION" = "us-east-2")


adm_level_i <- "ADM_1"

upload_shapefile_to_s3 <- function(sf_object, 
                                   geo_dataset, 
                                   geo_level, 
                                   id, 
                                   bucket = "wb-blackmarble") {
  
  # Create a temporary directory
  temp_dir <- tempdir()
  base_filename <- file.path(temp_dir, id)
  
  # Write the shapefile to the temporary directory
  write_sf(sf_object, paste0(base_filename, ".shp"))
  
  # List all files that were created (all shapefile components)
  shp_files <- list.files(temp_dir, pattern = paste0("^", id, "\\.(shp|dbf|prj|shx)$"), full.names = TRUE)
  
  # Upload each component to S3
  for (file in shp_files) {
    # Extract the file extension
    ext <- tools::file_ext(file)
    
    # Construct the S3 path
    s3_path <- paste0(geo_dataset, "/", geo_level, "/", id, "/", id, ".", ext)
    
    # Upload the file to S3
    put_object(
      file = file,
      object = s3_path,
      bucket = bucket
    )
    
    cat("Uploaded:", s3_path, "to bucket:", bucket, "\n")
  }
  
  # Optional: clean up temporary files
  unlink(shp_files)
  
  return(TRUE)
}

for(geo_level_i in c("ADM_0",
                     "ADM_1",
                     "ADM_2")){
  
  print(paste(geo_level_i, "-------------------------------------------------"))
  
  dir.create(here("data-to-s3", "data", "gadm_410", geo_level_i))
  
  roi_sf <- read_sf(here("data-to-s3", "data", "gadm_410", "gadm_410-levels.gpkg"),
                    geo_level_i)
  
  id_name <- "GID_0"
  
  ids_vec <- unique(roi_sf[[id_name]])
  
  ## Remove certain countries
  ids_vec <- ids_vec[ids_vec != "ATA"] # Antarctica
  
  for(id_i in unique(roi_sf[[id_name]])){
    
    print(id_i)
    
    roi_i_sf <- roi_sf[roi_sf[[id_name]] == id_i,]
    roi_i_sf <- roi_i_sf %>% st_make_valid()
    
    write_sf(roi_i_sf, here("data-to-s3", "data", "gadm_410", geo_level_i, 
                            paste0(id_i, ".geojson")),
             delete_dsn = T)
    
    saveRDS(roi_i_sf, here("data-to-s3", "data", "gadm_410", geo_level_i, 
                           paste0(id_i, ".Rds")))
    
    # Send to s3 ---------------------------------------------------------------
    # Make folders in s3
    if(F){
      put_object(file = raw(),
                 object = paste0(geo_dataset_i, "/"),
                 bucket = "wb-blackmarble")
      
      put_object(file = raw(),
                 object = paste0(geo_dataset_i, "/", geo_level_i, "/"),
                 bucket = "wb-blackmarble")
      
      put_object(file = raw(),
                 object = paste0(geo_dataset_i, "/", geo_level_i, "/", id_i, "/"),
                 bucket = "wb-blackmarble")
      
      ## Send to s3
      s3write_using(roi_i_sf,
                    FUN = write_sf,
                    object = paste0(geo_dataset_i, "/", geo_level_i, "/", id_i, "/", 
                                    paste0(id_i, ".geojson")),
                    bucket = "wb-blackmarble")
      
      upload_shapefile_to_s3(
        sf_object = roi_i_sf,
        geo_dataset = geo_dataset_i,
        geo_level = geo_level_i,
        id = id_i,
        bucket = "wb-blackmarble"
      )
    }
    
  }
  
}