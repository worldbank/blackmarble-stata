    * This test file use utilities from the repkit package - https://github.com/worldbank/repkit
    * Test if package is installed, otherwise throw error telling user to install repkit
    cap which repkit
    if _rc == 111 {
        di as error "{pstd}You need to have {cmd:repkit} installed to run this reproducibility package. Click {stata ssc install repkit, replace} to do so.{p_end}"
    }

    ************************
    * Set up root paths (if not already set), and set up dev environment

    * Always important to version control built-in Stata functions
    version 14.1

    * Use reproot to manage root path
    reproot, project("blackmarble") roots("clone") prefix("blackmarble_")

    * Use locals for all non-root paths
    local testfldr "${blackmarble_clone}/src/tests"

    * Use the /dev-env folder as a dev environment
    cap mkdir    "`testfldr'/dev-env"
    repado using "`testfldr'/dev-env"

    * Make sure repkit is installed also in the dev environment
    cap which repkit
    if _rc == 111 ssc install repkit

    * Make sure the version of blackmarble in the dev environment is up to date with all edits.
    cap net uninstall blackmarble
    net install blackmarble, from("${blackmarble_clone}/src") replace

    ************************
    * Run tests

    * Test basic case of the command blackmarble
    blackmarble

    // Add more tests here...
