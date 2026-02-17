* Check ter-region mapping from credit market workfile
clear all
set more off

di "=== Credit market workfile - ter values ==="
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Comparative Economics/rlms_credit_workfile.dta", clear

di _n "=== ter summary ==="
sum ter

di _n "=== Unique ter values ==="
tab ter if year == 2010, nolab

di _n "=== Relationship between site and ter ==="
table site ter if year == 2010

di _n "=== Create crosswalk: site to ter ==="
keep site ter
bysort site: keep if _n == 1
sort site
list site ter, clean noobs

di _n "=== Save crosswalk ==="
save "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Data/site_ter_crosswalk.dta", replace
