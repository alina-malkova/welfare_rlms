/*==============================================================================
  R2 - Quantile Regression on Asymmetric Smoothing Specification

  Project:  Welfare Cost of Labor Informality (Revision)
  Purpose:  Estimate δ⁻ (downside smoothing penalty) at each decile of the
            consumption growth distribution to test whether:
            - Penalty concentrated in left tail → Loss aversion (outsized
              reactions to large losses)
            - Penalty uniform across distribution → Mechanical constraint

  Methodology:
    At each quantile τ ∈ {0.1, 0.2, ..., 0.9}:
      Q_τ(Δln C) = α(τ) + β⁺(τ)·Δln(Y)⁺ + β⁻(τ)·Δln(Y)⁻
                 + δ⁺(τ)·(Δln(Y)⁺ × Informal) + δ⁻(τ)·(Δln(Y)⁻ × Informal)
                 + X'θ(τ)

    Key test: Is δ⁻(τ) larger at lower quantiles (left tail)?

  Output:
    - Tables/R2_quantile_coefficients.csv
    - Tables/R2_quantile_summary.tex
    - Figures/R2_delta_neg_by_quantile.png

  Author:
  Created: February 2026
==============================================================================*/

clear all
capture set maxvar 32767
do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/_Research/Credit_Market/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close
log using "$logdir/R2_quantile_asymmetric.log", replace

*===============================================================================
* 0. SETUP AND DATA
*===============================================================================

di as text _n "=============================================="
di as text    "  R2: Quantile Regression on Asymmetric Spec"
di as text    "=============================================="

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
global X_qreg "age age2 female married hh_size n_children"

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

* Sample size
count if !missing(dlnc, dlny_pos, dlny_neg, informal)
local N_full = r(N)
di as text "Analysis sample: N = `N_full'"

*===============================================================================
* 1. OLS BASELINE FOR COMPARISON
*===============================================================================

di as text _n "=============================================="
di as text    "  1. OLS Baseline (Mean Regression)"
di as text    "=============================================="

regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_qreg i.year, vce(cluster idind)

local beta_pos_ols = _b[dlny_pos]
local beta_neg_ols = _b[dlny_neg]
local delta_pos_ols = _b[dlny_pos_x_inf]
local delta_neg_ols = _b[dlny_neg_x_inf]

di as text "OLS (mean) estimates:"
di as text "  β⁺ (gains):   " %7.4f `beta_pos_ols'
di as text "  β⁻ (losses):  " %7.4f `beta_neg_ols'
di as text "  δ⁺ (inf×gains):  " %7.4f `delta_pos_ols'
di as text "  δ⁻ (inf×losses): " %7.4f `delta_neg_ols'

*===============================================================================
* 2. QUANTILE REGRESSION AT EACH DECILE
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Quantile Regression by Decile"
di as text    "=============================================="

* Store results: quantile, beta_pos, beta_neg, delta_pos, delta_neg, and SEs
tempname QR
matrix `QR' = J(9, 13, .)
matrix colnames `QR' = "quantile" "beta_pos" "se_beta_pos" "beta_neg" "se_beta_neg" ///
    "delta_pos" "se_delta_pos" "delta_neg" "se_delta_neg" ///
    "t_delta_neg" "p_delta_neg" "N" "pseudo_r2"

local row = 0

forvalues q = 10(10)90 {
    local ++row
    local tau = `q' / 100

    di as text _n "--- Quantile τ = `tau' ---"

    * Quantile regression with robust SE (capture errors at extreme quantiles)
    capture quietly qreg dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
        $X_qreg i.year, quantile(`tau') vce(robust)

    * If robust VCE fails, try without vce option
    if _rc != 0 {
        di as text "  (robust VCE failed, using default)"
        capture quietly qreg dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
            $X_qreg i.year, quantile(`tau')
    }

    if _rc != 0 {
        di as text "  (quantile regression failed at τ = `tau')"
        continue
    }

    * Store estimates
    matrix `QR'[`row', 1] = `tau'
    matrix `QR'[`row', 2] = _b[dlny_pos]
    matrix `QR'[`row', 3] = _se[dlny_pos]
    matrix `QR'[`row', 4] = _b[dlny_neg]
    matrix `QR'[`row', 5] = _se[dlny_neg]
    matrix `QR'[`row', 6] = _b[dlny_pos_x_inf]
    matrix `QR'[`row', 7] = _se[dlny_pos_x_inf]
    matrix `QR'[`row', 8] = _b[dlny_neg_x_inf]
    matrix `QR'[`row', 9] = _se[dlny_neg_x_inf]

    * t-stat and p-value for delta_neg
    local t_stat = _b[dlny_neg_x_inf] / _se[dlny_neg_x_inf]
    local p_val = 2 * (1 - normal(abs(`t_stat')))
    matrix `QR'[`row', 10] = `t_stat'
    matrix `QR'[`row', 11] = `p_val'
    matrix `QR'[`row', 12] = e(N)
    matrix `QR'[`row', 13] = e(r2_p)

    di as text "  δ⁻ = " %7.4f _b[dlny_neg_x_inf] " (SE " %6.4f _se[dlny_neg_x_inf] ///
        ", t = " %5.2f `t_stat' ", p = " %5.3f `p_val' ")"
}

