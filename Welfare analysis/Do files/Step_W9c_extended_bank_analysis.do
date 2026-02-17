/*==============================================================================
  Step W9c - Extended Bank Access Analysis (2006-2016)

  Purpose:  Merge bank access variables from credit market workfile (2006-2016)
            and re-run bank access heterogeneity with dramatically more power

  Key variables from credit market workfile:
    - cindzsc: Credit accessibility index (z-score)
    - cindpca: Credit accessibility index (PCA)
    - credpop: Credit institutions per 10,000 population
    - bdistS: Distance to nearest Sberbank (km)
    - bdistO: Distance to nearest other bank (km)

  This extends coverage from 2019-2023 (~13,000 obs) to 2006-2016 (~100,000 obs)
==============================================================================*/

clear all
set more off

global project "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)"
global credit "$project/Comparative Economics"
global welfare "$project/Welfare analysis"
global data "$welfare/Data"
global tables "$welfare/Tables"
global logs "$welfare/Logs"

capture log close
log using "$logs/Step_W9c_extended_bank.log", replace

*===============================================================================
* 1. EXTRACT BANK ACCESS FROM CREDIT MARKET WORKFILE
*===============================================================================

di as text _n "=============================================="
di as text    "  Step 1: Extract Bank Access Variables"
di as text    "=============================================="

use "$credit/rlms_credit_workfile.dta", clear

* Keep key identifiers and bank access variables
keep idind year ///
    cindzsc cindpca ///           // Credit accessibility indices
    credpop credpop2 ///          // Regional credit institutions per capita
    sberpop lnsberpop ///         // Sberbank per capita
    bdistS bdistO lnbdistS lnbdistO ///  // Distances to banks
    sbercap sberoffice            // Community-level Sberbank

* Summarize key variables
di _n "=== Credit accessibility index (z-score) ==="
sum cindzsc, detail

di _n "=== Credit institutions per 10,000 pop ==="
sum credpop, detail

di _n "=== Distance to nearest Sberbank ==="
sum bdistS, detail

* Save for merging
tempfile bank_access
save `bank_access'

*===============================================================================
* 2. MERGE INTO WELFARE PANEL
*===============================================================================

di as text _n "=============================================="
di as text    "  Step 2: Merge into Welfare Panel"
di as text    "=============================================="

use "$data/welfare_panel_cbr.dta", clear
keep if analysis_sample == 1

* Merge bank access variables
merge m:1 idind year using `bank_access', keep(master match) nogen

* Check merge success
di _n "=== Observations with bank access data ==="
count if cindzsc != .
count if credpop != .

* Year distribution of bank access data
di _n "=== Year distribution of credit accessibility data ==="
tab year if cindzsc != .

*===============================================================================
* 3. CREATE BANK ACCESS INDICATORS
*===============================================================================

di as text _n "=============================================="
di as text    "  Step 3: Create Bank Access Indicators"
di as text    "=============================================="

* Create low credit access indicator (below median)
egen cma_median = median(cindzsc)
gen low_cma = (cindzsc < cma_median) if cindzsc != .
label variable low_cma "Low credit market access (below median CMA index)"

* Create terciles for more granular analysis
xtile cma_tercile = cindzsc, nq(3)
label define cma_tercile 1 "Low CMA" 2 "Medium CMA" 3 "High CMA"
label values cma_tercile cma_tercile

* Summary
tab low_cma informal, row

* Check sample size
di _n "=== Sample size with CMA data ==="
count if cindzsc != . & dlny_lab != . & dlnc != .

*===============================================================================
* 4. BANK ACCESS HETEROGENEITY ANALYSIS (EXTENDED DATA)
*===============================================================================

di as text _n "=============================================="
di as text    "  Step 4: Bank Access Heterogeneity Analysis"
di as text    "=============================================="

* Setup
global X_demo "age age2 i.female i.married i.educat hh_size n_children"
global X_time "i.year"

* Create asymmetric income changes
capture drop dlny_pos dlny_neg
gen double dlny_pos = max(dlny_lab, 0) if dlny_lab != .
gen double dlny_neg = min(dlny_lab, 0) if dlny_lab != .

* Interactions
capture drop dlny_pos_x_inf dlny_neg_x_inf
gen double dlny_pos_x_inf = dlny_pos * informal
gen double dlny_neg_x_inf = dlny_neg * informal

eststo clear

* --- 4a: Separate by credit accessibility ---
di _n "=== Low Credit Market Access ==="
eststo cma_low: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if low_cma == 1, vce(cluster idind)

local coef_low = _b[dlny_neg_x_inf]
local se_low = _se[dlny_neg_x_inf]
local n_low = e(N)

di _n "=== High Credit Market Access ==="
eststo cma_high: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if low_cma == 0, vce(cluster idind)

local coef_high = _b[dlny_neg_x_inf]
local se_high = _se[dlny_neg_x_inf]
local n_high = e(N)

* Display results
di _n "=============================================="
di "  KEY RESULTS: Credit Market Access Heterogeneity"
di "  (Extended data: 2006-2016)"
di "=============================================="
di ""
di "  δ⁻ (Low CMA):   " %7.4f `coef_low' " (SE: " %6.4f `se_low' ") N=" %8.0f `n_low'
di "  δ⁻ (High CMA):  " %7.4f `coef_high' " (SE: " %6.4f `se_high' ") N=" %8.0f `n_high'
di ""
if `coef_high' != 0 {
    di "  Ratio (Low/High):  " %7.2f `coef_low'/`coef_high'
}

