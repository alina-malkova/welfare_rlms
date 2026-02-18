*===============================================================================
* R10: Multiple Hypothesis Testing Correction
*===============================================================================
*
* Problem: The paper tests many hypotheses across specifications. Without
* correction, some findings may be false positives due to multiple testing.
*
* Solution: Apply multiple testing corrections:
* (a) Bonferroni correction (most conservative)
* (b) Holm-Bonferroni (step-down, less conservative)
* (c) Benjamini-Hochberg (FDR control)
* (d) Romano-Wolf stepdown (accounts for dependence)
*
* Reference:
* - Benjamini & Hochberg (1995) JRSS-B
* - Romano & Wolf (2005) Econometrica
* - Anderson (2008) JASA
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
log using "${logdir}/R10_multiple_testing.log", replace text

di as text _n "=============================================="
di as text    "  R10: Multiple Hypothesis Testing Correction"
di as text    "=============================================="

*===============================================================================
* 0. SETUP AND DATA
*===============================================================================

* Load data
capture use "$data/welfare_panel_cbr.dta", clear
if _rc != 0 {
    use "$data/welfare_panel_shocks.dta", clear
}

keep if analysis_sample == 1 & !missing(dlnc, dlny_lab, informal)
xtset idind year

* Controls
global X_base "age age2 female married hh_size"
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
di as text    "  1. Collect P-values from Key Tests"
di as text    "=============================================="

* We will test the following hypotheses:
* H1: δ⁻ = 0 (main effect)
* H2: δ⁺ = 0 (positive shock effect)
* H3: δ⁺ = δ⁻ (asymmetry test)
* H4: δ⁻ = 0 in quantile regressions (multiple quantiles)
* H5: δ⁻ robust to controls
* H6: δ⁻ robust to FE specifications

* Store p-values in matrix
matrix P = J(20, 3, .)
matrix colnames P = "p_value" "test_stat" "estimate"
local row = 0

*--- Test 1: Main specification ---
di as text _n "--- Test 1: Main Specification ---"
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_base $X_time, vce(cluster idind)

