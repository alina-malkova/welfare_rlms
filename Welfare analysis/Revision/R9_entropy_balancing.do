*===============================================================================
* R9: Entropy Balancing for Selection
*===============================================================================
*
* Problem: OLS with controls may not adequately address selection into
* informal employment. Selection on observables may bias estimates.
*
* Solution: Entropy balancing (Hainmueller 2012) - reweight formal workers
* to match covariate moments of informal workers exactly.
*
* This ensures perfect balance on observed characteristics, making the
* comparison more credible.
*
* Reference: Hainmueller, J. (2012). Political Analysis.
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
log using "${logdir}/R9_entropy_balancing.log", replace text

di as text _n "=============================================="
di as text    "  R9: Entropy Balancing for Selection"
di as text    "=============================================="

*===============================================================================
* 0. SETUP AND DATA
*===============================================================================

* Check for ebalance package
capture which ebalance
if _rc {
    di as text "Installing ebalance package..."
    ssc install ebalance, replace
}

* Load data
capture use "$data/welfare_panel_cbr.dta", clear
if _rc != 0 {
    use "$data/welfare_panel_shocks.dta", clear
}

keep if analysis_sample == 1 & !missing(dlnc, dlny_lab, informal)
xtset idind year

* Controls
global X_demo "age age2 female married hh_size n_children"
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

*===============================================================================
* 1. BASELINE BALANCE CHECK
*===============================================================================

di as text _n "=============================================="
di as text    "  1. Baseline Covariate Balance"
di as text    "=============================================="

* Summary statistics by informality
di as text _n "Means by Informality Status:"
di as text "Variable          Formal    Informal    Diff"
di as text "------------------------------------------------"

foreach var in age female married hh_size n_children dlny_lab {
    sum `var' if informal == 0
    local mean0 = r(mean)
    sum `var' if informal == 1
    local mean1 = r(mean)
    local diff = `mean1' - `mean0'

    * T-test
    quietly ttest `var', by(informal)
    local p = r(p)

    di as text "`var'" _col(20) %7.3f `mean0' _col(30) %7.3f `mean1' _col(42) %7.3f `diff' " (p=" %5.3f `p' ")"
}

*===============================================================================
* 2. ENTROPY BALANCING
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Entropy Balancing"
di as text    "=============================================="

* Balancing covariates
* Target: make formal workers look like informal workers on observables
* (informal = 1 is the "treatment" group)

* Generate squared terms for balancing on variance
gen age_sq = age^2
gen hh_size_sq = hh_size^2

* Entropy balance: target = informal
ebalance informal age female married hh_size n_children, ///
    targets(1) generate(ebal_wt)

* Summary of weights
sum ebal_wt, detail
di as text _n "Entropy balance weights:"
di as text "  Mean: " %8.4f r(mean)
di as text "  SD:   " %8.4f r(sd)
di as text "  Min:  " %8.4f r(min)
di as text "  Max:  " %8.4f r(max)

* Normalize weights
egen ebal_wt_sum = total(ebal_wt)
gen ebal_wt_norm = ebal_wt * _N / ebal_wt_sum
drop ebal_wt_sum

*===============================================================================
* 3. POST-BALANCE CHECK
*===============================================================================

di as text _n "=============================================="
di as text    "  3. Post-Balance Check"
di as text    "=============================================="

di as text _n "Weighted Means (After Entropy Balancing):"
di as text "Variable          Formal(wt)  Informal    Diff"
di as text "------------------------------------------------"

foreach var in age female married hh_size n_children {
    * Weighted mean for formal
    sum `var' [aw=ebal_wt] if informal == 0
    local mean0_w = r(mean)
    * Mean for informal
    sum `var' if informal == 1
    local mean1 = r(mean)
    local diff_w = `mean1' - `mean0_w'

    di as text "`var'" _col(20) %7.3f `mean0_w' _col(32) %7.3f `mean1' _col(44) %7.4f `diff_w'
}

di as text _n "Note: Differences should be very close to zero after balancing"

*===============================================================================
* 4. BASELINE REGRESSION (UNWEIGHTED)
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Baseline Regression (Unweighted)"
di as text    "=============================================="

regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time, vce(cluster idind)

est store baseline_unwt

local delta_neg_unwt = _b[dlny_neg_x_inf]
local delta_neg_se_unwt = _se[dlny_neg_x_inf]
local delta_pos_unwt = _b[dlny_pos_x_inf]

test dlny_pos_x_inf = dlny_neg_x_inf
local wald_p_unwt = r(p)

