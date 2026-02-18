*===============================================================================
* R8: Regression Kink Design around Δln(Y) = 0
*===============================================================================
*
* Problem: The standard asymmetric specification assumes a sharp kink at
* exactly Δln(Y) = 0. This is a strong assumption.
*
* Solution: Regression Kink Design (RKD) to test whether there is genuinely
* a discontinuity in the slope of consumption response at zero.
*
* Test: Is there a kink in the consumption-income relationship at Δln(Y) = 0?
* Compare slopes just above and below zero.
*
* Author: Generated for revision
* Date: February 2026
*===============================================================================

clear all
set more off
capture log close

* Set globals directly (for batch mode compatibility)
global base "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/_Research/Credit_Market/Credit market (1)"
global welfare "${base}/Welfare analysis"
global dodir "${welfare}/Do files"
global data "${welfare}/Data"
global results "${welfare}/Results"
global tables "${welfare}/Tables"
global figures "${welfare}/Figures"
global logdir "${welfare}/Logs"

* Start log
log using "${logdir}/R8_regression_kink.log", replace text

di as text _n "=============================================="
di as text    "  R8: Regression Kink Design"
di as text    "      (Testing Kink at Δln(Y) = 0)"
di as text    "=============================================="

*===============================================================================
* 0. SETUP AND DATA
*===============================================================================

* Load data
capture use "$data/welfare_panel_cbr.dta", clear
if _rc != 0 {
    use "$data/welfare_panel_shocks.dta", clear
}

keep if analysis_sample == 1 & !missing(dlnc, dlny_lab)
xtset idind year

count
local N_total = r(N)
di as text "Full sample: N = `N_total'"

*===============================================================================
* 1. VISUALIZE RAW DATA
*===============================================================================

di as text _n "=============================================="
di as text    "  1. Visualize Consumption-Income Relationship"
di as text    "=============================================="

* Local polynomial smooth by informality
twoway (lpoly dlnc dlny_lab if informal == 0, bw(0.1) lcolor(blue) lwidth(medthick)) ///
       (lpoly dlnc dlny_lab if informal == 1, bw(0.1) lcolor(red) lwidth(medthick)), ///
       xline(0, lcolor(black) lpattern(dash)) ///
       xtitle("Δln(Y) (Income Change)") ytitle("Δln(C) (Consumption Change)") ///
       title("Consumption Response to Income Changes") ///
       legend(order(1 "Formal" 2 "Informal") position(6)) ///
       scheme(s2color) ///
       note("Local polynomial smoothing, bandwidth = 0.1")

graph export "${figures}/R8_lpoly_consumption_income.png", replace width(1200)
graph save "${figures}/R8_lpoly_consumption_income.gph", replace

*===============================================================================
* 2. DEFINE BANDWIDTH AND LOCAL SAMPLES
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Define Bandwidth"
di as text    "=============================================="

* Bandwidth for RKD
* Start with h = 0.10 (±10% income change)
local h = 0.10

