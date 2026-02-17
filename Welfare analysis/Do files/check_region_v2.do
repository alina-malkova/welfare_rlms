* Comprehensive check of region variables
clear all
set more off

di "=== Welfare Panel Variables ==="
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Data/welfare_panel_cbr.dta", clear

di _n "=== All variable names (first 200) ==="
describe, simple

di _n "=== Checking site patterns ==="
capture ds *site*
if _rc == 0 ds *site*

di _n "=== Checking region patterns ==="
capture ds *region*
if _rc == 0 ds *region*

di _n "=== Checking psu patterns ==="  
capture ds *psu*
if _rc == 0 ds *psu*

di _n "=== Checking obl patterns ==="
capture ds *obl*
if _rc == 0 ds *obl*

di _n "=== Checking numeric region-like variables ===" 
* Check if these exist
foreach v in site psu oblast region ter idsite {
    capture confirm variable `v'
    if _rc == 0 {
        di "Found variable: `v'"
        sum `v', detail
    }
}

di _n "=== Crossref: reg_credmarket ter values ==="
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Data/Regional statistics/reg_credmarket.dta", clear
tab ter, nolab
