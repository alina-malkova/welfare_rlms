* Check regional credit market data
clear all
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Regional statistics/reg_credmarket.dta", clear

describe, short
describe

di _n "=== Year coverage ==="
tab year

di _n "=== Summary of key variables ==="
sum *, detail
