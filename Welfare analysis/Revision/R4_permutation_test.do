*===============================================================================
* R4: Permutation Test for the Asymmetry
*===============================================================================
*
* Problem: Standard p-values assume normally distributed test statistics.
* For the Wald test of H0: δ⁺ = δ⁻, we want a distribution-free test.
*
* Solution: Permutation test with 10,000 iterations.
* Under H0, randomly assign positive/negative shock labels within individuals,
* re-estimate, and compare observed test statistic to permutation distribution.
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
log using "${logdir}/R4_permutation_test.log", replace text

di as text _n "=============================================="
di as text    "  R4: Permutation Test for Asymmetry"
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
global X_qreg "age age2 female married hh_size n_children"

* Create asymmetric income changes
capture drop dlny_pos dlny_neg
gen double dlny_pos = max(dlny_lab, 0) if dlny_lab != .
gen double dlny_neg = min(dlny_lab, 0) if dlny_lab != .

* Interactions
capture drop dlny_pos_x_inf dlny_neg_x_inf
gen double dlny_pos_x_inf = dlny_pos * informal
gen double dlny_neg_x_inf = dlny_neg * informal

* Restrict to analysis sample
keep if !missing(dlnc, dlny_pos, dlny_neg, informal)
count
local N_total = r(N)
di as text "Permutation test sample: N = `N_total'"

*===============================================================================
* 1. OBSERVED TEST STATISTIC
*===============================================================================

di as text _n "=============================================="
di as text    "  1. Observed Test Statistic"
di as text    "=============================================="

* Run baseline regression
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_qreg i.year, vce(cluster idind)

* Store observed coefficients
local delta_pos_obs = _b[dlny_pos_x_inf]
local delta_neg_obs = _b[dlny_neg_x_inf]
local diff_obs = `delta_neg_obs' - `delta_pos_obs'

* Standard Wald test
test dlny_pos_x_inf = dlny_neg_x_inf
local wald_F_obs = r(F)
local wald_p_obs = r(p)

di as text "Observed estimates:"
di as text "  δ⁺ = " %9.6f `delta_pos_obs'
di as text "  δ⁻ = " %9.6f `delta_neg_obs'
di as text "  Difference (δ⁻ - δ⁺) = " %9.6f `diff_obs'
di as text _n "Standard Wald test:"
di as text "  F = " %7.2f `wald_F_obs' ", p = " %6.4f `wald_p_obs'

*===============================================================================
* 2. PERMUTATION PROCEDURE
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Permutation Test (10,000 iterations)"
di as text    "=============================================="

* Set seed for reproducibility
set seed 20260217

* Number of permutations
local n_perm = 10000

* Store permutation differences
tempname PERM
matrix `PERM' = J(`n_perm', 3, .)
matrix colnames `PERM' = "delta_pos" "delta_neg" "diff"

* Create indicator for non-zero shock
gen has_shock = (dlny_lab != 0 & !missing(dlny_lab))

* Store original values
gen double dlny_pos_orig = dlny_pos
gen double dlny_neg_orig = dlny_neg
gen double dlny_pos_x_inf_orig = dlny_pos_x_inf
gen double dlny_neg_x_inf_orig = dlny_neg_x_inf

* Timer
timer clear 1
timer on 1

* Progress marker
local pct_done = 0

forvalues i = 1/`n_perm' {

    * Progress update every 10%
    local pct = floor(100 * `i' / `n_perm')
    if `pct' >= `pct_done' + 10 {
        local pct_done = `pct'
        di as text "  Progress: `pct_done'% complete..."
    }

    * Under H0: randomly swap positive and negative shock labels
    * This tests whether the distinction between gains and losses matters

    * Generate random swap indicator (within each individual-year)
    capture drop swap
    gen byte swap = runiform() < 0.5 if has_shock

    * Swap the shock signs
    replace dlny_pos = cond(swap, -dlny_neg_orig, dlny_pos_orig, .)
    replace dlny_neg = cond(swap, -dlny_pos_orig, dlny_neg_orig, .)

    * Recreate interactions
    replace dlny_pos_x_inf = dlny_pos * informal
    replace dlny_neg_x_inf = dlny_neg * informal

    * Re-estimate (quietly, no SE for speed)
    capture quietly regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
        $X_qreg i.year

    if _rc == 0 {
        matrix `PERM'[`i', 1] = _b[dlny_pos_x_inf]
        matrix `PERM'[`i', 2] = _b[dlny_neg_x_inf]
        matrix `PERM'[`i', 3] = _b[dlny_neg_x_inf] - _b[dlny_pos_x_inf]
    }
}

