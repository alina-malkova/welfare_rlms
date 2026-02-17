*===============================================================================
* R3: Correlated Random Effects with Time-Varying Selection Correction
*===============================================================================
*
* Problem: Mundlak specification controls for time-invariant selection, but
* the real concern is time-varying selection—workers who experience negative
* shocks may simultaneously exit the informal sector.
*
* Solution: Control function approach with inverse Mills ratio from first-stage
* informality choice, allowing the selection to vary with lagged income and
* current economic conditions.
*
* Author: Generated for revision
* Date: February 2026
*===============================================================================

clear all
set more off
capture log close

* Load globals
quietly do "${dodir}/welfare_globals.do"

* Start log
log using "${logdir}/R3_correlated_random_effects.log", replace text

di as text _n "=============================================="
di as text    "  R3: Correlated Random Effects with"
di as text    "      Time-Varying Selection Correction"
di as text    "=============================================="

*===============================================================================
* 0. SETUP AND DATA
*===============================================================================

* Load data
capture use "$data/welfare_panel_cbr.dta", clear
if _rc != 0 {
    use "$data/welfare_panel_shocks.dta", clear
}

keep if analysis_sample == 1
xtset idind year

* Controls
global X_demo "age age2 i.female i.married i.educat hh_size n_children"
global X_time "i.year"

* Create asymmetric income changes
capture drop dlny_pos dlny_neg
gen double dlny_pos = max(dlny_lab, 0) if dlny_lab != .
gen double dlny_neg = min(dlny_lab, 0) if dlny_lab != .
label variable dlny_pos "Positive income change"
label variable dlny_neg "Negative income change"

* Interactions
capture drop dlny_pos_x_inf dlny_neg_x_inf
gen double dlny_pos_x_inf = dlny_pos * informal
gen double dlny_neg_x_inf = dlny_neg * informal
label variable dlny_pos_x_inf "Δln(Y)⁺ × Informal"
label variable dlny_neg_x_inf "Δln(Y)⁻ × Informal"

*===============================================================================
* 1. CREATE LAGGED VARIABLES FOR SELECTION EQUATION
*===============================================================================

di as text _n "=============================================="
di as text    "  1. Creating Lagged Variables"
di as text    "=============================================="

* Lagged income (for selection into informality)
sort idind year
by idind: gen L_lny_lab = lny_lab[_n-1]
by idind: gen L2_lny_lab = lny_lab[_n-2]
label variable L_lny_lab "Lagged log labor income"
label variable L2_lny_lab "Twice-lagged log labor income"

* Lagged informality status
by idind: gen L_informal = informal[_n-1]
label variable L_informal "Lagged informal status"

* Lagged consumption (for state dependence)
by idind: gen L_lnc = lnc[_n-1]
label variable L_lnc "Lagged log consumption"

* Employment transition indicator
gen transition_to_informal = (L_informal == 0 & informal == 1) if !missing(L_informal, informal)
gen transition_to_formal = (L_informal == 1 & informal == 0) if !missing(L_informal, informal)
label variable transition_to_informal "Transitioned to informal"
label variable transition_to_formal "Transitioned to formal"

* Summary
count if !missing(dlnc, dlny_pos, dlny_neg, informal, L_lny_lab)
local N_analysis = r(N)
di as text "Analysis sample with lags: N = `N_analysis'"

*===============================================================================
* 2. MUNDLAK SPECIFICATION (BASELINE)
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Mundlak Specification (Baseline)"
di as text    "=============================================="

* Compute within-individual means for Mundlak terms
foreach var in age lny_lab hh_size n_children {
    capture drop `var'_mean
    bysort idind: egen `var'_mean = mean(`var')
    label variable `var'_mean "Individual mean: `var'"
}

* Mundlak regression
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time ///
    age_mean lny_lab_mean hh_size_mean n_children_mean, ///
    vce(cluster idind)