* Sample in bandwidth
gen byte in_bandwidth = (abs(dlny_lab) <= `h')
count if in_bandwidth == 1
local N_bw = r(N)
di as text "Bandwidth h = `h'"
di as text "Sample within bandwidth: N = `N_bw'"

* Check balance on either side
count if dlny_lab > 0 & dlny_lab <= `h'
local N_above = r(N)
count if dlny_lab < 0 & dlny_lab >= -`h'
local N_below = r(N)
di as text "  Observations just above zero: `N_above'"
di as text "  Observations just below zero: `N_below'"

*===============================================================================
* 3. RKD ESTIMATION: LOCAL LINEAR REGRESSION
*===============================================================================

di as text _n "=============================================="
di as text    "  3. RKD Estimation"
di as text    "=============================================="

* Running variable centered at zero
gen double running = dlny_lab

* Interaction for kink
gen double running_pos = max(running, 0)
gen double running_neg = min(running, 0)

* Local linear regression: different slopes above and below zero
* Full sample
di as text "--- Full Sample ---"
regress dlnc running_pos running_neg if in_bandwidth == 1, vce(cluster idind)

local slope_pos_full = _b[running_pos]
local slope_neg_full = _b[running_neg]
local kink_full = `slope_pos_full' - `slope_neg_full'

* SE via delta method
nlcom _b[running_pos] - _b[running_neg]
matrix KINK = r(b)
matrix V_KINK = r(V)
local kink_se_full = sqrt(V_KINK[1,1])
local t_kink_full = `kink_full' / `kink_se_full'
local p_kink_full = 2 * (1 - normal(abs(`t_kink_full')))

di as text "Full sample:"
di as text "  Slope above zero (β⁺): " %7.4f `slope_pos_full'
di as text "  Slope below zero (β⁻): " %7.4f `slope_neg_full'
di as text "  Kink (β⁺ - β⁻):        " %7.4f `kink_full' " (SE " %6.4f `kink_se_full' ")"
di as text "  t = " %5.2f `t_kink_full' ", p = " %5.3f `p_kink_full'

* By informality
foreach inf in 0 1 {
    if `inf' == 0 {
        di as text _n "--- Formal Workers ---"
    }
    else {
        di as text _n "--- Informal Workers ---"
    }

    quietly regress dlnc running_pos running_neg if in_bandwidth == 1 & informal == `inf', vce(cluster idind)

    local slope_pos_`inf' = _b[running_pos]
    local slope_neg_`inf' = _b[running_neg]

    quietly nlcom _b[running_pos] - _b[running_neg]
    matrix KINK_`inf' = r(b)
    matrix V_KINK_`inf' = r(V)
    local kink_`inf' = KINK_`inf'[1,1]
    local kink_se_`inf' = sqrt(V_KINK_`inf'[1,1])
    local t_kink_`inf' = `kink_`inf'' / `kink_se_`inf''
    local p_kink_`inf' = 2 * (1 - normal(abs(`t_kink_`inf''')))

    di as text "  Slope above zero (β⁺): " %7.4f `slope_pos_`inf''
    di as text "  Slope below zero (β⁻): " %7.4f `slope_neg_`inf''
    di as text "  Kink (β⁺ - β⁻):        " %7.4f `kink_`inf'' " (SE " %6.4f `kink_se_`inf'' ")"
    di as text "  t = " %5.2f `t_kink_`inf'' ", p = " %5.3f `p_kink_`inf''
}

* Difference in kinks: formal vs informal
local diff_kink = `kink_1' - `kink_0'
local se_diff_kink = sqrt(`kink_se_0'^2 + `kink_se_1'^2)
local t_diff_kink = `diff_kink' / `se_diff_kink'
local p_diff_kink = 2 * (1 - normal(abs(`t_diff_kink')))

di as text _n "Difference in kink (Informal - Formal):"
di as text "  Δ(kink) = " %7.4f `diff_kink' " (SE " %6.4f `se_diff_kink' ")"
di as text "  t = " %5.2f `t_diff_kink' ", p = " %5.3f `p_diff_kink'

*===============================================================================
* 4. BANDWIDTH SENSITIVITY
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Bandwidth Sensitivity"
di as text    "=============================================="

* Test multiple bandwidths
tempname BW_SENS
matrix `BW_SENS' = J(5, 4, .)
matrix colnames `BW_SENS' = "h" "kink_formal" "kink_informal" "diff"
matrix rownames `BW_SENS' = "h=0.05" "h=0.10" "h=0.15" "h=0.20" "h=0.25"

local row = 0
foreach h_val in 0.05 0.10 0.15 0.20 0.25 {
    local ++row
    matrix `BW_SENS'[`row', 1] = `h_val'

    * Formal
    capture quietly {
        regress dlnc running_pos running_neg if abs(dlny_lab) <= `h_val' & informal == 0, vce(cluster idind)
        nlcom _b[running_pos] - _b[running_neg]
        matrix TEMP = r(b)
    }
    if _rc == 0 {
        matrix `BW_SENS'[`row', 2] = TEMP[1,1]
    }

    * Informal
    capture quietly {
        regress dlnc running_pos running_neg if abs(dlny_lab) <= `h_val' & informal == 1, vce(cluster idind)
        nlcom _b[running_pos] - _b[running_neg]
        matrix TEMP = r(b)
    }
    if _rc == 0 {
        matrix `BW_SENS'[`row', 3] = TEMP[1,1]
    }

    matrix `BW_SENS'[`row', 4] = `BW_SENS'[`row', 3] - `BW_SENS'[`row', 2]
}

matrix list `BW_SENS', format(%7.4f)

*===============================================================================
* 5. POLYNOMIAL SPECIFICATION
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Polynomial Specifications"
di as text    "=============================================="

* Generate polynomial terms
gen double running2 = running^2
gen double running_pos2 = running_pos^2
gen double running_neg2 = running_neg^2

* Quadratic specification
di as text "--- Quadratic RKD ---"
regress dlnc running_pos running_neg running_pos2 running_neg2 ///
    if in_bandwidth == 1, vce(cluster idind)

local slope_pos_quad = _b[running_pos]
local slope_neg_quad = _b[running_neg]
local kink_quad = `slope_pos_quad' - `slope_neg_quad'

di as text "  Linear slope above zero: " %7.4f `slope_pos_quad'
di as text "  Linear slope below zero: " %7.4f `slope_neg_quad'
di as text "  Kink at zero:           " %7.4f `kink_quad'

* Triple difference: kink × informality
di as text _n "--- Triple Difference: Kink × Informality ---"
gen running_pos_inf = running_pos * informal
gen running_neg_inf = running_neg * informal

regress dlnc running_pos running_neg informal running_pos_inf running_neg_inf ///
    if in_bandwidth == 1, vce(cluster idind)

est store rkd_triple

* Test: kink differs by informality
test running_pos_inf = running_neg_inf
local F_triple = r(F)
local p_triple = r(p)
di as text "Test: Kink differs by informality"
di as text "  F = " %6.2f `F_triple' ", p = " %5.3f `p_triple'

*===============================================================================
* 6. PLACEBO TESTS: KINK AT OTHER VALUES
*===============================================================================

di as text _n "=============================================="
di as text    "  6. Placebo Tests"
di as text    "=============================================="

* Test for kinks at placebo locations
di as text "Testing for kinks at placebo locations..."

foreach cutoff in -0.20 -0.10 0.10 0.20 {
    * Center running variable at placebo cutoff
    gen double running_p_`=100*`cutoff'' = dlny_lab - `cutoff'
    gen double running_p_`=100*`cutoff''_pos = max(running_p_`=100*`cutoff'', 0)
    gen double running_p_`=100*`cutoff''_neg = min(running_p_`=100*`cutoff'', 0)

    quietly regress dlnc running_p_`=100*`cutoff''_pos running_p_`=100*`cutoff''_neg ///
        if abs(dlny_lab - `cutoff') <= 0.10, vce(cluster idind)

    capture quietly nlcom _b[running_p_`=100*`cutoff''_pos] - _b[running_p_`=100*`cutoff''_neg]
    if _rc == 0 {
        matrix PLACEBO = r(b)
        matrix V_PLACEBO = r(V)
        local kink_placebo = PLACEBO[1,1]
        local se_placebo = sqrt(V_PLACEBO[1,1])
        local t_placebo = `kink_placebo' / `se_placebo'
        local p_placebo = 2 * (1 - normal(abs(`t_placebo')))

        di as text "  Cutoff = `cutoff': kink = " %7.4f `kink_placebo' " (p = " %5.3f `p_placebo' ")"
    }
}

* Summary
di as text _n "True kink at Δln(Y) = 0: " %7.4f `kink_full' " (p = " %5.3f `p_kink_full' ")"
di as text "If placebo kinks are insignificant, supports genuine effect at zero"

*===============================================================================
* 7. VISUALIZATION OF RKD
*===============================================================================

di as text _n "=============================================="
di as text    "  7. RKD Visualization"
di as text    "=============================================="

* Binned scatter plot with fitted lines
preserve
    * Create bins
    gen bin = floor(dlny_lab * 20) / 20
    collapse (mean) dlnc, by(bin informal)

    * Plot with separate lines above and below zero
    twoway (scatter dlnc bin if informal == 0 & bin < 0, mcolor(blue)) ///
           (scatter dlnc bin if informal == 0 & bin >= 0, mcolor(blue)) ///
           (scatter dlnc bin if informal == 1 & bin < 0, mcolor(red)) ///
           (scatter dlnc bin if informal == 1 & bin >= 0, mcolor(red)) ///
           (lfit dlnc bin if informal == 0 & bin < 0, lcolor(blue) lpattern(solid)) ///
           (lfit dlnc bin if informal == 0 & bin >= 0, lcolor(blue) lpattern(solid)) ///
           (lfit dlnc bin if informal == 1 & bin < 0, lcolor(red) lpattern(solid)) ///
           (lfit dlnc bin if informal == 1 & bin >= 0, lcolor(red) lpattern(solid)), ///
           xline(0, lcolor(black) lpattern(dash) lwidth(medthick)) ///
           xtitle("Δln(Y) (Income Change)") ytitle("Mean Δln(C)") ///
           title("Regression Kink Design") ///
           subtitle("Testing for kink at Δln(Y) = 0") ///
           legend(order(1 "Formal" 3 "Informal") position(6)) ///
           scheme(s2color)

    graph export "${figures}/R8_rkd_binned.png", replace width(1200)
restore

*===============================================================================
* 8. SUMMARY TABLE
*===============================================================================

di as text _n "=============================================="
di as text    "  8. Summary"
di as text    "=============================================="

di as text _n "================================================================"
di as text   "Regression Kink Design: Kink at Δln(Y) = 0"
di as text   "================================================================"
di as text   "                      β⁺ (>0)    β⁻ (<0)    Kink       p-value"
di as text   "----------------------------------------------------------------"
di as text   "Full Sample          " %7.4f `slope_pos_full' "    " %7.4f `slope_neg_full' "    " %7.4f `kink_full' "    " %5.3f `p_kink_full'
di as text   "Formal Workers       " %7.4f `slope_pos_0' "    " %7.4f `slope_neg_0' "    " %7.4f `kink_0' "    " %5.3f `p_kink_0'
di as text   "Informal Workers     " %7.4f `slope_pos_1' "    " %7.4f `slope_neg_1' "    " %7.4f `kink_1' "    " %5.3f `p_kink_1'
di as text   "----------------------------------------------------------------"
di as text   "Diff (Inf - Formal)                        " %7.4f `diff_kink' "    " %5.3f `p_diff_kink'
di as text   "================================================================"

*===============================================================================
* 9. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  9. Export Results"
di as text    "=============================================="

* CSV export
preserve
    clear
    set obs 4
    gen group = ""
    gen slope_pos = .
    gen slope_neg = .
    gen kink = .
    gen p_value = .

    replace group = "Full" in 1
    replace slope_pos = `slope_pos_full' in 1
    replace slope_neg = `slope_neg_full' in 1
    replace kink = `kink_full' in 1
    replace p_value = `p_kink_full' in 1

    replace group = "Formal" in 2
    replace slope_pos = `slope_pos_0' in 2
    replace slope_neg = `slope_neg_0' in 2
    replace kink = `kink_0' in 2
    replace p_value = `p_kink_0' in 2

    replace group = "Informal" in 3
    replace slope_pos = `slope_pos_1' in 3
    replace slope_neg = `slope_neg_1' in 3
    replace kink = `kink_1' in 3
    replace p_value = `p_kink_1' in 3

    replace group = "Difference" in 4
    replace kink = `diff_kink' in 4
    replace p_value = `p_diff_kink' in 4

    export delimited using "${tables}/R8_regression_kink.csv", replace
restore

* Bandwidth sensitivity export
preserve
    clear
    svmat `BW_SENS', names(col)
    export delimited using "${tables}/R8_bandwidth_sensitivity.csv", replace
restore

*===============================================================================
* 10. SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  R8 SUMMARY: Regression Kink Design"
di as text    "=============================================="

di as text _n "RESEARCH QUESTION:"
di as text "  Is there a genuine kink in consumption response at Δln(Y) = 0?"
di as text "  This tests the assumption of asymmetric smoothing."

di as text _n "KEY FINDINGS:"
di as text "  1. Kink at zero (full sample): " %7.4f `kink_full' " (p = " %5.3f `p_kink_full' ")"

if `p_kink_full' < 0.05 {
    di as text "     → SIGNIFICANT kink: slopes differ above vs below zero"
}
else {
    di as text "     → No significant kink detected"
}

di as text _n "  2. Kink by informality:"
di as text "     Formal:   " %7.4f `kink_0' " (p = " %5.3f `p_kink_0' ")"
di as text "     Informal: " %7.4f `kink_1' " (p = " %5.3f `p_kink_1' ")"

di as text _n "  3. Difference in kinks (Informal - Formal):"
di as text "     " %7.4f `diff_kink' " (p = " %5.3f `p_diff_kink' ")"

di as text _n "INTERPRETATION:"
if `p_diff_kink' < 0.05 {
    di as text "  *** Informal workers have LARGER kink at zero ***"
    di as text "  This supports the asymmetric smoothing hypothesis:"
    di as text "  Informal workers respond MORE to losses than gains."
}
else if `p_kink_1' < 0.05 {
    di as text "  Significant kink for informal workers"
    di as text "  But difference from formal workers is not significant"
}
else {
    di as text "  No clear evidence of differential kink by informality"
}

log close

di as text _n "Log saved to: ${logdir}/R8_regression_kink.log"
di as text "Figures saved to: ${figures}/R8_*.png"
di as text "Tables saved to: ${tables}/R8_*.csv"

*===============================================================================
* END
*===============================================================================
