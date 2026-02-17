* Check available variables - corrected version
clear all
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Data/welfare_panel_cbr.dta", clear
describe, short

di _n "=== Savings-related variables ==="
capture noisily ds *sav*

di _n "=== Loan-related variables ==="
capture noisily ds *loan*

di _n "=== Credit-related variables ==="
capture noisily ds *credit*

di _n "=== Help-related variables ==="
capture noisily ds *help*

di _n "=== Food-related variables ==="
capture noisily ds *food*

di _n "=== Buffer-related variables ==="
capture noisily ds *buffer*

di _n "=== Shock-related variables ==="
capture noisily ds *shock*

di _n "=== Household variables (hh_*) ==="
capture noisily ds hh_*

di _n "=== Income variables ==="
capture noisily ds *lny* *dlny*

di _n "=== Consumption variables ==="
capture noisily ds *lnc* *dlnc*

di _n "=== Informal-related variables ==="
capture noisily ds *inf*

di _n "=== f12 variables (buffer stock) ==="
capture noisily ds *f12*

di _n "=== Borrow-related variables ==="
capture noisily ds *borrow*

di _n "=== All variables starting with 'hh' ==="
capture noisily ds hh*

di _n "=== Insurance-related variables ==="
capture noisily ds *insur*

di _n "=== Welfare-related variables ==="
capture noisily ds *welf*