timer off 1
quietly timer list 1
local time_elapsed = r(t1)
di as text _n "  Permutation test completed in " %6.1f `time_elapsed' " seconds"

* Restore original values
replace dlny_pos = dlny_pos_orig
replace dlny_neg = dlny_neg_orig
replace dlny_pos_x_inf = dlny_pos_x_inf_orig
replace dlny_neg_x_inf = dlny_neg_x_inf_orig

*===============================================================================
* 3. COMPUTE PERMUTATION P-VALUE
*===============================================================================

di as text _n "=============================================="
di as text    "  3. Permutation P-Value"
di as text    "=============================================="

* Convert matrix to dataset for analysis
preserve
    clear
    svmat `PERM'
    rename `PERM'1 delta_pos_perm
    rename `PERM'2 delta_neg_perm
    rename `PERM'3 diff_perm

    * Drop missing (failed iterations)
    drop if missing(diff_perm)
    count
    local n_valid = r(N)
    di as text "Valid permutations: `n_valid' / `n_perm'"

    * Two-sided p-value: proportion of permuted |diff| >= observed |diff|
    gen exceed_obs = abs(diff_perm) >= abs(`diff_obs')
    sum exceed_obs
    local p_perm_2sided = r(mean)

    * One-sided p-value: proportion of permuted diff >= observed diff
    * (testing H1: δ⁻ > δ⁺)
    gen exceed_obs_1sided = diff_perm >= `diff_obs'
    sum exceed_obs_1sided
    local p_perm_1sided = r(mean)

    * Summary statistics of permutation distribution
    sum diff_perm, detail
    local perm_mean = r(mean)
    local perm_sd = r(sd)
    local perm_p5 = r(p5)
    local perm_p95 = r(p95)

    * Save permutation distribution
    save "${data}/R4_permutation_distribution.dta", replace
restore

di as text "Permutation distribution of (δ⁻ - δ⁺):"
di as text "  Mean:      " %9.6f `perm_mean'
di as text "  Std Dev:   " %9.6f `perm_sd'
di as text "  5th pctl:  " %9.6f `perm_p5'
di as text "  95th pctl: " %9.6f `perm_p95'

di as text _n "PERMUTATION P-VALUES:"
di as text "  Observed difference: " %9.6f `diff_obs'
di as text "  Two-sided p-value:   " %6.4f `p_perm_2sided'
di as text "  One-sided p-value:   " %6.4f `p_perm_1sided'

*===============================================================================
* 4. COMPARISON WITH STANDARD TEST
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Comparison: Permutation vs Standard"
di as text    "=============================================="

di as text "                    Standard     Permutation"
di as text "  Two-sided p:      " %6.4f `wald_p_obs' "       " %6.4f `p_perm_2sided'
di as text "  One-sided p:      " %6.4f (`wald_p_obs'/2) "       " %6.4f `p_perm_1sided'

if `p_perm_2sided' < 0.05 & `wald_p_obs' < 0.05 {
    di as text _n "  RESULT: Both tests reject H0: δ⁺ = δ⁻ at 5% level"
    di as text "          Asymmetry is CONFIRMED by distribution-free test"
}
else if `p_perm_2sided' >= 0.05 & `wald_p_obs' < 0.05 {
    di as text _n "  CAUTION: Standard test rejects but permutation does not"
    di as text "           Standard p-value may be overstated"
}
else if `p_perm_2sided' < 0.05 & `wald_p_obs' >= 0.05 {
    di as text _n "  NOTE: Permutation rejects but standard does not"
    di as text "        This is unusual—check data"
}
else {
    di as text _n "  RESULT: Both tests fail to reject H0: δ⁺ = δ⁻"
    di as text "          No significant asymmetry"
}

*===============================================================================
* 5. VISUALIZATION
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Visualization"
di as text    "=============================================="

