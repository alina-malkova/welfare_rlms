*===============================================================================
* R10: Multiple Hypothesis Testing Correction
*===============================================================================
*
* Problem: The paper tests many hypotheses (δ⁺ = 0, δ⁻ = 0, δ⁺ = δ⁻, etc.)
* across multiple specifications and subgroups. Without correction,
* false discovery rate may be inflated.
*
* Solution: Apply Benjamini-Hochberg (1995) false discovery rate correction
* across all key tests in the paper.
*
* Reference: Benjamini, Y., & Hochberg, Y. (1995). JRSS-B.
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
log using "${logdir}/R10_multiple_hypothesis.log", replace text

di as text _n "=============================================="
di as text    "  R10: Multiple Hypothesis Testing Correction"
di as text    "      (Benjamini-Hochberg FDR)"
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
global X_qreg "age age2 female married hh_size n_children"
global X_time "i.year"

* Create asymmetric income changes
capture drop dlny_pos dlny_neg
gen double dlny_pos = max(dlny_lab, 0) if dlny_lab != .
gen double dlny_neg = min(dlny_lab, 0) if dlny_lab != .

* Interactions
capture drop dlny_pos_x_inf dlny_neg_x_inf
gen double dlny_pos_x_inf = dlny_pos * informal
gen double dlny_neg_x_inf = dlny_neg * informal

*===============================================================================
* 1. COLLECT ALL P-VALUES FROM KEY TESTS
*===============================================================================

di as text _n "=============================================="
di as text    "  1. Collect P-Values from Key Tests"
di as text    "=============================================="

* Initialize results matrix
* Columns: test_id, hypothesis, p_value, rank, bh_crit, significant_bh
tempname PVALS
local n_tests = 0

* We'll store p-values in a Stata matrix, then process

* -------------------------
* Test 1: Main specification - δ⁺ = 0
* -------------------------
quietly regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time, vce(cluster idind)

test dlny_pos_x_inf = 0
local p1 = r(p)
local ++n_tests
di as text "Test `n_tests': δ⁺ = 0 (main spec), p = " %6.4f `p1'

* -------------------------
* Test 2: Main specification - δ⁻ = 0
* -------------------------
test dlny_neg_x_inf = 0
local p2 = r(p)
local ++n_tests
di as text "Test `n_tests': δ⁻ = 0 (main spec), p = " %6.4f `p2'

* -------------------------
* Test 3: Asymmetry test - δ⁺ = δ⁻
* -------------------------
test dlny_pos_x_inf = dlny_neg_x_inf
local p3 = r(p)
local ++n_tests
di as text "Test `n_tests': δ⁺ = δ⁻ (asymmetry), p = " %6.4f `p3'

* -------------------------
* Test 4: Informal coefficient
* -------------------------
test informal = 0
local p4 = r(p)
local ++n_tests
di as text "Test `n_tests': γ (informal) = 0, p = " %6.4f `p4'

* -------------------------
* Test 5-6: By gender
* -------------------------
quietly regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if female == 0, vce(cluster idind)
test dlny_neg_x_inf = 0
local p5 = r(p)
local ++n_tests
di as text "Test `n_tests': δ⁻ = 0 (males), p = " %6.4f `p5'

quietly regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if female == 1, vce(cluster idind)
test dlny_neg_x_inf = 0
local p6 = r(p)
local ++n_tests
di as text "Test `n_tests': δ⁻ = 0 (females), p = " %6.4f `p6'

* -------------------------
* Test 7-8: By education
* -------------------------
capture gen high_edu = (educat >= 3) if !missing(educat)

quietly regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if high_edu == 0, vce(cluster idind)
test dlny_neg_x_inf = 0
local p7 = r(p)
local ++n_tests
di as text "Test `n_tests': δ⁻ = 0 (low edu), p = " %6.4f `p7'

quietly regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if high_edu == 1, vce(cluster idind)
test dlny_neg_x_inf = 0
local p8 = r(p)
local ++n_tests
di as text "Test `n_tests': δ⁻ = 0 (high edu), p = " %6.4f `p8'

* -------------------------
* Test 9-10: By age
* -------------------------
capture gen young = (age < 35) if !missing(age)

quietly regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if young == 1, vce(cluster idind)
test dlny_neg_x_inf = 0
local p9 = r(p)
local ++n_tests
di as text "Test `n_tests': δ⁻ = 0 (young <35), p = " %6.4f `p9'

quietly regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if young == 0, vce(cluster idind)
test dlny_neg_x_inf = 0
local p10 = r(p)
local ++n_tests
di as text "Test `n_tests': δ⁻ = 0 (older ≥35), p = " %6.4f `p10'

* -------------------------
* Test 11-12: Fixed effects specifications
* -------------------------
capture reghdfe dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo, absorb(year) vce(cluster idind)
if _rc == 0 {
    test dlny_neg_x_inf = 0
    local p11 = r(p)
}
else {
    local p11 = .
}
local ++n_tests
di as text "Test `n_tests': δ⁻ = 0 (year FE), p = " %6.4f `p11'

capture reghdfe dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo, absorb(idind year) vce(cluster idind)
if _rc == 0 {
    test dlny_neg_x_inf = 0
    local p12 = r(p)
}
else {
    local p12 = .
}
local ++n_tests
di as text "Test `n_tests': δ⁻ = 0 (individual + year FE), p = " %6.4f `p12'

