* Setup Package

local run_ad_setup   0 
local run_ad_command 0
local run_ad_publish 0

* point a local to the folder where the package will be created
local myfolder "~/Documents/Github/blackmarble-stata"

* Package meta info
local pkg "blackmarble"
local aut "Robert Marty"
local des "This package queries satellite data"
local url "https://github.com/worldbank/blackmarble-stata/adodown"
local con "rmarty@worldbank.org"

* Setup ------------------------------------------------------------------------
if `run_ad_setup' == 1{

	* Set up adodown-styled package folder
	ad_setup, adfolder("`myfolder'") autoprompt    ///
		 name("`pkg'") author("`aut'") desc("`des'") ///
		 url("`url'") contact("`con'")
}
	 
* Make commands ----------------------------------------------------------------
if `run_ad_command' == 1{
	ad_command create query_bm, adf("`myfolder'") pkg("`pkg'")
	ad_command create query_shp, adf("`myfolder'") pkg("`pkg'")
	ad_command create query_geojson, adf("`myfolder'") pkg("`pkg'")
}

if `run_ad_publish' == 1{
	ad_publish create, adf("`myfolder'")
}

