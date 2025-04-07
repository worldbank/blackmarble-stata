*! version 0.1 20250314 Robert Marty rmarty@worldbank.org

cap program drop   query_bm
    program define query_bm

qui {

    version 14.1
	
    syntax, ///
		geo_dataset(string) ///
		adm_level(string) ///
		iso(string) ///
		date_unit(string) ///
		date_start(string) ///
		date_end(string) ///
		file_name(string)
		
	local sat_dataset = "blackmarble"
    
    // Step 1: Create a folder based on the file_name
    local base_folder = substr("`file_name'", 1, strlen("`file_name'") - 4)
    local folder_name = "`base_folder'_dta_individual_files"
    capture mkdir "`folder_name'"
    
    // Step 2: Process dates based on date_unit
    if "`date_unit'" == "annual" {
        // For annual data, treat dates as years
        numlist "`date_start'/`date_end'"
        local date_list = r(numlist)
        local date_format = "%Y"
    }
    else if "`date_unit'" == "monthly" {
        // For monthly data, generate a list of monthly dates
        local date_list = ""
        
        // Standardize date format for monthly data
        local start_date = "`date_start'"
        local end_date = "`date_end'"
        
        // If only year-month is provided, add day
        if length("`start_date'") == 7 {
            local start_date = "`start_date'-01"
        }
        if length("`end_date'") == 7 {
            local end_date = "`end_date'-01"
        }
        
        // Convert dates to Stata date format
        local start_date_num = date("`start_date'", "YMD")
        local end_date_num = date("`end_date'", "YMD")
        
        // Generate list of all months between start and end dates
        local current_date = `start_date_num'
        while `current_date' <= `end_date_num' {
            local date_formatted = string(`current_date', "%tdCY-N-D")
            local month_first_day = substr("`date_formatted'", 1, 8) + "01"
            local date_list = "`date_list' `month_first_day'"
            
            // Move to next month
            local current_date = mofd(`current_date') + 1
            local current_date = dofm(`current_date')
        }
        local date_format = "%Y-%m-%d"
    }
    else if "`date_unit'" == "daily" {
        // For daily data, generate a list of daily dates
        local date_list = ""
        
        // Convert dates to Stata date format
        local start_date_num = date("`date_start'", "YMD")
        local end_date_num = date("`date_end'", "YMD")
        
        // Generate list of all days between start and end dates
        local current_date = `start_date_num'
        while `current_date' <= `end_date_num' {
            local date_formatted = string(`current_date', "%tdCY-N-D")
            local date_list = "`date_list' `date_formatted'"
            
            // Move to next day
            local current_date = `current_date' + 1
        }
        local date_format = "%Y-%m-%d"
    }
    else {
        display as error "Invalid date_unit. Must be 'annual', 'monthly', or 'daily'."
        error 198
    }
    
    // Step 3: Process each country
    local iso_list = subinstr("`iso'", " ", " ", .)  // Ensure spaces are standardized
    local any_country_successful = 0
    
    // Create a temporary file to store the combined dataset
    tempfile combined_data
    clear
    save `combined_data', emptyok
    
    foreach country of local iso_list {
        // Clean up the country code (remove quotes if present)
        local country = subinstr("`country'", `"""', "", .)
        local country = subinstr("`country'", "'", "", .)
        
        // Create a subfolder for the country
        capture mkdir "`folder_name'/`country'"
        
        // Download available files from AWS
        local successfully_downloaded = ""
        foreach date_value of local date_list {
            // Format the date for the filename
            if "`date_unit'" == "annual" {
                local formatted_date = "`date_value'"
            }
            else {
                local formatted_date = "`date_value'"
            }
            
            // Use the correct S3 URL format with region
            local aws_url = "https://wb-blackmarble.s3.us-east-2.amazonaws.com/`geo_dataset'/`adm_level'/`country'/`sat_dataset'/`date_unit'/`formatted_date'.dta"
            local local_path = "`folder_name'/`country'/`formatted_date'.dta"
            
            // Create temporary path for download to avoid empty files
            tempfile temp_download
            
            // Check if the file already exists locally
            capture confirm file "`local_path'"
            if _rc {
                // File doesn't exist locally, try to download to temp first
                capture copy "`aws_url'" "`temp_download'"
                if _rc == 0 {
                    // Verify the file is not empty and is a valid Stata file
                    capture describe using "`temp_download'"
                    if _rc == 0 {
                        // Only after validation, copy to final location
                        copy "`temp_download'" "`local_path'", replace
                        display "Downloaded `formatted_date' data for `country'"
                        local successfully_downloaded = "`successfully_downloaded' `formatted_date'"
                    }
                    else {
                        display "Note: Data for `formatted_date' not available for `country' (invalid file)"
                    }
                }
                else {
                    display "Note: Data for `formatted_date' not available for `country'"
                }
            }
            else {
                // File exists locally, verify it's a valid Stata file
                capture describe using "`local_path'"
                if _rc == 0 {
                    // Check if file has actual data and isn't empty
                    preserve
                    capture use "`local_path'", clear
                    if _rc == 0 {
                        local obs = _N
                        if `obs' > 0 {
                            display "File for `formatted_date' already exists locally, skipping download"
                            local successfully_downloaded = "`successfully_downloaded' `formatted_date'"
                        }
                        else {
                            // File exists but is empty (has zero observations)
                            display "Existing file for `formatted_date' is empty, attempting to re-download"
                            capture erase "`local_path'"
                            
                            // Try to download again
                            capture copy "`aws_url'" "`temp_download'"
                            if _rc == 0 {
                                capture describe using "`temp_download'"
                                if _rc == 0 {
                                    // Only copy to final location if valid
                                    copy "`temp_download'" "`local_path'", replace
                                    display "Re-downloaded `formatted_date' data for `country'"
                                    local successfully_downloaded = "`successfully_downloaded' `formatted_date'"
                                }
                            }
                            else {
                                display "Note: Data for `formatted_date' not available for `country'"
                            }
                        }
                    }
                    restore
                }
                else {
                    // Invalid Stata file, remove it
                    display "Existing file for `formatted_date' is invalid, removing"
                    capture erase "`local_path'"
                }
            }
        }
        
        // Process the country's files if any were successfully downloaded
        local success_count = wordcount("`successfully_downloaded'")
        
        if `success_count' > 0 {
            // Instead of loading the first file and appending to it,
            // we'll load each file into a clean temporary dataset
            clear
            tempfile country_combined
            save `country_combined', emptyok
            local is_first = 1
            
            foreach date of local successfully_downloaded {
                // Load each file
                capture use "`folder_name'/`country'/`date'.dta", clear
                if _rc == 0 {
                    // Confirm the file has observations
                    local obs = _N
                    if `obs' > 0 {
                        // Add date identifier based on date_unit if it doesn't exist
                        if "`date_unit'" == "annual" {
                            capture confirm variable year
                            if _rc {
                                gen year = `date'
                            }
                        }
                        else if inlist("`date_unit'", "monthly", "daily") {
                            capture confirm variable date
                            if _rc {
                                gen date = date("`date'", "YMD")
                                format date %td
                            }
                        }
                        
                        // Add country identifier if it doesn't exist
                        capture confirm variable iso_code
                        if _rc {
                            gen iso_code = "`country'"
                        }
                        
                        // Append to the combined dataset
                        if `is_first' == 1 {
                            save `country_combined', replace
                            local is_first = 0
                        }
                        else {
                            tempfile temp_data
                            save `temp_data'
                            use `country_combined', clear
                            append using `temp_data'
                            save `country_combined', replace
                        }
                    }
                    else {
                        display "Warning: File for `date' has no observations, skipping"
                        capture erase "`folder_name'/`country'/`date'.dta"
                    }
                }
                else {
                    display "Warning: Cannot load file for `date', skipping"
                }
            }
            
            // Only proceed if we actually have data
            if `is_first' == 0 {
                // Now append this country's data to the overall combined dataset
                if `any_country_successful' == 0 {
                    use `country_combined', clear
                    save `combined_data', replace
                    local any_country_successful = 1
                }
                else {
                    use `combined_data', clear
                    append using `country_combined'
                    save `combined_data', replace
                }
            }
        }
        else {
            display "No valid files were found or downloaded for `country'."
        }
    }
    
    // Step 4: Save the final combined dataset if any countries were successful
    if `any_country_successful' == 1 {
        use `combined_data', clear
        
        // Optional: Sort the dataset by country and date
        if "`date_unit'" == "annual" {
            capture confirm variable iso_code
            if !_rc {
                capture confirm variable year
                if !_rc {
                    sort iso_code year
                }
            }
        }
        else if inlist("`date_unit'", "monthly", "daily") {
            capture confirm variable iso_code
            if !_rc {
                capture confirm variable date
                if !_rc {
                    sort iso_code date
                }
            }
        }
        
        // Save the final dataset
        save "`file_name'", replace
        display "Final combined dataset saved as `file_name'"
    }
    else {
        display "No valid files were found or downloaded for any country. Cannot create the dataset."
        error 601
    }
	
}
end
