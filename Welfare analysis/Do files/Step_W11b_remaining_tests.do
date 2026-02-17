/*==============================================================================
  Step W11b - Remaining Behavioral Tests
==============================================================================*/

clear all
set more off

global project "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)"
global welfare "$project/Welfare analysis"
global data "$welfare/Data"

use "$data/welfare_panel_cbr.dta", clear
keep if analysis_sample == 1

* Create variables
gen double dlny_pos = max(dlny_lab, 0) if dlny_lab != .
gen double dlny_neg = min(dlny_lab, 0) if dlny_lab != .
gen double dlny_pos_x_inf = dlny_pos * informal
gen double dlny_neg_x_inf = dlny_neg * informal

global X_demo "age age2 i.female i.married i.educat hh_size"
global X_time "i.year"

*===============================================================================
* 1. NETWORK DENSITY PROXY
*===============================================================================

di as text _n "=============================================="
di as text    "  Test: Network Density Proxy"
di as text    "=============================================="

* Calculate regional informality rate by year
bysort region year: egen n_total = count(informal)
bysort region year: egen n_informal = total(informal)
gen reg_informal_rate = n_informal / n_total

* Create high informality region indicator
egen reg_informal_med = median(reg_informal_rate)
gen high_informal_region = (reg_informal_rate > reg_informal_med) if reg_informal_rate != .

di _n "=== High Informality Regions (Network Density) ==="
regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if high_informal_region == 1, vce(cluster idind)
local coef_high_inf = _b[dlny_neg_x_inf]
local se_high_inf = _se[dlny_neg_x_inf]
local n_high_inf = e(N)

di _n "=== Low Informality Regions ==="
regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if high_informal_region == 0, vce(cluster idind)
local coef_low_inf = _b[dlny_neg_x_inf]
local se_low_inf = _se[dlny_neg_x_inf]
local n_low_inf = e(N)

di _n "Network Density Results:"
di "  High informality region: δ⁻ = " %7.4f `coef_high_inf' " (SE: " %6.4f `se_high_inf' ") N=" %6.0f `n_high_inf'
di "  Low informality region:  δ⁻ = " %7.4f `coef_low_inf' " (SE: " %6.4f `se_low_inf' ") N=" %6.0f `n_low_inf'
di ""
di "  Network hypothesis: High < Low (better informal networks reduce penalty)"

*===============================================================================
* 2. LOSS AVERSION CALIBRATION
*===============================================================================

di as text _n "=============================================="
di as text    "  Loss Aversion Calibration"
di as text    "=============================================="

* Run main asymmetric regression to get coefficients
regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time, vce(cluster idind)

local beta_pos = _b[dlny_pos]
local beta_neg = _b[dlny_neg]
local delta_pos = _b[dlny_pos_x_inf]
local delta_neg = _b[dlny_neg_x_inf]

* For informal workers:
local inf_pos = `beta_pos' + `delta_pos'
local inf_neg = `beta_neg' + `delta_neg'

* Implied loss aversion ratio
* Under simple loss aversion: response to losses / response to gains = λ
local lambda_formal = abs(`beta_neg') / abs(`beta_pos')
local lambda_informal = abs(`inf_neg') / abs(`inf_pos')

di _n "Loss Aversion Calibration:"
di "  Formal workers:"
di "    Response to positive shocks: " %7.4f `beta_pos'
di "    Response to negative shocks: " %7.4f `beta_neg'
di "    Implied λ (|neg|/|pos|):      " %7.3f `lambda_formal'
di ""
di "  Informal workers:"
di "    Response to positive shocks: " %7.4f `inf_pos'
di "    Response to negative shocks: " %7.4f `inf_neg'
di "    Implied λ (|neg|/|pos|):      " %7.3f `lambda_informal'
di ""
di "  Standard loss aversion benchmark (Tversky & Kahneman): λ ≈ 2.00-2.50"
di "  Ratio of informal/formal λ: " %7.3f `lambda_informal'/`lambda_formal'

*===============================================================================
* 3. POST-2010 SELECTION TEST
*===============================================================================

di as text _n "=============================================="
di as text    "  Post-2010 Selection Test"
di as text    "=============================================="

* Test if remaining informal workers post-2010 differ
gen post2010 = (year >= 2010)

* Compare characteristics
di _n "=== Informal Worker Characteristics by Period ==="
ttest age if informal == 1, by(post2010)
ttest hh_size if informal == 1, by(post2010)

* Run regression by period
di _n "=== Pre-2010 ==="
regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo i.year if post2010 == 0, vce(cluster idind)
local coef_pre = _b[dlny_neg_x_inf]
local se_pre = _se[dlny_neg_x_inf]

di _n "=== Post-2010 ==="
regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo i.year if post2010 == 1, vce(cluster idind)
local coef_post = _b[dlny_neg_x_inf]
local se_post = _se[dlny_neg_x_inf]

di _n "Period Comparison:"
di "  Pre-2010:  δ⁻ = " %7.4f `coef_pre' " (SE: " %6.4f `se_pre' ")"
di "  Post-2010: δ⁻ = " %7.4f `coef_post' " (SE: " %6.4f `se_post' ")"

*===============================================================================
* SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  SUMMARY"
di as text    "=============================================="
di ""
di "Network Density:"
di "  High informality region: δ⁻ = " %7.4f `coef_high_inf'
di "  Low informality region:  δ⁻ = " %7.4f `coef_low_inf'
di ""
di "Loss Aversion Calibration:"
di "  Formal λ:   " %7.3f `lambda_formal'
di "  Informal λ: " %7.3f `lambda_informal'
di "  Ratio:      " %7.3f `lambda_informal'/`lambda_formal'
di ""
di "Period Comparison:"
di "  Pre-2010:  δ⁻ = " %7.4f `coef_pre'
di "  Post-2010: δ⁻ = " %7.4f `coef_post'