* Table output
di _n "Table: Informality Penalty by Credit Market Access (Extended)"
esttab cma_low cma_high, ///
    keep(dlny_neg_x_inf dlny_pos_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitle("Low CMA" "High CMA") ///
    title("Informality Penalty by Credit Market Access (2006-2016)")

* --- 4b: Triple interaction with continuous CMA ---
di _n "=== Triple Interaction (Continuous CMA) ==="

* Standardize CMA for interpretability
egen cma_std = std(cindzsc)

* Create interactions
gen double dlny_neg_x_cma = dlny_neg * cma_std
gen double dlny_neg_x_inf_x_cma = dlny_neg * informal * cma_std
gen double inf_x_cma = informal * cma_std

eststo triple_cont: regress dlnc dlny_pos dlny_neg informal cma_std ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    dlny_neg_x_cma inf_x_cma dlny_neg_x_inf_x_cma ///
    $X_demo $X_time, vce(cluster idind)

di _n "Triple interaction (continuous CMA):"
di "  Coef on Δln(Y)⁻ × Informal × CMA: " %7.4f _b[dlny_neg_x_inf_x_cma] ///
    " (SE: " %6.4f _se[dlny_neg_x_inf_x_cma] ")"
di "  t-stat: " %6.2f _b[dlny_neg_x_inf_x_cma]/_se[dlny_neg_x_inf_x_cma]
test dlny_neg_x_inf_x_cma = 0
di "  p-value: " %6.4f r(p)

* --- 4c: By CMA terciles ---
di _n "=== By CMA Terciles ==="

forvalues t = 1/3 {
    eststo terc`t': regress dlnc dlny_pos dlny_neg informal ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        $X_demo $X_time if cma_tercile == `t', vce(cluster idind)
    local coef_t`t' = _b[dlny_neg_x_inf]
    local se_t`t' = _se[dlny_neg_x_inf]
    local n_t`t' = e(N)
}

di _n "Gradient across CMA terciles:"
di "  Tercile 1 (Low CMA):  δ⁻ = " %7.4f `coef_t1' " (SE: " %6.4f `se_t1' ") N=" %6.0f `n_t1'
di "  Tercile 2 (Med CMA):  δ⁻ = " %7.4f `coef_t2' " (SE: " %6.4f `se_t2' ") N=" %6.0f `n_t2'
di "  Tercile 3 (High CMA): δ⁻ = " %7.4f `coef_t3' " (SE: " %6.4f `se_t3' ") N=" %6.0f `n_t3'

* Export tables
esttab cma_low cma_high using "$tables/W9c_cma_extended.tex", replace ///
    keep(dlny_neg_x_inf dlny_pos_x_inf informal) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitle("Low CMA" "High CMA") ///
    booktabs fragment label ///
    addnotes("CMA = Credit Market Accessibility index from credit market paper" ///
             "Sample: 2006-2016, individual-year observations with CMA data")

esttab terc1 terc2 terc3 using "$tables/W9c_cma_terciles.tex", replace ///
    keep(dlny_neg_x_inf dlny_pos_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitle("Low CMA" "Medium CMA" "High CMA") ///
    booktabs fragment label

*===============================================================================
* 5. COMPARISON: 2019-2023 vs 2006-2016
*===============================================================================

di as text _n "=============================================="
di as text    "  Step 5: Compare Old vs New Bank Data"
di as text    "=============================================="

* Original 2019-2023 CBR analysis (for comparison)
di _n "=== 2019-2023 (CBR data) ==="
count if low_bank_access != .
eststo cbr_low: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if low_bank_access == 1, vce(cluster idind)
eststo cbr_high: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if low_bank_access == 0, vce(cluster idind)

di _n "=== Comparison of Results ==="
di ""
di "2019-2023 (CBR, N~13,000):"
estimates restore cbr_low
di "  Low bank access:  δ⁻ = " %7.4f _b[dlny_neg_x_inf] " (SE: " %6.4f _se[dlny_neg_x_inf] ")"
estimates restore cbr_high
di "  High bank access: δ⁻ = " %7.4f _b[dlny_neg_x_inf] " (SE: " %6.4f _se[dlny_neg_x_inf] ")"
di ""
di "2006-2016 (CMA index, N~" %6.0f `n_low' + `n_high' "):"
di "  Low CMA:  δ⁻ = " %7.4f `coef_low' " (SE: " %6.4f `se_low' ")"
di "  High CMA: δ⁻ = " %7.4f `coef_high' " (SE: " %6.4f `se_high' ")"

*===============================================================================
* SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  SUMMARY: Extended Bank Access Analysis"
di as text    "=============================================="
di ""
di "Sample size increased from ~13,000 to ~" %6.0f `n_low' + `n_high' " observations"
di "Year coverage extended from 2019-2023 to 2006-2016"
di ""
di "Key findings with extended data:"
di "  - Low CMA regions:  δ⁻ = " %7.4f `coef_low'
di "  - High CMA regions: δ⁻ = " %7.4f `coef_high'
di ""
di "Continuous CMA triple interaction: " %7.4f _b[dlny_neg_x_inf_x_cma] ///
   " (p = " %6.4f 2*ttail(e(df_r), abs(_b[dlny_neg_x_inf_x_cma]/_se[dlny_neg_x_inf_x_cma])) ")"

log close
