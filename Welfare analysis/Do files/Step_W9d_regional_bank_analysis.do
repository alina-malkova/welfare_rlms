/*==============================================================================
  Step W9d - Regional Bank Access Analysis (1996-2016)

  Purpose:  Merge regional credit market data from CBR Excel files
            and run bank access heterogeneity analysis with full coverage

  Data source: /Data/Regional statistics/reg_credmarket.dta
    - credpop: Credit institutions per 10,000 population
    - sberpop: Sberbank offices per 10,000 population
    - Coverage: 1996-2016, 81 regions

  Mapping: Uses site-ter crosswalk from credit market workfile
==============================================================================*/

clear all
set more off

global project "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)"
global welfare "$project/Welfare analysis"
global data "$welfare/Data"
global tables "$welfare/Tables"
global logs "$welfare/Logs"
global regdata "$project/Data/Regional statistics"

capture log close
log using "$logs/Step_W9d_regional_bank.log", replace

*===============================================================================
* 1. CREATE SITE-TER CROSSWALK FROM CREDIT MARKET WORKFILE
*===============================================================================

di as text _n "=============================================="
di as text    "  Step 1: Create Site-Ter Crosswalk"
di as text    "=============================================="

use "$project/Comparative Economics/rlms_credit_workfile.dta", clear

* Keep site and ter
keep site ter
bysort site: keep if _n == 1
sort site

di _n "=== Site-ter crosswalk ==="
count
sum site ter

* Save crosswalk
tempfile crosswalk
save `crosswalk'

*===============================================================================
* 2. LOAD AND PREPARE REGIONAL CREDIT MARKET DATA
*===============================================================================

di as text _n "=============================================="
di as text    "  Step 2: Load Regional Credit Market Data"
di as text    "=============================================="

use "$regdata/reg_credmarket.dta", clear

* Keep key variables
keep ter year credpop sberpop crednum sbernum

* Summarize
di _n "=== Credit institutions per 10,000 population ==="
sum credpop, detail

di _n "=== Sberbank offices per 10,000 population ==="
sum sberpop, detail

di _n "=== Year coverage ==="
tab year

* Save for merging
tempfile regcred
save `regcred'

*===============================================================================
* 3. LOAD WELFARE PANEL AND MERGE VIA SITE-TER CROSSWALK
*===============================================================================

di as text _n "=============================================="
di as text    "  Step 3: Merge into Welfare Panel"
di as text    "=============================================="

use "$data/welfare_panel_cbr.dta", clear
keep if analysis_sample == 1

di _n "=== Original welfare panel ==="
count

* First merge: add ter via site crosswalk
merge m:1 site using `crosswalk', keep(master match)
tab _merge
drop _merge

di _n "=== After adding ter variable ==="
sum ter
count if ter != .

* Second merge: add regional credit data via ter and year
merge m:1 ter year using `regcred', keep(master match)
di _n "=== Merge results ==="
tab _merge
drop _merge

* Check merge success
di _n "=== Observations with credit data ==="
count if credpop != .
count if sberpop != .

di _n "=== Year distribution of credit data ==="
tab year if credpop != .

*===============================================================================
* 4. CREATE BANK ACCESS INDICATORS
*===============================================================================

di as text _n "=============================================="
di as text    "  Step 4: Create Bank Access Indicators"
di as text    "=============================================="

* Create low credit access indicator (below median)
egen credpop_med = median(credpop)
gen low_credpop = (credpop < credpop_med) if credpop != .
label variable low_credpop "Low credit access (below median credpop)"

* Similarly for Sberbank
egen sberpop_med = median(sberpop)
gen low_sberpop = (sberpop < sberpop_med) if sberpop != .
label variable low_sberpop "Low Sberbank access (below median)"

* Create terciles
xtile credpop_tercile = credpop, nq(3)
label define credpop_tercile 1 "Low" 2 "Medium" 3 "High"
label values credpop_tercile credpop_tercile

* Summary
di _n "=== Low credit access by informality ==="
tab low_credpop informal, row

di _n "=== Sample size with credit data ==="
count if credpop != . & dlny_lab != . & dlnc != .

*===============================================================================
* 5. BANK ACCESS HETEROGENEITY ANALYSIS
*===============================================================================

di as text _n "=============================================="
di as text    "  Step 5: Bank Access Heterogeneity Analysis"
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

* --- 5a: Separate by credit access (binary) ---
di _n "=== Low Credit Access Regions ==="
eststo cred_low: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if low_credpop == 1, vce(cluster idind)

local coef_low = _b[dlny_neg_x_inf]
local se_low = _se[dlny_neg_x_inf]
local n_low = e(N)

di _n "=== High Credit Access Regions ==="
eststo cred_high: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if low_credpop == 0, vce(cluster idind)

local coef_high = _b[dlny_neg_x_inf]
local se_high = _se[dlny_neg_x_inf]
local n_high = e(N)

* Display results
di _n "=============================================="
di "  KEY RESULTS: Credit Access Heterogeneity"
di "  (Regional CBR data: 1996-2016)"
di "=============================================="
di ""
di "  δ⁻ (Low credit access):   " %7.4f `coef_low' " (SE: " %6.4f `se_low' ") N=" %8.0f `n_low'
di "  δ⁻ (High credit access):  " %7.4f `coef_high' " (SE: " %6.4f `se_high' ") N=" %8.0f `n_high'
di ""
if `coef_high' != 0 {
    di "  Ratio (Low/High):  " %7.2f `coef_low'/`coef_high'
}