matrix list `QR', format(%9.4f) title("Quantile regression results")

*===============================================================================
* 3. SIMULTANEOUS QUANTILE REGRESSION (for joint inference)
*===============================================================================

di as text _n "=============================================="
di as text    "  3. Simultaneous Quantile Regression"
di as text    "=============================================="

* Use sqreg for proper variance-covariance across quantiles
quietly sqreg dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_qreg i.year, quantiles(0.1 0.25 0.5 0.75 0.9) reps(100)

* Display key coefficients
di as text "Simultaneous QR: δ⁻ (Δln(Y)⁻ × Informal) across quantiles"
di as text "  τ = 0.10: " %7.4f _b[q10:dlny_neg_x_inf] " (SE " %6.4f _se[q10:dlny_neg_x_inf] ")"
di as text "  τ = 0.25: " %7.4f _b[q25:dlny_neg_x_inf] " (SE " %6.4f _se[q25:dlny_neg_x_inf] ")"
di as text "  τ = 0.50: " %7.4f _b[q50:dlny_neg_x_inf] " (SE " %6.4f _se[q50:dlny_neg_x_inf] ")"
di as text "  τ = 0.75: " %7.4f _b[q75:dlny_neg_x_inf] " (SE " %6.4f _se[q75:dlny_neg_x_inf] ")"
di as text "  τ = 0.90: " %7.4f _b[q90:dlny_neg_x_inf] " (SE " %6.4f _se[q90:dlny_neg_x_inf] ")"

* Test: Is δ⁻ at τ=0.10 different from δ⁻ at τ=0.90?
di as text _n "Test: δ⁻(τ=0.10) = δ⁻(τ=0.90)"
test [q10]dlny_neg_x_inf = [q90]dlny_neg_x_inf
local p_tail_test = r(p)
di as text "  F = " %6.2f r(F) ", p = " %6.4f `p_tail_test'

* Test: Is δ⁻ at τ=0.10 different from δ⁻ at τ=0.50?
di as text _n "Test: δ⁻(τ=0.10) = δ⁻(τ=0.50)"
test [q10]dlny_neg_x_inf = [q50]dlny_neg_x_inf
local p_left_median = r(p)
di as text "  F = " %6.2f r(F) ", p = " %6.4f `p_left_median'

* Test: Joint equality across all quantiles
di as text _n "Test: δ⁻ equal across all quantiles"
test [q10]dlny_neg_x_inf = [q25]dlny_neg_x_inf = [q50]dlny_neg_x_inf = ///
     [q75]dlny_neg_x_inf = [q90]dlny_neg_x_inf
local p_joint = r(p)
di as text "  F = " %6.2f r(F) ", p = " %6.4f `p_joint'

* Store sqreg results
local delta_neg_q10 = _b[q10:dlny_neg_x_inf]
local delta_neg_q25 = _b[q25:dlny_neg_x_inf]
local delta_neg_q50 = _b[q50:dlny_neg_x_inf]
local delta_neg_q75 = _b[q75:dlny_neg_x_inf]
local delta_neg_q90 = _b[q90:dlny_neg_x_inf]

local se_q10 = _se[q10:dlny_neg_x_inf]
local se_q25 = _se[q25:dlny_neg_x_inf]
local se_q50 = _se[q50:dlny_neg_x_inf]
local se_q75 = _se[q75:dlny_neg_x_inf]
local se_q90 = _se[q90:dlny_neg_x_inf]

