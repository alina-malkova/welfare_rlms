* Check if credit market workfile has both region codes
clear all
set more off

di "=== Credit market workfile - checking for region crosswalk ==="
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Comparative Economics/rlms_credit_workfile.dta", clear

di _n "=== Region-like variables ==="
capture ds *ter* *region* *site*
ds *ter* *region* *site*

di _n "=== Checking if ter exists ==="
capture sum ter
if _rc == 0 {
    di "ter exists!"
    sum ter
}
else {
    di "ter does NOT exist"
}

di _n "=== Checking region variable ==="
sum region site

di _n "=== Sample of region and site values ==="
list region site in 1/20

di _n "=== Check if reg_credmarket has regname ==="
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Data/Regional statistics/reg_credmarket.dta", clear
di "Region names:"
tab regname if year == 2010, missing