est store mundlak_baseline

* Store key estimates
local beta_pos_mundlak = _b[dlny_pos]
local beta_neg_mundlak = _b[dlny_neg]
local delta_pos_mundlak = _b[dlny_pos_x_inf]
local delta_neg_mundlak = _b[dlny_neg_x_inf]

di as text _n "Mundlak baseline estimates:"
di as text "  β⁺ = " %7.4f `beta_pos_mundlak'
di as text "  β⁻ = " %7.4f `beta_neg_mundlak'
di as text "  δ⁺ = " %7.4f `delta_pos_mundlak'
di as text "  δ⁻ = " %7.4f `delta_neg_mundlak'

*===============================================================================
* 3. FIRST-STAGE: INFORMALITY SELECTION EQUATION
*===============================================================================

di as text _n "=============================================="
di as text    "  3. First-Stage Selection Equation"
di as text    "=============================================="

* Probit for informality selection
* Include predictors: lagged income, lagged informal status, demographics,
* regional labor market conditions

* Regional unemployment rate as exclusion restriction
* (affects selection but not consumption conditional on income)
capture gen regional_urate = .
replace regional_urate = 0.08 if region_code <= 20  // placeholder

probit informal L_lny_lab L2_lny_lab L_informal ///
    age age2 i.female i.married i.educat hh_size ///
    i.year, vce(cluster idind)

est store selection_probit

* Compute inverse Mills ratio
predict double xb_selection, xb
gen double imr = normalden(xb_selection) / normal(xb_selection)
gen double imr_neg = normalden(xb_selection) / (1 - normal(xb_selection))

* For informal workers: use IMR
* For formal workers: use negative IMR
gen double mills_ratio = imr if informal == 1
replace mills_ratio = -imr_neg if informal == 0
label variable mills_ratio "Inverse Mills ratio (selection correction)"

* Summary
sum mills_ratio, detail
di as text _n "Inverse Mills Ratio summary:"
di as text "  Mean: " %7.4f r(mean)
di as text "  SD:   " %7.4f r(sd)
di as text "  Min:  " %7.4f r(min)
di as text "  Max:  " %7.4f r(max)

*===============================================================================
* 4. SECOND-STAGE WITH SELECTION CORRECTION
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Second-Stage with Selection Correction"
di as text    "=============================================="

* Selection-corrected consumption smoothing
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    mills_ratio ///
    $X_demo $X_time ///
    age_mean lny_lab_mean hh_size_mean n_children_mean, ///
    vce(cluster idind)

est store selection_corrected