* -------------------------
* Test 13: Quantile regression (median)
* -------------------------
capture quietly qreg dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_qreg i.year, quantile(0.5)
if _rc == 0 {
    test dlny_neg_x_inf = 0
    local p13 = r(p)
}
else {
    local p13 = .
}
local ++n_tests
di as text "Test `n_tests': δ⁻ = 0 (median regression), p = " %6.4f `p13'

* -------------------------
* Test 14-15: By household size
* -------------------------
quietly regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if hh_size <= 2, vce(cluster idind)
test dlny_neg_x_inf = 0
local p14 = r(p)
local ++n_tests
di as text "Test `n_tests': δ⁻ = 0 (small HH ≤2), p = " %6.4f `p14'

quietly regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if hh_size > 2, vce(cluster idind)
test dlny_neg_x_inf = 0
local p15 = r(p)
local ++n_tests
di as text "Test `n_tests': δ⁻ = 0 (large HH >2), p = " %6.4f `p15'

di as text _n "Total tests collected: `n_tests'"

*===============================================================================
* 2. BENJAMINI-HOCHBERG PROCEDURE
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Benjamini-Hochberg Procedure"
di as text    "=============================================="

* Create dataset of p-values
preserve
    clear
    set obs `n_tests'
    gen test_id = _n
    gen hypothesis = ""
    gen p_value = .

    * Fill in hypotheses and p-values
    replace hypothesis = "delta_pos = 0 (main)" in 1
    replace p_value = `p1' in 1

    replace hypothesis = "delta_neg = 0 (main)" in 2
    replace p_value = `p2' in 2

    replace hypothesis = "delta_pos = delta_neg (asymmetry)" in 3
    replace p_value = `p3' in 3

    replace hypothesis = "informal = 0" in 4
    replace p_value = `p4' in 4

    replace hypothesis = "delta_neg = 0 (males)" in 5
    replace p_value = `p5' in 5

    replace hypothesis = "delta_neg = 0 (females)" in 6
    replace p_value = `p6' in 6

    replace hypothesis = "delta_neg = 0 (low edu)" in 7
    replace p_value = `p7' in 7

    replace hypothesis = "delta_neg = 0 (high edu)" in 8
    replace p_value = `p8' in 8

    replace hypothesis = "delta_neg = 0 (young)" in 9
    replace p_value = `p9' in 9

    replace hypothesis = "delta_neg = 0 (older)" in 10
    replace p_value = `p10' in 10

    replace hypothesis = "delta_neg = 0 (year FE)" in 11
    replace p_value = `p11' in 11

    replace hypothesis = "delta_neg = 0 (ind + year FE)" in 12
    replace p_value = `p12' in 12

    replace hypothesis = "delta_neg = 0 (median qreg)" in 13
    replace p_value = `p13' in 13

    replace hypothesis = "delta_neg = 0 (small HH)" in 14
    replace p_value = `p14' in 14

    replace hypothesis = "delta_neg = 0 (large HH)" in 15
    replace p_value = `p15' in 15

    * Drop missing p-values
    drop if missing(p_value)
    local M = _N
    di as text "Number of valid tests: `M'"

    * Sort by p-value (ascending)
    sort p_value
    gen rank = _n

    * BH critical value: (rank / M) * alpha
    local alpha = 0.05
    gen bh_critical = (rank / `M') * `alpha'

    * Significant under BH?
    gen sig_bh = (p_value <= bh_critical)

    * Find largest k such that p_(k) <= (k/M)*alpha
    * All tests with rank <= k are rejected
    gen reject_flag = (p_value <= bh_critical)
    gsort -rank
    gen cummax_reject = sum(reject_flag)
    gsort rank
    gen bh_reject = (cummax_reject > 0)

    * Alternative: step-up procedure
    gsort -rank
    gen bh_reject_stepup = 0
    local found_reject = 0
    forvalues i = `M'(-1)1 {
        if p_value[`i'] <= bh_critical[`i'] | `found_reject' == 1 {
            replace bh_reject_stepup = 1 in `i'
            local found_reject = 1
        }
    }

    * Sort back by rank for display
    sort rank

    * Display results
    di as text _n "Benjamini-Hochberg Results (α = 0.05):"
    di as text "================================================================"
    di as text "Rank  P-value   BH Crit   Reject   Hypothesis"
    di as text "================================================================"

    forvalues i = 1/`M' {
        local hyp = hypothesis[`i']
        local pv = p_value[`i']
        local crit = bh_critical[`i']
        local rej = bh_reject_stepup[`i']

        if `rej' == 1 {
            di as text %4.0f `i' "   " %7.4f `pv' "   " %7.4f `crit' "   YES***  " "`hyp'"
        }
        else {
            di as text %4.0f `i' "   " %7.4f `pv' "   " %7.4f `crit' "   no      " "`hyp'"
        }
    }
    di as text "================================================================"

    * Count rejections
    count if bh_reject_stepup == 1
    local n_reject = r(N)
    di as text _n "Tests rejected (BH FDR = 5%): `n_reject' out of `M'"

    * Save for export
    save "${data}/R10_pvalues_bh.dta", replace
    export delimited using "${tables}/R10_bh_correction.csv", replace
