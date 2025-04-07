*! version 0.1 20250314 Robert Marty rmarty@worldbank.org

cap program drop   query_geojson
    program define query_geojson

qui {

    version 14.1

    syntax, geo_dataset(string) adm_level(string) iso(string) file_name(string)
    
    // Construct the S3 URL based on the parameters
    local s3_url "https://wb-blackmarble.s3.us-east-2.amazonaws.com/`geo_dataset'/`adm_level'/`iso'/`iso'.geojson"
    
    // Display information about the download
    display as text "Downloading from: `s3_url'"
    display as text "Saving to: `file_name'"
    
    // Use Stata's copy command to download the file
    copy "`s3_url'" "`file_name'", replace
    
    // Check if the download was successful
    if _rc == 0 {
        display as result "Download successful: GeoJSON file saved to `file_name'"
    }
    else {
        display as error "Error downloading file. Check your parameters and internet connection."
    }
    
}
end
