* Check credit market workfile for bank access variables
clear all
use "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Comparative Economics/rlms_credit_workfile.dta", clear
describe, short

di _n "=== Bank-related variables ==="
ds *bank* *sber* *branch* *credit* *cma*

di _n "=== Summary of key credit variables ==="
sum *bank* *sber* *branch*, detail

di _n "=== Year coverage ==="
tab year