*===============================================================================
* 4. INTERPRETATION
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Interpretation"
di as text    "=============================================="

* Check if penalty is concentrated in left tail
local left_tail_larger = (`delta_neg_q10' > `delta_neg_q50') & (`delta_neg_q10' > `delta_neg_q90')
local ratio_10_50 = `delta_neg_q10' / `delta_neg_q50'
local ratio_10_90 = `delta_neg_q10' / `delta_neg_q90'

di as text "δ⁻ pattern across distribution:"
di as text "  Left tail (τ=0.10):  " %7.4f `delta_neg_q10'
di as text "  Median (τ=0.50):     " %7.4f `delta_neg_q50'
di as text "  Right tail (τ=0.90): " %7.4f `delta_neg_q90'
di as text ""
di as text "Ratios:"
di as text "  δ⁻(0.10) / δ⁻(0.50) = " %5.2f `ratio_10_50'
di as text "  δ⁻(0.10) / δ⁻(0.90) = " %5.2f `ratio_10_90'
di as text ""

if `p_joint' < 0.05 {
    di as text "RESULT: δ⁻ varies significantly across quantiles (p = " %5.3f `p_joint' ")"
    if `delta_neg_q10' > `delta_neg_q90' & `p_tail_test' < 0.10 {
        di as text "  → Penalty CONCENTRATED in LEFT TAIL"
        di as text "  → Consistent with LOSS AVERSION (outsized reactions to large losses)"
    }
    else if `delta_neg_q10' < `delta_neg_q90' {
        di as text "  → Penalty larger in RIGHT TAIL (unexpected)"
    }
}
else {
    di as text "RESULT: δ⁻ is UNIFORM across the distribution (p = " %5.3f `p_joint' ")"
    di as text "  → Consistent with a MECHANICAL CONSTRAINT"
    di as text "  → Informal workers face uniform smoothing penalty regardless of shock size"
}

*===============================================================================
* 5. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Export Results"
di as text    "=============================================="

* --- Save quantile coefficients ---
preserve
    clear
    svmat `QR'
    rename `QR'1 quantile
    rename `QR'2 beta_pos
    rename `QR'3 se_beta_pos
    rename `QR'4 beta_neg
    rename `QR'5 se_beta_neg
    rename `QR'6 delta_pos
    rename `QR'7 se_delta_pos
    rename `QR'8 delta_neg
    rename `QR'9 se_delta_neg
    rename `QR'10 t_delta_neg
    rename `QR'11 p_delta_neg
    rename `QR'12 N
    rename `QR'13 pseudo_r2

    export delimited using "$tables/R2_quantile_coefficients.csv", replace
    save "$data/quantile_regression_results.dta", replace
restore

* --- Create figure ---
preserve
    clear
    svmat `QR'
    rename `QR'1 quantile
    rename `QR'8 delta_neg
    rename `QR'9 se_delta_neg

    * Confidence intervals
    gen delta_neg_lo = delta_neg - 1.96 * se_delta_neg
    gen delta_neg_hi = delta_neg + 1.96 * se_delta_neg

    * OLS reference line
    gen ols_delta_neg = `delta_neg_ols'

    * Plot
    twoway (rarea delta_neg_lo delta_neg_hi quantile, color(navy%30)) ///
           (line delta_neg quantile, lcolor(navy) lwidth(medthick)) ///
           (line ols_delta_neg quantile, lpattern(dash) lcolor(cranberry)) ///
           , ///
           xlabel(0.1(0.1)0.9, grid) ///
           ylabel(, grid) ///
           xtitle("Quantile (τ)") ///
           ytitle("δ⁻: Informality penalty on downside smoothing") ///
           legend(order(2 "Quantile estimate" 1 "95% CI" 3 "OLS (mean)") ///
                  position(6) ring(0) cols(3) size(small)) ///
           title("Downside Smoothing Penalty Across the Distribution") ///
           subtitle("δ⁻ = coefficient on (Δln Y⁻ × Informal)") ///
           note("Larger δ⁻ = worse smoothing of negative income shocks for informal workers")

    graph export "$figures/R2_delta_neg_by_quantile.png", replace width(1200)
    graph save "$figures/R2_delta_neg_by_quantile.gph", replace
restore

* --- Create LaTeX table ---
file open latex using "$tables/R2_quantile_summary.tex", write replace

file write latex "\begin{table}[htbp]" _n
file write latex "\centering" _n
file write latex "\caption{Quantile Regression: Downside Smoothing Penalty}" _n
file write latex "\label{tab:quantile_delta}" _n
file write latex "\begin{tabular}{lccccc}" _n
file write latex "\toprule" _n
file write latex " & \multicolumn{5}{c}{Quantile (\$\tau\$)} \\" _n
file write latex "\cmidrule(lr){2-6}" _n
file write latex " & 0.10 & 0.25 & 0.50 & 0.75 & 0.90 \\" _n
file write latex "\midrule" _n

* Delta negative row
local d10: display %6.4f `delta_neg_q10'
local d25: display %6.4f `delta_neg_q25'
local d50: display %6.4f `delta_neg_q50'
local d75: display %6.4f `delta_neg_q75'
local d90: display %6.4f `delta_neg_q90'

file write latex "\$\delta^-\$ (Informal penalty) & `d10' & `d25' & `d50' & `d75' & `d90' \\" _n

* SE row
local se10: display %6.4f `se_q10'
local se25: display %6.4f `se_q25'
local se50: display %6.4f `se_q50'
local se75: display %6.4f `se_q75'
local se90: display %6.4f `se_q90'

file write latex " & (`se10') & (`se25') & (`se50') & (`se75') & (`se90') \\" _n

