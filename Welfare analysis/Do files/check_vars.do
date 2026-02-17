* Check available variables
clear all
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Data/welfare_panel_cbr.dta", clear
describe, short
di _n "Variables containing 'sav', 'asset', 'loan', 'credit', 'help', 'food', 'buffer':"
ds *sav* *asset* *loan* *credit* *borrow* *help* *food* *buffer*
di _n "Variables containing 'dlny', 'shock', 'inf':"
ds *dlny* *shock* *inf*
di _n "Variables containing 'hh_':"
ds hh_*
