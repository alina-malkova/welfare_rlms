* Check regional credit market data from Data folder
clear all

di "=== reg_credmarket.dta ==="
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Data/Regional statistics/reg_credmarket.dta", clear
describe
tab year
sum *

di _n "=== reg_common.dta ==="
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Data/Regional statistics/reg_common.dta", clear
describe
tab year