di as text "Unweighted estimates:"
di as text "  δ⁺ = " %7.4f `delta_pos_unwt'
di as text "  δ⁻ = " %7.4f `delta_neg_unwt' " (SE " %6.4f `delta_neg_se_unwt' ")"
di as text "  Wald p-value (δ⁺ = δ⁻): " %5.3f `wald_p_unwt'

*===============================================================================
* 5. ENTROPY-BALANCED REGRESSION
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Entropy-Balanced Regression"
di as text    "=============================================="

regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time [pw=ebal_wt], vce(cluster idind)

est store ebalance_wt

local delta_neg_wt = _b[dlny_neg_x_inf]
local delta_neg_se_wt = _se[dlny_neg_x_inf]
local delta_pos_wt = _b[dlny_pos_x_inf]

test dlny_pos_x_inf = dlny_neg_x_inf
local wald_p_wt = r(p)

di as text "Entropy-balanced estimates:"
di as text "  δ⁺ = " %7.4f `delta_pos_wt'
di as text "  δ⁻ = " %7.4f `delta_neg_wt' " (SE " %6.4f `delta_neg_se_wt' ")"
di as text "  Wald p-value (δ⁺ = δ⁻): " %5.3f `wald_p_wt'

* Change from baseline
local pct_change = 100 * (`delta_neg_wt' - `delta_neg_unwt') / abs(`delta_neg_unwt')
di as text _n "Change from baseline:"
di as text "  Δ(δ⁻) = " %7.4f (`delta_neg_wt' - `delta_neg_unwt')
di as text "  % change = " %5.1f `pct_change' "%"

*===============================================================================
* 6. ALTERNATIVE: MATCHING ON PROPENSITY SCORE
*===============================================================================

di as text _n "=============================================="
di as text    "  6. Alternative: Propensity Score Weighting"
di as text    "=============================================="

* Propensity score for informality
probit informal age age2 female married hh_size n_children i.year, vce(cluster idind)

predict double pscore, pr
label variable pscore "P(Informal)"

* Inverse propensity weighting
* For informal workers: weight = 1
* For formal workers: weight = pscore / (1 - pscore)
gen double ipw = .
replace ipw = 1 if informal == 1
replace ipw = pscore / (1 - pscore) if informal == 0

* Trim extreme weights
sum ipw if informal == 0, detail
local p99 = r(p99)
replace ipw = `p99' if ipw > `p99' & informal == 0
sum ipw, detail

* IPW regression
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time [pw=ipw], vce(cluster idind)

est store ipw_reg

local delta_neg_ipw = _b[dlny_neg_x_inf]
local delta_neg_se_ipw = _se[dlny_neg_x_inf]

test dlny_pos_x_inf = dlny_neg_x_inf
local wald_p_ipw = r(p)

di as text "IPW estimates:"
di as text "  δ⁻ = " %7.4f `delta_neg_ipw' " (SE " %6.4f `delta_neg_se_ipw' ")"
di as text "  Wald p-value: " %5.3f `wald_p_ipw'

*===============================================================================
* 7. DOUBLY ROBUST ESTIMATOR
*===============================================================================

di as text _n "=============================================="
di as text    "  7. Doubly Robust Estimator"
di as text    "=============================================="

* Doubly robust: combine entropy balancing + regression adjustment
* Estimate separate models for formal and informal

* Informal workers
regress dlnc dlny_pos dlny_neg $X_demo i.year if informal == 1, vce(cluster idind)
predict double yhat_inf, xb
local beta_pos_inf = _b[dlny_pos]
local beta_neg_inf = _b[dlny_neg]

* Formal workers (weighted)
regress dlnc dlny_pos dlny_neg $X_demo i.year [pw=ebal_wt] if informal == 0, vce(cluster idind)
predict double yhat_formal, xb
local beta_pos_formal = _b[dlny_pos]
local beta_neg_formal = _b[dlny_neg]

* Doubly robust treatment effect
* δ⁺ = β⁺_informal - β⁺_formal
* δ⁻ = β⁻_informal - β⁻_formal

local delta_pos_dr = `beta_pos_inf' - `beta_pos_formal'
local delta_neg_dr = `beta_neg_inf' - `beta_neg_formal'

di as text "Doubly Robust estimates (separate regressions):"
di as text "  β⁺ (formal):   " %7.4f `beta_pos_formal'
di as text "  β⁺ (informal): " %7.4f `beta_pos_inf'
di as text "  → δ⁺ = " %7.4f `delta_pos_dr'
di as text _n "  β⁻ (formal):   " %7.4f `beta_neg_formal'
di as text "  β⁻ (informal): " %7.4f `beta_neg_inf'
di as text "  → δ⁻ = " %7.4f `delta_neg_dr'

*===============================================================================
* 8. COMPARISON TABLE
*===============================================================================

