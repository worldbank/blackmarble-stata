*! version 0.1 20250314 Robert Marty rmarty@worldbank.org

cap program drop query_shp
program define query_shp

qui {
    version 14.1
    syntax, geo_dataset(string) adm_level(string) iso(string) file_name(string) [replace]
    
    // Extract base filename without extension
    local base_file = subinstr("`file_name'", ".shp", "", .)
    local base_file = subinstr("`base_file'", ".shx", "", .)
    local base_file = subinstr("`base_file'", ".prj", "", .)
    local base_file = subinstr("`base_file'", ".dbf", "", .)
    
    // Extract directory from file_name
    local last_slash = max(strpos(strreverse("`file_name'"), "/"), strpos(strreverse("`file_name'"), "\"))
    if `last_slash' > 0 {
        local last_slash = length("`file_name'") - `last_slash' + 1
        local dest_folder = substr("`file_name'", 1, `last_slash'-1)
        // Create destination folder if it doesn't exist
        capture mkdir "`dest_folder'"
    }
    
    // Base S3 URL without file extension
    local s3_base_url "https://wb-blackmarble.s3.us-east-2.amazonaws.com/`geo_dataset'/`adm_level'/`iso'/`iso'"
    
    // shp
    local s3_url "`s3_base_url'.shp"
    local dest_file "`base_file'.shp"
    capture copy "`s3_url'" "`dest_file'", `replace'
    
    // shx
    local s3_url "`s3_base_url'.shx"
    local dest_file "`base_file'.shx"
    capture copy "`s3_url'" "`dest_file'", `replace'
    
    // prj
    local s3_url "`s3_base_url'.prj"
    local dest_file "`base_file'.prj"
    capture copy "`s3_url'" "`dest_file'", `replace'
    
    // dbf
    local s3_url "`s3_base_url'.dbf"
    local dest_file "`base_file'.dbf"
    capture copy "`s3_url'" "`dest_file'", `replace'
    
    // Check if the download was successful
    if _rc != 0 {
        display as error "Error downloading file: `s3_url'"
        display as error "Check your parameters and internet connection."
        local success = 0
    }
    else {
        local success = 1
    }
    
    // Final success message
    if `success' == 1 {
        display as result "Download successful: Complete shapefile set saved to `base_file'.*"
    }
}
end