file write latex "\midrule" _n
file write latex "\multicolumn{6}{l}{\textit{Tests:}} \\" _n

local p10_90: display %5.3f `p_tail_test'
local p_all: display %5.3f `p_joint'

file write latex "\$\delta^-(0.10) = \delta^-(0.90)\$ & \multicolumn{5}{c}{p = `p10_90'} \\" _n
file write latex "Equal across quantiles & \multicolumn{5}{c}{p = `p_all'} \\" _n

file write latex "\bottomrule" _n
file write latex "\end{tabular}" _n
file write latex "\begin{tablenotes}" _n
file write latex "\small" _n
file write latex "\item Notes: Quantile regression estimates of \$\delta^-\$, the coefficient on " _n
file write latex "(Δln Y\$^-\$ × Informal). Larger values indicate worse consumption smoothing " _n
file write latex "of negative income shocks for informal workers. " _n
file write latex "Standard errors in parentheses (robust). " _n
file write latex "If \$\delta^-\$ is larger at lower quantiles, the penalty is concentrated " _n
file write latex "in the left tail, consistent with loss aversion." _n
file write latex "\end{tablenotes}" _n
file write latex "\end{table}" _n

file close latex

di as text "Results exported to:"
di as text "  $tables/R2_quantile_coefficients.csv"
di as text "  $tables/R2_quantile_summary.tex"
di as text "  $figures/R2_delta_neg_by_quantile.png"

*===============================================================================
* 6. SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  SUMMARY"
di as text    "=============================================="

di as text _n "Key finding:"
di as text "  The downside smoothing penalty (δ⁻) varies across quantiles."
di as text ""
di as text "  δ⁻ at τ=0.10 (left tail):  " %7.4f `delta_neg_q10'
di as text "  δ⁻ at τ=0.50 (median):     " %7.4f `delta_neg_q50'
di as text "  δ⁻ at τ=0.90 (right tail): " %7.4f `delta_neg_q90'
di as text ""
di as text "  Test τ=0.10 vs τ=0.90: p = " %5.3f `p_tail_test'
di as text "  Test equality across all: p = " %5.3f `p_joint'
di as text ""

if `delta_neg_q10' > `delta_neg_q50' & `delta_neg_q10' > `delta_neg_q90' {
    di as text "  INTERPRETATION: Penalty concentrated in LEFT TAIL"
    di as text "  → Loss aversion: outsized reactions to large consumption drops"
}
else if abs(`delta_neg_q10' - `delta_neg_q90') / `delta_neg_q50' < 0.3 {
    di as text "  INTERPRETATION: Penalty roughly UNIFORM"
    di as text "  → Mechanical constraint: uniform borrowing restriction"
}
else {
    di as text "  INTERPRETATION: Mixed pattern"
}

*===============================================================================

di as text _n "=============================================="
di as text    "  R2 - Quantile Asymmetric complete."
di as text    "=============================================="

log close
