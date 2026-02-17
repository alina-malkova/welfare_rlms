* Check available variables
clear all
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Data/welfare_panel_cbr.dta", clear
describe, short
di _n "All variable names:"
describe, varlist
di _n "Search for key patterns:"
capture ds *sav*
capture ds *loan*
capture ds *credit*
capture ds *help*
capture ds *food*
capture ds *buffer*
capture ds *shock*
di _n "Household variables (hh_*):"
capture noisily ds hh_*
di _n "Income and consumption:"
capture noisily ds *lny* *lnc* *dlny* *dlnc*
di _n "Informal related:"
capture noisily ds *inf*
di _n "Buffer related:"
capture noisily ds *buffer* *f12*