* Table output
di _n "Table: Informality Penalty by Credit Access"
esttab cred_low cred_high, ///
    keep(dlny_neg_x_inf dlny_pos_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitle("Low Credit Access" "High Credit Access") ///
    title("Informality Penalty by Regional Credit Access (CBR 1996-2016)")

* --- 5b: Triple interaction with continuous credpop ---
di _n "=== Triple Interaction (Continuous) ==="

* Standardize for interpretability
egen credpop_std = std(credpop)

* Create interactions
gen double dlny_neg_x_cred = dlny_neg * credpop_std
gen double dlny_neg_x_inf_x_cred = dlny_neg * informal * credpop_std
gen double inf_x_cred = informal * credpop_std

eststo triple: regress dlnc dlny_pos dlny_neg informal credpop_std ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    dlny_neg_x_cred inf_x_cred dlny_neg_x_inf_x_cred ///
    $X_demo $X_time, vce(cluster idind)

di _n "Triple interaction (continuous credpop):"
di "  Coef on Δln(Y)⁻ × Informal × CredPop: " %7.4f _b[dlny_neg_x_inf_x_cred] ///
    " (SE: " %6.4f _se[dlny_neg_x_inf_x_cred] ")"
local tstat = _b[dlny_neg_x_inf_x_cred]/_se[dlny_neg_x_inf_x_cred]
di "  t-stat: " %6.2f `tstat'
di "  p-value: " %6.4f 2*ttail(e(df_r), abs(`tstat'))

local triple_coef = _b[dlny_neg_x_inf_x_cred]
local triple_se = _se[dlny_neg_x_inf_x_cred]
local triple_t = `tstat'

* --- 5c: By terciles ---
di _n "=== By Credit Access Terciles ==="

forvalues t = 1/3 {
    eststo terc`t': regress dlnc dlny_pos dlny_neg informal ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        $X_demo $X_time if credpop_tercile == `t', vce(cluster idind)
    local coef_t`t' = _b[dlny_neg_x_inf]
    local se_t`t' = _se[dlny_neg_x_inf]
    local n_t`t' = e(N)
}

di _n "Gradient across credit access terciles:"
di "  Tercile 1 (Low):    δ⁻ = " %7.4f `coef_t1' " (SE: " %6.4f `se_t1' ") N=" %6.0f `n_t1'
di "  Tercile 2 (Medium): δ⁻ = " %7.4f `coef_t2' " (SE: " %6.4f `se_t2' ") N=" %6.0f `n_t2'
di "  Tercile 3 (High):   δ⁻ = " %7.4f `coef_t3' " (SE: " %6.4f `se_t3' ") N=" %6.0f `n_t3'

* --- 5d: Using Sberbank offices ---
di _n "=== Using Sberbank Offices per Capita ==="

eststo sber_low: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if low_sberpop == 1, vce(cluster idind)

local coef_sber_low = _b[dlny_neg_x_inf]
local se_sber_low = _se[dlny_neg_x_inf]

eststo sber_high: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if low_sberpop == 0, vce(cluster idind)

local coef_sber_high = _b[dlny_neg_x_inf]
local se_sber_high = _se[dlny_neg_x_inf]

di _n "Sberbank offices results:"
di "  Low Sberbank:  δ⁻ = " %7.4f `coef_sber_low' " (SE: " %6.4f `se_sber_low' ")"
di "  High Sberbank: δ⁻ = " %7.4f `coef_sber_high' " (SE: " %6.4f `se_sber_high' ")"

* Export tables
esttab cred_low cred_high using "$tables/W9d_credpop_binary.tex", replace ///
    keep(dlny_neg_x_inf dlny_pos_x_inf informal) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitle("Low Credit Access" "High Credit Access") ///
    booktabs fragment label ///
    addnotes("Credit access = credit institutions per 10,000 population (CBR)" ///
             "Sample: 1996-2016")

esttab terc1 terc2 terc3 using "$tables/W9d_credpop_terciles.tex", replace ///
    keep(dlny_neg_x_inf dlny_pos_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitle("Low" "Medium" "High") ///
    booktabs fragment label

*===============================================================================
* SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  SUMMARY: Regional Bank Access Analysis"
di as text    "  (CBR Data 1996-2016)"
di as text    "=============================================="
di ""
di "Total sample with credit data: N = " %8.0f `n_low' + `n_high'
di ""
di "Binary split (credit institutions per capita):"
di "  Low credit access:  δ⁻ = " %7.4f `coef_low' " (SE: " %6.4f `se_low' ")"
di "  High credit access: δ⁻ = " %7.4f `coef_high' " (SE: " %6.4f `se_high' ")"
di ""
di "Terciles:"
di "  Low:    δ⁻ = " %7.4f `coef_t1'
di "  Medium: δ⁻ = " %7.4f `coef_t2'
di "  High:   δ⁻ = " %7.4f `coef_t3'
di ""
di "Triple interaction coefficient: " %7.4f `triple_coef'
di "  t-statistic: " %6.2f `triple_t'
di "  (negative = penalty decreases with more credit access)"

log close

