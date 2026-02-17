/*==============================================================================
  Step W10c - Regional Bank Access Analysis

  Purpose:  Test if informality penalty varies with regional bank access
==============================================================================*/

clear all
capture set maxvar 32767
do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close
log using "$logdir/Step_W10c_bank_access.log", replace

use "$data/welfare_panel_cbr.dta", clear
keep if analysis_sample == 1
xtset idind year

* Global controls
global X_demo "age age2 i.female i.married i.educat hh_size n_children"
global X_time "i.year"

di _n "=============================================="
di "  Regional Bank Access Analysis"
di "=============================================="

* Check variables
di _n "=== Low bank access variable ==="
tab low_bank_access, missing

* Create asymmetric income changes
capture drop dlny_pos dlny_neg
gen double dlny_pos = max(dlny_lab, 0) if dlny_lab != .
gen double dlny_neg = min(dlny_lab, 0) if dlny_lab != .

* Interactions
capture drop dlny_pos_x_inf dlny_neg_x_inf
gen double dlny_pos_x_inf = dlny_pos * informal
gen double dlny_neg_x_inf = dlny_neg * informal

eststo clear

* === Separate regressions by bank access ===
di _n "=== Low Bank Access Regions ==="
eststo bank_low: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if low_bank_access == 1, vce(cluster idind)

local coef_low = _b[dlny_neg_x_inf]
local se_low = _se[dlny_neg_x_inf]
local n_low = e(N)

di _n "=== High Bank Access Regions ==="
eststo bank_high: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if low_bank_access == 0, vce(cluster idind)

local coef_high = _b[dlny_neg_x_inf]
local se_high = _se[dlny_neg_x_inf]
local n_high = e(N)

* Display results
di _n "=============================================="
di "  KEY RESULTS: Bank Access Heterogeneity"
di "=============================================="
di ""
di "  δ⁻ (Low bank access):   " %7.4f `coef_low' " (SE: " %6.4f `se_low' ") N=" %6.0f `n_low'
di "  δ⁻ (High bank access):  " %7.4f `coef_high' " (SE: " %6.4f `se_high' ") N=" %6.0f `n_high'
di ""
if `coef_high' != 0 {
    di "  Ratio (Low/High):       " %7.2f `coef_low'/`coef_high'
}

* Table output
di _n "Table: Informality Penalty by Regional Bank Access"
esttab bank_low bank_high, ///
    keep(dlny_neg_x_inf dlny_pos_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitle("Low Bank Access" "High Bank Access") ///
    title("Informality Penalty by Regional Bank Access")

* Save to tex
esttab bank_low bank_high using "$tables/W10c_bank_access.tex", replace ///
    keep(dlny_neg_x_inf dlny_pos_x_inf informal) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitle("Low Bank Access" "High Bank Access") ///
    booktabs fragment label

* === Triple interaction specification ===
di _n "=== Triple Interaction Specification ==="

capture drop dlny_neg_x_low_bank dlny_neg_x_inf_x_low inf_x_low
gen double dlny_neg_x_low_bank = dlny_neg * low_bank_access
gen double dlny_neg_x_inf_x_low = dlny_neg * informal * low_bank_access
gen double inf_x_low = informal * low_bank_access

eststo triple: regress dlnc dlny_pos dlny_neg informal low_bank_access ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    dlny_neg_x_low_bank inf_x_low dlny_neg_x_inf_x_low ///
    $X_demo $X_time, vce(cluster idind)

di _n "Triple interaction coefficient (δ⁻ × Informal × LowBank):"
di "  Coef: " %7.4f _b[dlny_neg_x_inf_x_low] " (SE: " %6.4f _se[dlny_neg_x_inf_x_low] ")"

log close