di as text _n "=============================================="
di as text    "  8. Comparison of Approaches"
di as text    "=============================================="

di as text _n "================================================================"
di as text   "Method                δ⁺         δ⁻         Wald p    Δ from OLS"
di as text   "================================================================"
di as text   "OLS (unweighted)    " %7.4f `delta_pos_unwt' "    " %7.4f `delta_neg_unwt' "    " %5.3f `wald_p_unwt' "    ---"
di as text   "Entropy Balanced    " %7.4f `delta_pos_wt' "    " %7.4f `delta_neg_wt' "    " %5.3f `wald_p_wt' "    " %+5.1f (100*(`delta_neg_wt'-`delta_neg_unwt')/abs(`delta_neg_unwt')) "%"
di as text   "IPW                 " %7.4f _b[dlny_pos_x_inf] "    " %7.4f `delta_neg_ipw' "    " %5.3f `wald_p_ipw' "    " %+5.1f (100*(`delta_neg_ipw'-`delta_neg_unwt')/abs(`delta_neg_unwt')) "%"
di as text   "Doubly Robust       " %7.4f `delta_pos_dr' "    " %7.4f `delta_neg_dr' "           " %+5.1f (100*(`delta_neg_dr'-`delta_neg_unwt')/abs(`delta_neg_unwt')) "%"
di as text   "================================================================"

*===============================================================================
* 9. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  9. Export Results"
di as text    "=============================================="

* Regression table
esttab baseline_unwt ebalance_wt ipw_reg ///
    using "${tables}/R9_entropy_balancing.tex", replace ///
    keep(dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("OLS" "Entropy Balance" "IPW") ///
    title("Consumption Smoothing with Selection Correction") ///
    label booktabs

* CSV summary
preserve
    clear
    set obs 4
    gen method = ""
    gen delta_pos = .
    gen delta_neg = .
    gen wald_p = .
    gen pct_change = .

    replace method = "OLS" in 1
    replace delta_pos = `delta_pos_unwt' in 1
    replace delta_neg = `delta_neg_unwt' in 1
    replace wald_p = `wald_p_unwt' in 1

    replace method = "Entropy" in 2
    replace delta_pos = `delta_pos_wt' in 2
    replace delta_neg = `delta_neg_wt' in 2
    replace wald_p = `wald_p_wt' in 2
    replace pct_change = 100 * (`delta_neg_wt' - `delta_neg_unwt') / abs(`delta_neg_unwt') in 2

    replace method = "IPW" in 3
    replace delta_neg = `delta_neg_ipw' in 3
    replace wald_p = `wald_p_ipw' in 3
    replace pct_change = 100 * (`delta_neg_ipw' - `delta_neg_unwt') / abs(`delta_neg_unwt') in 3

    replace method = "Doubly_Robust" in 4
    replace delta_pos = `delta_pos_dr' in 4
    replace delta_neg = `delta_neg_dr' in 4
    replace pct_change = 100 * (`delta_neg_dr' - `delta_neg_unwt') / abs(`delta_neg_unwt') in 4

    export delimited using "${tables}/R9_selection_methods.csv", replace
restore

*===============================================================================
* 10. SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  R9 SUMMARY: Entropy Balancing"
di as text    "=============================================="

di as text _n "METHODOLOGY:"
di as text "  Entropy balancing reweights formal workers to match informal"
di as text "  workers on observable characteristics (age, gender, marriage,"
di as text "  household size, children). This addresses selection on observables."

di as text _n "KEY RESULTS:"
di as text "  OLS δ⁻:              " %7.4f `delta_neg_unwt' " (p = " %5.3f `wald_p_unwt' ")"
di as text "  Entropy-balanced δ⁻: " %7.4f `delta_neg_wt' " (p = " %5.3f `wald_p_wt' ")"
di as text "  Change:              " %5.1f `pct_change' "%"

if abs(`pct_change') < 20 & `wald_p_wt' < 0.05 {
    di as text _n "CONCLUSION:"
    di as text "  *** Results are ROBUST to selection on observables ***"
    di as text "  Entropy balancing does not substantially change estimates."
    di as text "  The asymmetric smoothing penalty (δ⁻) is NOT driven by"
    di as text "  compositional differences between formal and informal workers."
}
else if abs(`pct_change') >= 20 {
    di as text _n "CONCLUSION:"
    di as text "  Selection on observables MATTERS."
    di as text "  Entropy-balanced estimate should be preferred."
}

log close

di as text _n "Log saved to: ${logdir}/R9_entropy_balancing.log"
di as text "Tables saved to: ${tables}/R9_entropy_balancing.tex"
di as text "                 ${tables}/R9_selection_methods.csv"

*===============================================================================
* END
*===============================================================================
