/*==============================================================================
  Step W11 - Additional Behavioral Tests
  
  Tests:
  1. Reference point adaptation (recent consumption history)
  2. Subjective wellbeing response to shocks
  3. Heterogeneity by informality type
  4. Network density proxy
  5. Loss aversion calibration
==============================================================================*/

clear all
set more off

global project "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)"
global welfare "$project/Welfare analysis"
global data "$welfare/Data"

use "$data/welfare_panel_cbr.dta", clear
keep if analysis_sample == 1

*===============================================================================
* 1. REFERENCE POINT ADAPTATION TEST
*    Under Koszegi-Rabin, reference point adapts to recent experience
*    Workers with stable recent consumption should show stronger loss aversion
*===============================================================================

di as text _n "=============================================="
di as text    "  Test 1: Reference Point Adaptation"
di as text    "=============================================="

* Create lagged consumption volatility (past 2 periods)
sort idind year
by idind: gen L1_dlnc = dlnc[_n-1]
by idind: gen L2_dlnc = dlnc[_n-2]

* Measure recent consumption stability (SD of past 2 consumption changes)
egen recent_cons_sd = rowsd(L1_dlnc L2_dlnc)

* Create stable consumption indicator (below median volatility)
egen recent_cons_sd_med = median(recent_cons_sd)
gen stable_recent_cons = (recent_cons_sd < recent_cons_sd_med) if recent_cons_sd != .

* Create asymmetric income changes
gen double dlny_pos = max(dlny_lab, 0) if dlny_lab != .
gen double dlny_neg = min(dlny_lab, 0) if dlny_lab != .
gen double dlny_pos_x_inf = dlny_pos * informal
gen double dlny_neg_x_inf = dlny_neg * informal

* Setup controls
global X_demo "age age2 i.female i.married i.educat hh_size"
global X_time "i.year"

* Test: Does asymmetry differ by recent consumption stability?
di _n "=== Stable Recent Consumption (Reference Point Adaptation) ==="

regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if stable_recent_cons == 1, vce(cluster idind)
local coef_stable = _b[dlny_neg_x_inf]
local se_stable = _se[dlny_neg_x_inf]
local n_stable = e(N)

regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if stable_recent_cons == 0, vce(cluster idind)
local coef_volatile = _b[dlny_neg_x_inf]
local se_volatile = _se[dlny_neg_x_inf]
local n_volatile = e(N)

di _n "Reference Point Adaptation Results:"
di "  Stable recent consumption:   δ⁻ = " %7.4f `coef_stable' " (SE: " %6.4f `se_stable' ") N=" %6.0f `n_stable'
di "  Volatile recent consumption: δ⁻ = " %7.4f `coef_volatile' " (SE: " %6.4f `se_volatile' ") N=" %6.0f `n_volatile'
di ""
di "  Koszegi-Rabin prediction: Stable > Volatile (stronger reference point)"

*===============================================================================
* 2. SUBJECTIVE WELLBEING TEST
*    Check if informal workers report disproportionate happiness drops
*===============================================================================

di as text _n "=============================================="
di as text    "  Test 2: Subjective Wellbeing Response"
di as text    "=============================================="

* Check what wellbeing variables exist
capture ds m20* m3* j69*
di "Looking for subjective wellbeing variables..."

* m20 is usually life satisfaction in RLMS
capture confirm variable m20
if _rc == 0 {
    di "Found m20 (life satisfaction)"
    
    * Create change in wellbeing
    sort idind year
    by idind: gen dlnm20 = m20 - m20[_n-1] if m20 != . & m20[_n-1] != .
    
    * Test: Does wellbeing respond asymmetrically to income shocks?
    regress dlnm20 dlny_pos dlny_neg informal ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        $X_demo $X_time, vce(cluster idind)
    
    di _n "Wellbeing Response to Income Shocks:"
    di "  Formal positive shock (β⁺):  " %7.4f _b[dlny_pos]
    di "  Formal negative shock (β⁻):  " %7.4f _b[dlny_neg]
    di "  Informal × positive (δ⁺):    " %7.4f _b[dlny_pos_x_inf] " (SE: " %6.4f _se[dlny_pos_x_inf] ")"
    di "  Informal × negative (δ⁻):    " %7.4f _b[dlny_neg_x_inf] " (SE: " %6.4f _se[dlny_neg_x_inf] ")"
}
else {
    di "m20 not found, skipping wellbeing test"
}

*===============================================================================
* 3. HETEROGENEITY BY INFORMALITY TYPE
*===============================================================================

di as text _n "=============================================="
di as text    "  Test 3: Informality Type Heterogeneity"
di as text    "=============================================="

* Check what informality variables exist
capture ds informal* j11* j10*
di "Checking informality type variables..."

* j10 is often enterprise type, j11 registration status
capture confirm variable j10
if _rc == 0 {
    di "Found j10 (enterprise type)"
    tab j10 informal, missing
}

* Create self-employed indicator if possible
* j1 is usually employment status
capture confirm variable j1
if _rc == 0 {
    * Check for self-employment codes
    tab j1 if informal == 1
    
    * Create self-employed informal vs wage informal
    gen self_employed = (j1 >= 3 & j1 <= 5) if j1 != .  // Typical self-employment codes
    
    di _n "=== Self-Employed Informal ==="
    regress dlnc dlny_pos dlny_neg informal ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        $X_demo $X_time if self_employed == 1, vce(cluster idind)
    local coef_self = _b[dlny_neg_x_inf]
    local se_self = _se[dlny_neg_x_inf]
    local n_self = e(N)
    
    di _n "=== Wage Employee Informal ==="
    regress dlnc dlny_pos dlny_neg informal ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        $X_demo $X_time if self_employed == 0, vce(cluster idind)
    local coef_wage = _b[dlny_neg_x_inf]
    local se_wage = _se[dlny_neg_x_inf]
    local n_wage = e(N)
    
    di _n "Informality Type Heterogeneity:"
    di "  Self-employed: δ⁻ = " %7.4f `coef_self' " (SE: " %6.4f `se_self' ") N=" %6.0f `n_self'
    di "  Wage employee: δ⁻ = " %7.4f `coef_wage' " (SE: " %6.4f `se_wage' ") N=" %6.0f `n_wage'
}

*===============================================================================
* 4. NETWORK DENSITY PROXY
*    Do informal workers in high-informality regions show better smoothing?
*===============================================================================

di as text _n "=============================================="
di as text    "  Test 4: Network Density Proxy"
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
di "  Network hypothesis: High < Low (better informal networks)"

*===============================================================================
* 5. LOSS AVERSION CALIBRATION
*    Calculate implied λ from observed asymmetry
*===============================================================================

di as text _n "=============================================="
di as text    "  Test 5: Loss Aversion Calibration"
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
di "  Standard loss aversion benchmark (Tversky & Kahneman): λ ≈ 2.25"
di "  Ratio of informal/formal λ: " %7.3f `lambda_informal'/`lambda_formal'

*===============================================================================
* SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  SUMMARY: Behavioral Tests"
di as text    "=============================================="
di ""
di "1. Reference Point Adaptation:"
di "   Stable consumption: δ⁻ = " %7.4f `coef_stable'
di "   Volatile consumption: δ⁻ = " %7.4f `coef_volatile'
di ""
di "2. Network Density:"
di "   High informality region: δ⁻ = " %7.4f `coef_high_inf'
di "   Low informality region: δ⁻ = " %7.4f `coef_low_inf'
di ""
di "3. Loss Aversion Calibration:"
di "   Formal λ: " %7.3f `lambda_formal'
di "   Informal λ: " %7.3f `lambda_informal'