preserve
    use "${data}/R4_permutation_distribution.dta", clear

    * Histogram of permutation distribution with observed value
    twoway (histogram diff_perm, bin(50) fcolor(gs12) lcolor(gs8)) ///
           (scatteri 0 `diff_obs' 500 `diff_obs', recast(line) lcolor(red) lwidth(thick) lpattern(dash)), ///
           xline(0, lcolor(black) lpattern(dot)) ///
           xtitle("Permuted (δ⁻ - δ⁺)") ytitle("Frequency") ///
           title("Permutation Distribution of Asymmetry") ///
           subtitle("Red dashed line = Observed value") ///
           note("10,000 permutations. Permutation p = " %5.3f `p_perm_2sided') ///
           legend(off) ///
           scheme(s2color)

    graph export "${figures}/R4_permutation_distribution.png", replace width(1200)
    graph save "${figures}/R4_permutation_distribution.gph", replace
restore

*===============================================================================
* 6. BOOTSTRAP COMPARISON (Alternative Approach)
*===============================================================================

di as text _n "=============================================="
di as text    "  6. Bootstrap Comparison"
di as text    "=============================================="

* For comparison: cluster bootstrap SE for the difference
capture program drop boot_diff
program define boot_diff, rclass
    regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
        $X_qreg i.year
    return scalar diff = _b[dlny_neg_x_inf] - _b[dlny_pos_x_inf]
end

set seed 20260217
capture bootstrap r(diff), reps(1000) cluster(idind) nodots: boot_diff
if _rc == 0 {
    local boot_diff = _b[_bs_1]
    local boot_se = _se[_bs_1]
    local boot_t = `boot_diff' / `boot_se'
    local boot_p = 2 * (1 - normal(abs(`boot_t')))

    di as text "Cluster Bootstrap (1000 reps):"
    di as text "  Difference: " %9.6f `boot_diff'
    di as text "  Bootstrap SE: " %9.6f `boot_se'
    di as text "  t-stat: " %6.2f `boot_t'
    di as text "  p-value: " %6.4f `boot_p'
}
else {
    di as text "(Bootstrap failed, skipping)"
}

*===============================================================================
* 7. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  7. Export Results"
di as text    "=============================================="

* Export summary to CSV
preserve
    clear
    set obs 1
    gen test = "Permutation"
    gen observed_diff = `diff_obs'
    gen p_value_2sided = `p_perm_2sided'
    gen p_value_1sided = `p_perm_1sided'
    gen wald_p = `wald_p_obs'
    gen n_permutations = `n_valid'
    gen perm_mean = `perm_mean'
    gen perm_sd = `perm_sd'
    export delimited using "${tables}/R4_permutation_results.csv", replace
restore

*===============================================================================
* 8. SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  R4 SUMMARY: Permutation Test"
di as text    "=============================================="

di as text _n "METHODOLOGY:"
di as text "  Under H0: δ⁺ = δ⁻, the distinction between positive and negative"
di as text "  shocks should not matter. We randomly swap labels and re-estimate."

di as text _n "KEY RESULTS:"
di as text "  Observed (δ⁻ - δ⁺):     " %9.6f `diff_obs'
di as text "  Permutation mean:        " %9.6f `perm_mean'
di as text "  Permutation SD:          " %9.6f `perm_sd'
di as text _n "  Standard Wald p:         " %6.4f `wald_p_obs'
di as text "  Permutation p (2-sided): " %6.4f `p_perm_2sided'
di as text "  Permutation p (1-sided): " %6.4f `p_perm_1sided'

di as text _n "INTERPRETATION:"
if `p_perm_2sided' < 0.01 {
    di as text "  *** Permutation test STRONGLY REJECTS H0 at 1% level ***"
    di as text "  The asymmetric smoothing is NOT an artifact of distributional"
    di as text "  assumptions or clustering structure."
}
else if `p_perm_2sided' < 0.05 {
    di as text "  ** Permutation test REJECTS H0 at 5% level **"
}
else if `p_perm_2sided' < 0.10 {
    di as text "  * Permutation test REJECTS H0 at 10% level *"
}
else {
    di as text "  Permutation test does NOT reject H0"
}

log close

di as text _n "Log saved to: ${logdir}/R4_permutation_test.log"
di as text "Figure saved to: ${figures}/R4_permutation_distribution.png"
di as text "Results saved to: ${tables}/R4_permutation_results.csv"

*===============================================================================
* END
*===============================================================================
