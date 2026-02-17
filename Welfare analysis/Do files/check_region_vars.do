* Check region variables in welfare panel
clear all
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Data/welfare_panel_cbr.dta", clear

di _n "=== All variable names ==="
describe, varlist

di _n "=== Looking for region-like variables ==="
ds *reg* *ter* *obl* *site* *psu* *okrug*
