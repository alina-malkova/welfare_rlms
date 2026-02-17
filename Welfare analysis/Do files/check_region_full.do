* Comprehensive check of region variables
clear all
set more off

di "=== Welfare Panel Variables ==="
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Data/welfare_panel_cbr.dta", clear

di _n "=== Looking for region-like variables ==="
ds *site* *region* *reg* *psu* *okrug* *obl* *ter*

di _n "=== All variable names ==="
describe, simple

di _n "=== Checking site variable ==="
capture sum site
if _rc == 0 {
    tab site if year == 2010
}

di _n "=== Checking psu variable ==="
capture sum psu
if _rc == 0 {
    sum psu
}

di _n "=== Checking okrug variable ==="
capture sum okrug  
if _rc == 0 {
    tab okrug if year == 2010
}

di _n "=== Cross-reference with credit market workfile ==="
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Comparative Economics/rlms_credit_workfile.dta", clear
ds *site* *region* *reg* *psu* *okrug* *obl* *ter*