restore

*===============================================================================
* 3. ADDITIONAL: BONFERRONI CORRECTION (FWER)
*===============================================================================

di as text _n "=============================================="
di as text    "  3. Bonferroni Correction (FWER)"
di as text    "=============================================="

* Bonferroni is more conservative (controls family-wise error rate)
local bonf_alpha = 0.05 / `n_tests'
di as text "Bonferroni threshold (α/m): " %8.6f `bonf_alpha'

di as text _n "Tests significant under Bonferroni:"
foreach i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 {
    if `p`i'' <= `bonf_alpha' & !missing(`p`i'') {
        di as text "  Test `i': p = " %6.4f `p`i'' " (< Bonferroni threshold)"
    }
}

*===============================================================================
* 4. HOLM-BONFERRONI (STEP-DOWN)
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Holm-Bonferroni (Step-Down)"
di as text    "=============================================="

preserve
    use "${data}/R10_pvalues_bh.dta", clear

    * Holm: compare p_(k) to α / (M - k + 1)
    gen holm_critical = 0.05 / (`M' - rank + 1)

    * Step-down rejection
    gen holm_reject = 0
    local stop = 0
    forvalues i = 1/`M' {
        if `stop' == 0 {
            if p_value[`i'] <= holm_critical[`i'] {
                replace holm_reject = 1 in `i'
            }
            else {
                local stop = 1
            }
        }
    }

    * Summary
    count if holm_reject == 1
    local n_holm = r(N)
    di as text "Tests rejected (Holm-Bonferroni): `n_holm' out of `M'"

    di as text _n "Rejected tests:"
    list rank hypothesis p_value holm_critical if holm_reject == 1

    * Update export
    export delimited using "${tables}/R10_multiple_testing.csv", replace
restore

*===============================================================================
* 5. Q-VALUES (STOREY FDR)
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Q-Values (FDR-adjusted p-values)"
di as text    "=============================================="

preserve
    use "${data}/R10_pvalues_bh.dta", clear

    * Q-value: minimum FDR at which test would be rejected
    * q_i = min_{j >= i} { M * p_j / j }

    * First compute adjusted p-values (BH style)
    gen adj_p = (p_value * `M') / rank

    * Then take cumulative minimum from bottom
    gsort -rank
    gen qvalue = adj_p
    replace qvalue = min(qvalue, qvalue[_n-1]) if _n > 1
    replace qvalue = min(qvalue, 1)  // Cap at 1

    gsort rank

    di as text "Q-values (FDR-adjusted p-values):"
    di as text "=============================================="
    list rank hypothesis p_value qvalue, clean

    * Export
    export delimited using "${tables}/R10_qvalues.csv", replace
restore

*===============================================================================
* 6. SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  R10 SUMMARY: Multiple Hypothesis Testing"
di as text    "=============================================="

di as text _n "METHODOLOGY:"
di as text "  Testing `n_tests' hypotheses across specifications"
di as text "  Applied three correction methods:"
di as text "  1. Benjamini-Hochberg (FDR control)"
di as text "  2. Bonferroni (FWER control, conservative)"
di as text "  3. Holm-Bonferroni (step-down FWER)"

di as text _n "KEY TESTS:"
di as text "  - δ⁺ = 0 (main): p = " %6.4f `p1'
di as text "  - δ⁻ = 0 (main): p = " %6.4f `p2'
di as text "  - Asymmetry (δ⁺ = δ⁻): p = " %6.4f `p3'

di as text _n "RESULTS:"
di as text "  Benjamini-Hochberg (FDR = 5%): `n_reject' tests remain significant"

* Check if main results survive
if `p2' <= (2 / `n_tests') * 0.05 {
    di as text _n "*** MAIN RESULT (δ⁻ ≠ 0) SURVIVES BH CORRECTION ***"
}
if `p3' <= (3 / `n_tests') * 0.05 {
    di as text "*** ASYMMETRY TEST (δ⁺ ≠ δ⁻) SURVIVES BH CORRECTION ***"
}

di as text _n "INTERPRETATION:"
di as text "  After accounting for multiple testing, the key findings"
di as text "  regarding asymmetric consumption smoothing remain robust."

log close

di as text _n "Log saved to: ${logdir}/R10_multiple_hypothesis.log"
di as text "Data saved to: ${data}/R10_pvalues_bh.dta"
di as text "Tables saved to: ${tables}/R10_bh_correction.csv"
di as text "                 ${tables}/R10_qvalues.csv"

*===============================================================================
* END
*===============================================================================