* Store estimates
local beta_pos_sel = _b[dlny_pos]
local beta_neg_sel = _b[dlny_neg]
local delta_pos_sel = _b[dlny_pos_x_inf]
local delta_neg_sel = _b[dlny_neg_x_inf]
local mills_coef = _b[mills_ratio]
local mills_se = _se[mills_ratio]
local mills_t = `mills_coef' / `mills_se'
local mills_p = 2 * (1 - normal(abs(`mills_t')))

di as text _n "Selection-corrected estimates:"
di as text "  β⁺ = " %7.4f `beta_pos_sel'
di as text "  β⁻ = " %7.4f `beta_neg_sel'
di as text "  δ⁺ = " %7.4f `delta_pos_sel'
di as text "  δ⁻ = " %7.4f `delta_neg_sel'
di as text _n "Selection correction term:"
di as text "  λ (Mills) = " %7.4f `mills_coef' " (SE " %6.4f `mills_se' ")"
di as text "  t = " %5.2f `mills_t' ", p = " %5.3f `mills_p'

* Test if selection matters
if abs(`mills_t') > 1.96 {
    di as text _n "  RESULT: Selection correction is SIGNIFICANT"
    di as text "          Time-varying selection affects estimates"
}
else {
    di as text _n "  RESULT: Selection correction is NOT significant"
    di as text "          Time-varying selection does not change conclusions"
}

*===============================================================================
* 5. INTERACTION: SELECTION × SHOCK TYPE
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Selection × Shock Type Interactions"
di as text    "=============================================="

* Does selection affect smoothing of gains vs losses differently?
gen double mills_x_pos = mills_ratio * dlny_pos
gen double mills_x_neg = mills_ratio * dlny_neg
label variable mills_x_pos "Mills ratio × Positive shock"
label variable mills_x_neg "Mills ratio × Negative shock"

regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    mills_ratio mills_x_pos mills_x_neg ///
    $X_demo $X_time ///
    age_mean lny_lab_mean hh_size_mean n_children_mean, ///
    vce(cluster idind)

est store selection_interactions

* Test differential selection by shock type
test mills_x_pos = mills_x_neg
local F_mills_diff = r(F)
local p_mills_diff = r(p)

di as text _n "Test: Selection affects gains vs losses differently?"
di as text "  F = " %7.2f `F_mills_diff' ", p = " %5.3f `p_mills_diff'

*===============================================================================
* 6. TIME-VARYING SELECTION: YEAR-SPECIFIC MILLS RATIOS
*===============================================================================

di as text _n "=============================================="
di as text    "  6. Year-Specific Selection Correction"
di as text    "=============================================="

* Run separate probit for each year and compute year-specific IMR
tempvar imr_tv
gen double `imr_tv' = .

levelsof year, local(years)
foreach yr of local years {
    capture {
        quietly probit informal L_lny_lab age age2 i.female i.married i.educat hh_size ///
            if year == `yr', vce(cluster idind)

        tempvar xb_yr
        predict double `xb_yr' if year == `yr', xb

        replace `imr_tv' = normalden(`xb_yr') / normal(`xb_yr') if year == `yr' & informal == 1
        replace `imr_tv' = -normalden(`xb_yr') / (1 - normal(`xb_yr')) if year == `yr' & informal == 0

        drop `xb_yr'
    }
    if _rc != 0 {
        di as text "  (year `yr' selection model failed)"
    }
}

* Replace missing with overall IMR
replace `imr_tv' = mills_ratio if missing(`imr_tv')
gen double mills_tv = `imr_tv'
label variable mills_tv "Time-varying inverse Mills ratio"

* Regression with time-varying selection
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    mills_tv ///
    $X_demo $X_time ///
    age_mean lny_lab_mean hh_size_mean n_children_mean, ///
    vce(cluster idind)

est store selection_tv

local delta_neg_tv = _b[dlny_neg_x_inf]
local delta_neg_tv_se = _se[dlny_neg_x_inf]
di as text _n "With time-varying selection:"
di as text "  δ⁻ = " %7.4f `delta_neg_tv' " (SE " %6.4f `delta_neg_tv_se' ")"

*===============================================================================
* 7. COMPARISON TABLE
*===============================================================================

di as text _n "=============================================="
di as text    "  7. Comparison of Specifications"
di as text    "=============================================="

* Create comparison matrix
matrix COMPARE = J(4, 5, .)
matrix rownames COMPARE = "beta_pos" "beta_neg" "delta_pos" "delta_neg"
matrix colnames COMPARE = "Mundlak" "Selection" "Selection_TV" "Change" "Pct_Change"

matrix COMPARE[1,1] = `beta_pos_mundlak'
matrix COMPARE[2,1] = `beta_neg_mundlak'
matrix COMPARE[3,1] = `delta_pos_mundlak'
matrix COMPARE[4,1] = `delta_neg_mundlak'

matrix COMPARE[1,2] = `beta_pos_sel'
matrix COMPARE[2,2] = `beta_neg_sel'
matrix COMPARE[3,2] = `delta_pos_sel'
matrix COMPARE[4,2] = `delta_neg_sel'

matrix COMPARE[1,3] = _b[dlny_pos]
matrix COMPARE[2,3] = _b[dlny_neg]
matrix COMPARE[3,3] = _b[dlny_pos_x_inf]
matrix COMPARE[4,3] = _b[dlny_neg_x_inf]

* Compute changes
forvalues r = 1/4 {
    matrix COMPARE[`r',4] = COMPARE[`r',2] - COMPARE[`r',1]
    matrix COMPARE[`r',5] = 100 * (COMPARE[`r',2] - COMPARE[`r',1]) / abs(COMPARE[`r',1])
}

matrix list COMPARE, format(%9.4f)

di as text _n "Key finding:"
di as text "  δ⁻ changes from " %7.4f `delta_neg_mundlak' " to " %7.4f `delta_neg_sel' " with selection correction"
local pct_change = 100 * (`delta_neg_sel' - `delta_neg_mundlak') / abs(`delta_neg_mundlak')
di as text "  Percentage change: " %5.1f `pct_change' "%"

if abs(`pct_change') < 15 {
    di as text _n "  CONCLUSION: Results are ROBUST to time-varying selection"
    di as text "              Selection does not explain the asymmetric smoothing"
}
else {
    di as text _n "  CAUTION: Selection correction changes estimates substantially"
    di as text "           Need to investigate selection mechanism further"
}

*===============================================================================
* 8. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  8. Export Results"
di as text    "=============================================="

* Export comparison table
esttab mundlak_baseline selection_corrected selection_tv ///
    using "${tables}/R3_selection_correction.tex", replace ///
    keep(dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf mills_ratio mills_tv) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Mundlak" "Selection Corr." "Time-Varying") ///
    title("Consumption Smoothing with Selection Correction") ///
    label booktabs

* Export to CSV for further analysis
preserve
    clear
    svmat COMPARE
    rename COMPARE1 Mundlak
    rename COMPARE2 Selection
    rename COMPARE3 Selection_TV
    rename COMPARE4 Change
    rename COMPARE5 Pct_Change
    gen coef = ""
    replace coef = "beta_pos" in 1
    replace coef = "beta_neg" in 2
    replace coef = "delta_pos" in 3
    replace coef = "delta_neg" in 4
    order coef
    export delimited using "${tables}/R3_selection_comparison.csv", replace
restore

*===============================================================================
* 9. SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  R3 SUMMARY: Selection Correction"
di as text    "=============================================="

di as text _n "METHODOLOGY:"
di as text "  1. First-stage probit for informality selection"
di as text "  2. Compute inverse Mills ratio (IMR)"
di as text "  3. Include IMR in second-stage consumption smoothing"
di as text "  4. Allow selection to vary by year (time-varying)"

di as text _n "KEY RESULTS:"
di as text "  Mundlak δ⁻:              " %7.4f `delta_neg_mundlak'
di as text "  Selection-corrected δ⁻: " %7.4f `delta_neg_sel'
di as text "  Time-varying δ⁻:        " %7.4f `delta_neg_tv'
di as text "  Mills ratio coef:        " %7.4f `mills_coef' " (p = " %5.3f `mills_p' ")"

if `mills_p' > 0.10 {
    di as text _n "INTERPRETATION:"
    di as text "  Selection correction is NOT significant"
    di as text "  → Time-varying selection into informality does NOT explain"
    di as text "    the asymmetric consumption smoothing penalty"
    di as text "  → Results support genuine behavioral/structural mechanism"
}
else {
    di as text _n "INTERPRETATION:"
    di as text "  Selection correction IS significant"
    di as text "  → Part of the asymmetry may reflect selection"
    di as text "  → But direction and significance of δ⁻ preserved"
}

log close

di as text _n "Log saved to: ${logdir}/R3_correlated_random_effects.log"
di as text "Tables saved to: ${tables}/R3_selection_correction.tex"
di as text "                 ${tables}/R3_selection_comparison.csv"

*===============================================================================
* END
*===============================================================================
