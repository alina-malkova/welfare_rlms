* Check Sberbank triple interaction
clear all
set more off

global project "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)"
global welfare "$project/Welfare analysis"
global data "$welfare/Data"
global regdata "$project/Data/Regional statistics"

* Load crosswalk
use "$project/Comparative Economics/rlms_credit_workfile.dta", clear
keep site ter
bysort site: keep if _n == 1
tempfile crosswalk
save `crosswalk'

* Load regional data
use "$regdata/reg_credmarket.dta", clear
keep ter year sberpop
tempfile regcred
save `regcred'

* Load welfare panel and merge
use "$data/welfare_panel_cbr.dta", clear
keep if analysis_sample == 1
merge m:1 site using `crosswalk', keep(master match)
drop _merge
merge m:1 ter year using `regcred', keep(master match)
drop _merge

* Setup
global X_demo "age age2 i.female i.married i.educat hh_size"
global X_time "i.year"

* Create variables
gen double dlny_pos = max(dlny_lab, 0) if dlny_lab != .
gen double dlny_neg = min(dlny_lab, 0) if dlny_lab != .
gen double dlny_pos_x_inf = dlny_pos * informal
gen double dlny_neg_x_inf = dlny_neg * informal

* Standardize sberpop
egen sberpop_std = std(sberpop)

* Create triple interactions
gen double dlny_neg_x_sber = dlny_neg * sberpop_std
gen double dlny_neg_x_inf_x_sber = dlny_neg * informal * sberpop_std
gen double inf_x_sber = informal * sberpop_std

* Run triple interaction regression
di _n "=== Sberbank Triple Interaction (Continuous) ==="
regress dlnc dlny_pos dlny_neg informal sberpop_std ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    dlny_neg_x_sber inf_x_sber dlny_neg_x_inf_x_sber ///
    $X_demo $X_time, vce(cluster idind)

di _n "Triple interaction (continuous sberpop):"
di "  Coef on Δln(Y)⁻ × Informal × SberPop: " %7.4f _b[dlny_neg_x_inf_x_sber] ///
    " (SE: " %6.4f _se[dlny_neg_x_inf_x_sber] ")"
local tstat = _b[dlny_neg_x_inf_x_sber]/_se[dlny_neg_x_inf_x_sber]
di "  t-stat: " %6.2f `tstat'
di "  p-value: " %6.4f 2*ttail(e(df_r), abs(`tstat'))

* Also check correlation between sberpop and urban
di _n "=== Correlation sberpop with urban ==="
corr sberpop urban if dlnc != .