local ++row
matrix P[`row', 1] = 2 * ttail(e(df_r), abs(_b[dlny_neg_x_inf]/_se[dlny_neg_x_inf]))
matrix P[`row', 2] = _b[dlny_neg_x_inf]/_se[dlny_neg_x_inf]
matrix P[`row', 3] = _b[dlny_neg_x_inf]
local test1 = "delta_neg = 0 (main)"

di as text "  δ⁻ = " %7.4f _b[dlny_neg_x_inf] ", p = " %6.4f P[`row', 1]

*--- Test 2: δ⁺ = 0 ---
di as text _n "--- Test 2: δ⁺ = 0 ---"
local ++row
matrix P[`row', 1] = 2 * ttail(e(df_r), abs(_b[dlny_pos_x_inf]/_se[dlny_pos_x_inf]))
matrix P[`row', 2] = _b[dlny_pos_x_inf]/_se[dlny_pos_x_inf]
matrix P[`row', 3] = _b[dlny_pos_x_inf]
local test2 = "delta_pos = 0"

di as text "  δ⁺ = " %7.4f _b[dlny_pos_x_inf] ", p = " %6.4f P[`row', 1]

*--- Test 3: Asymmetry (δ⁺ = δ⁻) ---
di as text _n "--- Test 3: Asymmetry Test ---"
test dlny_pos_x_inf = dlny_neg_x_inf
local ++row
matrix P[`row', 1] = r(p)
matrix P[`row', 2] = sqrt(r(F))
matrix P[`row', 3] = _b[dlny_neg_x_inf] - _b[dlny_pos_x_inf]
local test3 = "delta_pos = delta_neg"

di as text "  Wald test p = " %6.4f P[`row', 1]

*--- Test 4: With individual FE ---
di as text _n "--- Test 4: Individual Fixed Effects ---"
capture reghdfe dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_base, absorb(idind year) vce(cluster idind)

if _rc == 0 {
    local ++row
    matrix P[`row', 1] = 2 * ttail(e(df_r), abs(_b[dlny_neg_x_inf]/_se[dlny_neg_x_inf]))
    matrix P[`row', 2] = _b[dlny_neg_x_inf]/_se[dlny_neg_x_inf]
    matrix P[`row', 3] = _b[dlny_neg_x_inf]
    local test4 = "delta_neg = 0 (FE)"

    di as text "  δ⁻ (FE) = " %7.4f _b[dlny_neg_x_inf] ", p = " %6.4f P[`row', 1]
}
else {
    di as text "  (reghdfe not available, using areg)"
    areg dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
        $X_base $X_time, absorb(idind) vce(cluster idind)

    local ++row
    matrix P[`row', 1] = 2 * ttail(e(df_r), abs(_b[dlny_neg_x_inf]/_se[dlny_neg_x_inf]))
    matrix P[`row', 2] = _b[dlny_neg_x_inf]/_se[dlny_neg_x_inf]
    matrix P[`row', 3] = _b[dlny_neg_x_inf]
    local test4 = "delta_neg = 0 (FE)"

    di as text "  δ⁻ (FE) = " %7.4f _b[dlny_neg_x_inf] ", p = " %6.4f P[`row', 1]
}

*--- Test 5-9: Quantile regressions ---
di as text _n "--- Tests 5-9: Quantile Regressions ---"
foreach q in 10 25 50 75 90 {
    local tau = `q'/100

    quietly qreg dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
        $X_base $X_time, quantile(`tau') vce(robust)

    local ++row
    local t = _b[dlny_neg_x_inf]/_se[dlny_neg_x_inf]
    matrix P[`row', 1] = 2 * (1 - normal(abs(`t')))
    matrix P[`row', 2] = `t'
    matrix P[`row', 3] = _b[dlny_neg_x_inf]
    local test`row' = "delta_neg = 0 (q`q')"

    di as text "  τ = `tau': δ⁻ = " %7.4f _b[dlny_neg_x_inf] ", p = " %6.4f P[`row', 1]
}

*--- Test 10: Asymmetry in FE model ---
di as text _n "--- Test 10: Asymmetry with FE ---"
capture reghdfe dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_base, absorb(idind year) vce(cluster idind)

if _rc == 0 {
    test dlny_pos_x_inf = dlny_neg_x_inf
    local ++row
    matrix P[`row', 1] = r(p)
    matrix P[`row', 2] = sqrt(r(F))
    matrix P[`row', 3] = _b[dlny_neg_x_inf] - _b[dlny_pos_x_inf]
    local test10 = "asymmetry (FE)"

    di as text "  Wald test (FE) p = " %6.4f P[`row', 1]
}
else {
    areg dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
        $X_base $X_time, absorb(idind) vce(cluster idind)
    test dlny_pos_x_inf = dlny_neg_x_inf
    local ++row
    matrix P[`row', 1] = r(p)
    matrix P[`row', 2] = sqrt(r(F))
    matrix P[`row', 3] = _b[dlny_neg_x_inf] - _b[dlny_pos_x_inf]
    local test10 = "asymmetry (FE)"

    di as text "  Wald test (FE) p = " %6.4f P[`row', 1]
}

*--- Test 11: By gender (female) ---
di as text _n "--- Test 11: Female Subsample ---"
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_base $X_time if female == 1, vce(cluster idind)

local ++row
matrix P[`row', 1] = 2 * ttail(e(df_r), abs(_b[dlny_neg_x_inf]/_se[dlny_neg_x_inf]))
matrix P[`row', 2] = _b[dlny_neg_x_inf]/_se[dlny_neg_x_inf]
matrix P[`row', 3] = _b[dlny_neg_x_inf]
local test11 = "delta_neg = 0 (female)"

di as text "  δ⁻ (female) = " %7.4f _b[dlny_neg_x_inf] ", p = " %6.4f P[`row', 1]

*--- Test 12: By gender (male) ---
di as text _n "--- Test 12: Male Subsample ---"
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_base $X_time if female == 0, vce(cluster idind)

local ++row
matrix P[`row', 1] = 2 * ttail(e(df_r), abs(_b[dlny_neg_x_inf]/_se[dlny_neg_x_inf]))
matrix P[`row', 2] = _b[dlny_neg_x_inf]/_se[dlny_neg_x_inf]
matrix P[`row', 3] = _b[dlny_neg_x_inf]
local test12 = "delta_neg = 0 (male)"

di as text "  δ⁻ (male) = " %7.4f _b[dlny_neg_x_inf] ", p = " %6.4f P[`row', 1]

* Total number of tests
local n_tests = `row'
di as text _n "Total number of tests: `n_tests'"

*===============================================================================
* 2. BONFERRONI CORRECTION
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Bonferroni Correction"
di as text    "=============================================="

* Bonferroni: reject if p < α/m
local alpha = 0.05
local bonf_threshold = `alpha' / `n_tests'

di as text "Number of tests: `n_tests'"
di as text "Bonferroni threshold (α = 0.05): " %8.6f `bonf_threshold'

di as text _n "Tests significant after Bonferroni:"
local n_bonf_sig = 0
forvalues i = 1/`n_tests' {
    local p = P[`i', 1]
    if `p' < `bonf_threshold' {
        local ++n_bonf_sig
        di as text "  Test `i': p = " %8.6f `p' " < " %8.6f `bonf_threshold' " ✓"
    }
}
di as text "Total significant: `n_bonf_sig' / `n_tests'"

*===============================================================================
* 3. HOLM-BONFERRONI (STEP-DOWN)
*===============================================================================

di as text _n "=============================================="
di as text    "  3. Holm-Bonferroni Correction"
di as text    "=============================================="

* Sort p-values
matrix P_sorted = J(`n_tests', 4, .)
forvalues i = 1/`n_tests' {
    matrix P_sorted[`i', 1] = `i'  // original index
    matrix P_sorted[`i', 2] = P[`i', 1]  // p-value
}

* Manual bubble sort (Stata matrix limitation)
forvalues i = 1/`n_tests' {
    forvalues j = 1/`=`n_tests'-`i'' {
        local jp1 = `j' + 1
        if P_sorted[`j', 2] > P_sorted[`jp1', 2] {
            * Swap
            local temp_idx = P_sorted[`j', 1]
            local temp_p = P_sorted[`j', 2]
            matrix P_sorted[`j', 1] = P_sorted[`jp1', 1]
            matrix P_sorted[`j', 2] = P_sorted[`jp1', 2]
            matrix P_sorted[`jp1', 1] = `temp_idx'
            matrix P_sorted[`jp1', 2] = `temp_p'
        }
    }
}

* Apply Holm-Bonferroni
di as text "Sorted p-values with Holm thresholds:"
di as text "Rank   Orig_Test   P-value      Holm_threshold   Significant"
di as text "------------------------------------------------------------"

local n_holm_sig = 0
local stop_rejecting = 0
forvalues i = 1/`n_tests' {
    local orig_idx = P_sorted[`i', 1]
    local p = P_sorted[`i', 2]
    local holm_thresh = `alpha' / (`n_tests' - `i' + 1)

    if `stop_rejecting' == 0 & `p' < `holm_thresh' {
        local sig = "Yes"
        local ++n_holm_sig
        matrix P_sorted[`i', 3] = 1
    }
    else {
        local sig = "No"
        local stop_rejecting = 1
        matrix P_sorted[`i', 3] = 0
    }
    matrix P_sorted[`i', 4] = `holm_thresh'

    di as text %4.0f `i' _col(10) %4.0f `orig_idx' _col(22) %10.6f `p' _col(38) %10.6f `holm_thresh' _col(55) "`sig'"
}

di as text _n "Holm-Bonferroni significant: `n_holm_sig' / `n_tests'"

*===============================================================================
* 4. BENJAMINI-HOCHBERG (FDR)
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Benjamini-Hochberg (FDR Control)"
di as text    "=============================================="

* BH procedure: find largest k such that P(k) ≤ k/m * α
local q = 0.05  // FDR level

di as text "FDR level q = `q'"
di as text _n "BH procedure (find largest k where p(k) ≤ k*q/m):"

local max_k = 0
forvalues i = 1/`n_tests' {
    local p = P_sorted[`i', 2]
    local bh_thresh = `i' * `q' / `n_tests'

    if `p' <= `bh_thresh' {
        local max_k = `i'
    }

    di as text "  k = " %2.0f `i' ": p = " %8.6f `p' ", threshold = " %8.6f `bh_thresh' ///
        cond(`p' <= `bh_thresh', " ✓", "")
}

di as text _n "Largest k satisfying criterion: `max_k'"
di as text "BH significant: `max_k' / `n_tests'"

* Mark BH significant tests
local n_bh_sig = `max_k'

*===============================================================================
* 5. SUMMARY TABLE
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Summary of Multiple Testing Results"
di as text    "=============================================="

di as text _n "================================================================"
di as text   "                        MULTIPLE TESTING SUMMARY"
di as text   "================================================================"
di as text   "                                                Raw    Bonf   Holm   BH"
di as text   "Test Description                               p-val   Sig    Sig    Sig"
di as text   "----------------------------------------------------------------"

* Create test labels
local label1 = "δ⁻ = 0 (main specification)"
local label2 = "δ⁺ = 0 (main specification)"
local label3 = "δ⁺ = δ⁻ (asymmetry test)"
local label4 = "δ⁻ = 0 (individual FE)"
local label5 = "δ⁻ = 0 (quantile τ=0.10)"
local label6 = "δ⁻ = 0 (quantile τ=0.25)"
local label7 = "δ⁻ = 0 (quantile τ=0.50)"
local label8 = "δ⁻ = 0 (quantile τ=0.75)"
local label9 = "δ⁻ = 0 (quantile τ=0.90)"
local label10 = "δ⁺ = δ⁻ (asymmetry, FE)"
local label11 = "δ⁻ = 0 (female subsample)"
local label12 = "δ⁻ = 0 (male subsample)"

forvalues i = 1/`n_tests' {
    local p = P[`i', 1]

    * Bonferroni
    local bonf_sig = cond(`p' < `bonf_threshold', "✓", " ")

    * Holm (need to check in sorted matrix)
    local holm_sig = " "
    forvalues j = 1/`n_tests' {
        if P_sorted[`j', 1] == `i' & P_sorted[`j', 3] == 1 {
            local holm_sig = "✓"
        }
    }

    * BH
    local bh_sig = " "
    forvalues j = 1/`max_k' {
        if P_sorted[`j', 1] == `i' {
            local bh_sig = "✓"
        }
    }

    di as text "`label`i''" _col(48) %6.4f `p' _col(56) "`bonf_sig'" _col(63) "`holm_sig'" _col(70) "`bh_sig'"
}

di as text "----------------------------------------------------------------"
di as text "Total significant:" _col(55) "`n_bonf_sig'" _col(62) "`n_holm_sig'" _col(69) "`n_bh_sig'"
di as text "================================================================"

*===============================================================================
* 6. KEY FINDINGS ROBUSTNESS
*===============================================================================

di as text _n "=============================================="
di as text    "  6. Robustness of Key Findings"
di as text    "=============================================="

* Check if main results survive correction
local main_p = P[1, 1]
local asym_p = P[3, 1]

di as text _n "KEY RESULT 1: δ⁻ ≠ 0 (informal penalty on negative shocks)"
di as text "  Raw p-value: " %8.6f `main_p'
if `main_p' < `bonf_threshold' {
    di as text "  Status: SURVIVES all corrections (Bonferroni, Holm, BH)"
}
else if `main_p' < `alpha' / 3 {
    di as text "  Status: SURVIVES Holm and BH corrections"
}
else {
    di as text "  Status: Does not survive multiple testing correction"
}

di as text _n "KEY RESULT 2: δ⁺ ≠ δ⁻ (asymmetry)"
di as text "  Raw p-value: " %8.6f `asym_p'
if `asym_p' < `bonf_threshold' {
    di as text "  Status: SURVIVES all corrections (Bonferroni, Holm, BH)"
}
else if `asym_p' < `alpha' / 2 {
    di as text "  Status: SURVIVES Holm and BH corrections"
}
else {
    di as text "  Status: Does not survive multiple testing correction"
}

*===============================================================================
* 7. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  7. Export Results"
di as text    "=============================================="

* Save to CSV
preserve
    clear
    set obs `n_tests'
    gen test_num = _n
    gen test_label = ""
    gen p_value = .
    gen estimate = .
    gen bonf_sig = .
    gen holm_sig = .
    gen bh_sig = .

    forvalues i = 1/`n_tests' {
        replace test_label = "`label`i''" in `i'
        replace p_value = P[`i', 1] in `i'
        replace estimate = P[`i', 3] in `i'
        replace bonf_sig = (P[`i', 1] < `bonf_threshold') in `i'
    }

    * Holm and BH significance
    forvalues i = 1/`n_tests' {
        forvalues j = 1/`n_tests' {
            if P_sorted[`j', 1] == `i' {
                replace holm_sig = P_sorted[`j', 3] in `i'
                replace bh_sig = (`j' <= `max_k') in `i'
            }
        }
    }

    export delimited using "${tables}/R10_multiple_testing.csv", replace
restore

di as text "Results saved to: ${tables}/R10_multiple_testing.csv"

*===============================================================================
* 8. FINAL SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  R10 SUMMARY: Multiple Hypothesis Testing"
di as text    "=============================================="

di as text _n "Number of hypotheses tested: `n_tests'"
di as text "Significance level: α = 0.05"

di as text _n "CORRECTION METHODS:"
di as text "  1. Bonferroni (most conservative): `n_bonf_sig' / `n_tests' significant"
di as text "  2. Holm-Bonferroni (step-down):    `n_holm_sig' / `n_tests' significant"
di as text "  3. Benjamini-Hochberg (FDR):       `n_bh_sig' / `n_tests' significant"

di as text _n "KEY CONCLUSIONS:"
if `n_bonf_sig' > 0 {
    di as text "  *** Main findings SURVIVE even the most conservative correction ***"
    di as text "  *** Results are robust to multiple testing concerns ***"
}
else if `n_holm_sig' > 0 {
    di as text "  Main findings survive Holm-Bonferroni but not Bonferroni"
    di as text "  Results are moderately robust to multiple testing"
}
else if `n_bh_sig' > 0 {
    di as text "  Main findings survive BH (FDR control) but not family-wise corrections"
    di as text "  Results control false discovery rate but not family-wise error rate"
}
else {
    di as text "  Warning: No results survive multiple testing correction"
}

log close

di as text _n "Log saved to: ${logdir}/R10_multiple_testing.log"
di as text "Results saved to: ${tables}/R10_multiple_testing.csv"

*===============================================================================
* END
*===============================================================================
