* Check additional variables for extended analysis
clear all
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Data/welfare_panel_cbr.dta", clear

di _n "=== Spouse-related variables ==="
capture noisily ds *spouse* *partner* *married*

di _n "=== Wealth/asset variables ==="
capture noisily ds *wealth* *asset* *property* *own*

di _n "=== F12A (buffer stock months) ==="
capture noisily describe f12_a f12_1a f12_1aa f12_1ab

di _n "=== Summary of f12_a ==="
capture noisily sum f12_a, detail

di _n "=== Tabulate f12_a ==="
capture noisily tab f12_a if f12_a < 99, missing

di _n "=== Bank access variables ==="
capture noisily ds *bank* *branch* *cbr* *access*

di _n "=== Regional variables ==="
capture noisily ds *region* *reg_*
