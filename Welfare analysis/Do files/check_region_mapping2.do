* Check if credit market workfile has both region codes
clear all
set more off

di "=== Credit market workfile - checking for region crosswalk ==="
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Comparative Economics/rlms_credit_workfile.dta", clear

di _n "=== All site/ter-like variables ==="
capture ds *ter*
if _rc == 0 ds *ter*
capture ds *site*  
if _rc == 0 ds *site*
capture ds *psu*
if _rc == 0 ds *psu*

di _n "=== Key variables ==="
describe site psu

di _n "=== Sample of site values ==="
tab site if year == 2010

di _n "=== Check reg_credmarket - list region names ==="
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Data/Regional statistics/reg_credmarket.dta", clear
keep if year == 2010
keep ter regname
list ter regname in 1/30, clean noobs
