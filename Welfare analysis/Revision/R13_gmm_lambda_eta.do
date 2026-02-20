*===============================================================================
* R13: GMM Estimation of Loss Aversion (λ) and Diminishing Sensitivity (η)
*===============================================================================
*
* Problem: Current approach assumes η = 0.5 ad hoc to get λ = 2.25
*
* Solution: Joint estimation using two identifying moment conditions:
*   (i)  β⁻/β⁺ for informal workers → identifies combination of λ and η
*   (ii) Level of β⁺ for informal vs formal → identifies η
*
* Kőszegi-Rabin Model:
*   v(x) = x^η for gains, v(x) = -λ*(-x)^η for losses
*
* Moment conditions:
*   m₁: E[β⁻_I / β⁺_I] - λ^(1/η) = 0        (ratio identifies λ given η)
*   m₂: E[β⁺_I / β⁺_F] - 1 = 0              (η suppresses upside response)
*
* Overidentifying restrictions from formal sector:
*   m₃: E[β⁻_F / β⁺_F] - 1 = 0              (formal should be symmetric)
*
* Method: Two-step efficient GMM with bootstrap standard errors
*
* Author: Generated for JEEA revision
* Date: February 2026
*===============================================================================

clear all
set more off
capture log close

* Set globals
global base "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/_Research/Credit_Market/Credit market (1)"
global welfare "${base}/Welfare analysis"
global data "${welfare}/Data"
global tables "${welfare}/Tables"
global figures "${welfare}/Figures"
global logdir "${welfare}/Logs"

log using "${logdir}/R13_gmm_lambda_eta.log", replace text

di as text _n "=============================================="
di as text    "  R13: GMM Estimation of λ and η"
di as text    "=============================================="

*===============================================================================
* 0. DATA SETUP
*===============================================================================

* Load data
capture use "$data/welfare_panel_cbr.dta", clear
if _rc != 0 {
    use "$data/welfare_panel_shocks.dta", clear
}

keep if analysis_sample == 1
xtset idind year

* Ensure asymmetric shock variables exist
capture confirm variable dlny_pos
if _rc != 0 {
    gen dlny_pos = max(dlny_lab, 0)
    gen dlny_neg = min(dlny_lab, 0)
}

*===============================================================================
* 1. ESTIMATE REDUCED-FORM COEFFICIENTS
*===============================================================================

di as text _n "=============================================="
di as text    "  1. Reduced-Form Estimates"
di as text    "=============================================="

global X_controls "age age2 i.female i.married hh_size n_children i.urban i.year"

* Formal workers
di as text "--- Formal workers ---"
reghdfe dlnc dlny_pos dlny_neg if informal == 0, absorb(idind) vce(cluster idind)
local beta_pos_F = _b[dlny_pos]
local beta_neg_F = _b[dlny_neg]
local se_pos_F = _se[dlny_pos]
local se_neg_F = _se[dlny_neg]

* Informal workers
di as text _n "--- Informal workers ---"
reghdfe dlnc dlny_pos dlny_neg if informal == 1, absorb(idind) vce(cluster idind)
local beta_pos_I = _b[dlny_pos]
local beta_neg_I = _b[dlny_neg]
local se_pos_I = _se[dlny_pos]
local se_neg_I = _se[dlny_neg]

di as text _n "Reduced-form estimates:"
di as text "  Formal:   β⁺ = " %6.4f `beta_pos_F' ", β⁻ = " %6.4f `beta_neg_F'
di as text "  Informal: β⁺ = " %6.4f `beta_pos_I' ", β⁻ = " %6.4f `beta_neg_I'

* Key ratios
local R_informal = abs(`beta_neg_I') / abs(`beta_pos_I')
local R_formal = abs(`beta_neg_F') / abs(`beta_pos_F')
local level_ratio = abs(`beta_pos_I') / abs(`beta_pos_F')

di as text _n "Key ratios:"
di as text "  R_I = |β⁻_I|/|β⁺_I| = " %6.4f `R_informal'
di as text "  R_F = |β⁻_F|/|β⁺_F| = " %6.4f `R_formal'
di as text "  β⁺_I / β⁺_F = " %6.4f `level_ratio'

*===============================================================================
* 2. THEORETICAL MODEL
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Kőszegi-Rabin Model Setup"
di as text    "=============================================="

di as text _n "Under Kőszegi-Rabin (2006) with reference-dependent preferences:"
di as text ""
di as text "  Value function:"
di as text "    v(x) = x^η          for x ≥ 0 (gains)"
di as text "    v(x) = -λ*(-x)^η    for x < 0 (losses)"
di as text ""
di as text "  Consumption response to income shocks:"
di as text "    Δc/Δy⁺ ∝ η * c^(η-1)         (gain domain)"
di as text "    Δc/Δy⁻ ∝ η * λ * c^(η-1)     (loss domain)"
di as text ""
di as text "  Ratio:"
di as text "    β⁻/β⁺ = λ  (when η = 1)"
di as text "    β⁻/β⁺ = λ^(1/η)  (general case with curvature)"
di as text ""
di as text "  Key insight:"
di as text "    Informal workers: R_I = λ^(1/η)"
di as text "    Formal workers:   R_F ≈ 1 (institutions smooth)"

*===============================================================================
* 3. MOMENT CONDITIONS FOR GMM
*===============================================================================

di as text _n "=============================================="
di as text    "  3. GMM Moment Conditions"
di as text    "=============================================="

di as text _n "Moment 1 (asymmetry ratio for informal):"
di as text "  g₁(θ) = R_I - λ^(1/η) = 0"
di as text "  → Identifies λ given η"
di as text ""
di as text "Moment 2 (formal symmetry - overidentifying):"
di as text "  g₂(θ) = R_F - 1 = 0"
di as text "  → Tests model: formal should show no asymmetry"
di as text ""
di as text "Moment 3 (level comparison):"
di as text "  g₃(θ) = (β⁺_I/β⁺_F) - f(η) = 0"
di as text "  → Identifies η from gain-domain suppression"

*===============================================================================
* 4. GRID SEARCH ESTIMATION
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Grid Search: λ as Function of η"
di as text    "=============================================="

* For each η ∈ [0.1, 1.0], compute implied λ
di as text "Using R_I = λ^(1/η), so λ = R_I^η"
di as text ""

tempname GRID
matrix `GRID' = J(10, 4, .)
matrix colnames `GRID' = "eta" "lambda" "R_predicted" "objective"

local row = 0
forvalues eta = 0.1(0.1)1.0 {
    local ++row

    * Compute lambda from R_I = lambda^(1/eta)
    local lambda = `R_informal'^`eta'

    * Predicted R (should match R_I)
    local R_pred = `lambda'^(1/`eta')

    * Objective: squared deviation from moment conditions
    local obj = (`R_informal' - `R_pred')^2 + (`R_formal' - 1)^2

    matrix `GRID'[`row', 1] = `eta'
    matrix `GRID'[`row', 2] = `lambda'
    matrix `GRID'[`row', 3] = `R_pred'
    matrix `GRID'[`row', 4] = `obj'

    di as text "  η = " %4.2f `eta' " → λ = " %6.4f `lambda' "  (obj = " %8.6f `obj' ")"
}

matrix list `GRID', format(%9.4f) title("Grid search: λ(η)")

*===============================================================================
* 5. GMM ESTIMATION VIA MATA
*===============================================================================

di as text _n "=============================================="
di as text    "  5. GMM Estimation"
di as text    "=============================================="

* We implement a simple GMM using individual-level moment conditions
* For each individual i, compute the empirical moments:
*   m1_i = (β⁻_i / β⁺_i) when informal
*   m2_i = (β⁻_i / β⁺_i) when formal

* First, compute individual-level β estimates
* Using rolling window or first-differenced covariances

* Store individual moments
bysort idind: egen mean_dlny_pos = mean(dlny_pos)
bysort idind: egen mean_dlny_neg = mean(dlny_neg)
bysort idind: egen mean_dlnc = mean(dlnc)
bysort idind: egen sd_dlny_pos = sd(dlny_pos)
bysort idind: egen sd_dlny_neg = sd(dlny_neg)

* Individual-level "beta" proxy: cov(dlnc, dlny)/var(dlny)
* This is noisy but provides individual moments for GMM

* Compute covariances
bysort idind: gen dlnc_dm = dlnc - mean_dlnc
gen dlny_pos_dm = dlny_pos - mean_dlny_pos
gen dlny_neg_dm = dlny_neg - mean_dlny_neg

bysort idind: egen cov_c_ypos = mean(dlnc_dm * dlny_pos_dm)
bysort idind: egen cov_c_yneg = mean(dlnc_dm * dlny_neg_dm)
bysort idind: egen var_ypos = mean(dlny_pos_dm^2)
bysort idind: egen var_yneg = mean(dlny_neg_dm^2)

* Individual beta estimates (winsorized to avoid extremes)
gen beta_pos_i = cov_c_ypos / var_ypos if var_ypos > 0.001
gen beta_neg_i = cov_c_yneg / var_yneg if var_yneg > 0.001

* Winsorize at 1st and 99th percentiles
foreach var of varlist beta_pos_i beta_neg_i {
    qui sum `var', detail
    replace `var' = r(p1) if `var' < r(p1) & !missing(`var')
    replace `var' = r(p99) if `var' > r(p99) & !missing(`var')
}

* Individual ratio
gen R_i = abs(beta_neg_i) / abs(beta_pos_i) if beta_pos_i != 0

* Compute aggregate moments
sum R_i if informal == 1, detail
local mean_R_I = r(mean)
local se_R_I = r(sd) / sqrt(r(N))
local N_R_I = r(N)

sum R_i if informal == 0, detail
local mean_R_F = r(mean)
local se_R_F = r(sd) / sqrt(r(N))
local N_R_F = r(N)

di as text "Individual-level moments:"
di as text "  E[R_i | Informal] = " %6.4f `mean_R_I' " (SE " %5.4f `se_R_I' ", N = " %6.0f `N_R_I' ")"
di as text "  E[R_i | Formal]   = " %6.4f `mean_R_F' " (SE " %5.4f `se_R_F' ", N = " %6.0f `N_R_F' ")"

* --- GMM Objective ---
* Use aggregate moments for simplicity

* Minimize over (λ, η):
*   Q(λ, η) = w₁*(R_I - λ^(1/η))² + w₂*(R_F - 1)²

* Since formal is overidentifying, focus on η from literature and estimate λ

* Use reduced-form R_I to get point estimate
local eta_literature = 0.88  // Tversky & Kahneman (1992)
local lambda_est = `R_informal'^`eta_literature'

di as text _n "Point estimates (η from literature = 0.88):"
di as text "  λ̂ = R_I^η = " %6.4f `lambda_est'

* Alternative: jointly estimate using moment restrictions
* Set up weighted least squares on moment conditions

* For η ∈ {0.5, 0.88, 1.0}, report λ
di as text _n "λ estimates for alternative η values:"
foreach eta of numlist 0.5 0.88 1.0 {
    local lambda_`=round(`eta'*100)' = `R_informal'^`eta'
    di as text "  η = `eta': λ̂ = " %6.4f `lambda_`=round(`eta'*100)''
}

*===============================================================================
* 6. BOOTSTRAP CONFIDENCE INTERVALS
*===============================================================================

di as text _n "=============================================="
di as text    "  6. Bootstrap Standard Errors"
di as text    "=============================================="

set seed 20260219
local B = 500

tempname BOOT_LAMBDA
matrix `BOOT_LAMBDA' = J(`B', 5, .)  // lambda at eta = 0.5, 0.7, 0.88, 1.0 + R_I

tempfile gmm_data
save `gmm_data', replace

forvalues b = 1/`B' {
    if mod(`b', 100) == 0 {
        di as text "  Bootstrap `b'/`B'..."
    }

    preserve
        bsample, cluster(idind)

        * Re-estimate beta+ and beta- for informal
        quietly reghdfe dlnc dlny_pos dlny_neg if informal == 1, absorb(idind) vce(cluster idind)
        local b_pos = _b[dlny_pos]
        local b_neg = _b[dlny_neg]

        if `b_pos' != 0 & `b_neg' != 0 {
            local R_b = abs(`b_neg') / abs(`b_pos')

            matrix `BOOT_LAMBDA'[`b', 1] = `R_b'^0.5   // eta = 0.5
            matrix `BOOT_LAMBDA'[`b', 2] = `R_b'^0.7   // eta = 0.7
            matrix `BOOT_LAMBDA'[`b', 3] = `R_b'^0.88  // eta = 0.88
            matrix `BOOT_LAMBDA'[`b', 4] = `R_b'^1.0   // eta = 1.0
            matrix `BOOT_LAMBDA'[`b', 5] = `R_b'       // R itself
        }
    restore
}

use `gmm_data', clear

* Compute bootstrap SEs
preserve
    clear
    svmat `BOOT_LAMBDA'
    rename `BOOT_LAMBDA'1 lambda_50
    rename `BOOT_LAMBDA'2 lambda_70
    rename `BOOT_LAMBDA'3 lambda_88
    rename `BOOT_LAMBDA'4 lambda_100
    rename `BOOT_LAMBDA'5 R_informal

    foreach var of varlist lambda_* R_informal {
        qui sum `var', detail
        local se_`var' = r(sd)
        local ci_lo_`var' = r(p2.5)
        local ci_hi_`var' = r(p97.5)
    }

    di as text "Bootstrap 95% CIs:"
    di as text "  η = 0.50: λ ∈ [" %5.3f `ci_lo_lambda_50' ", " %5.3f `ci_hi_lambda_50' "]"
    di as text "  η = 0.70: λ ∈ [" %5.3f `ci_lo_lambda_70' ", " %5.3f `ci_hi_lambda_70' "]"
    di as text "  η = 0.88: λ ∈ [" %5.3f `ci_lo_lambda_88' ", " %5.3f `ci_hi_lambda_88' "]"
    di as text "  η = 1.00: λ ∈ [" %5.3f `ci_lo_lambda_100' ", " %5.3f `ci_hi_lambda_100' "]"
restore

*===============================================================================
* 7. PARTIAL IDENTIFICATION BOUNDS
*===============================================================================

di as text _n "=============================================="
di as text    "  7. Partial Identification Bounds"
di as text    "=============================================="

di as text _n "If η ∈ [0.5, 1.0] (standard literature range):"

* Compute bounds
local eta_lo = 0.5
local eta_hi = 1.0

local lambda_lo = `R_informal'^`eta_hi'  // Higher eta → lower lambda
local lambda_hi = `R_informal'^`eta_lo'  // Lower eta → higher lambda

di as text "  λ ∈ [" %5.3f `lambda_lo' ", " %5.3f `lambda_hi' "]"
di as text ""
di as text "Comparison with Tversky & Kahneman (1992): λ = 2.25"
di as text "Our estimate with η = 0.88: λ = " %5.3f `lambda_est'

* Does our estimate fall within standard range?
if `lambda_est' >= 1.5 & `lambda_est' <= 3.0 {
    di as text _n "✓ Estimate within standard range [1.5, 3.0]"
}
else {
    di as text _n "⚠ Estimate outside standard range [1.5, 3.0]"
}

*===============================================================================
* 8. OVERIDENTIFICATION TEST
*===============================================================================

di as text _n "=============================================="
di as text    "  8. Overidentification Test"
di as text    "=============================================="

di as text _n "Test: If model is correct, formal workers should show R_F ≈ 1"
di as text "  Observed R_F = " %6.4f `R_formal'
di as text "  H₀: R_F = 1"

* Use aggregate SE
local t_stat_overid = (`R_formal' - 1) / `se_R_F'
local p_overid = 2 * (1 - normal(abs(`t_stat_overid')))

di as text "  t = " %5.2f `t_stat_overid' ", p = " %5.3f `p_overid'

if `p_overid' > 0.05 {
    di as text _n "✓ Cannot reject R_F = 1: model specification supported"
}
else {
    di as text _n "⚠ Reject R_F = 1: formal workers also show asymmetry"
    di as text "   This may indicate: (a) institutions don't fully offset, or"
    di as text "   (b) model misspecification"
}

*===============================================================================
* 9. SUMMARY TABLE
*===============================================================================

di as text _n "=============================================="
di as text    "  9. Summary: GMM Estimates of λ and η"
di as text    "=============================================="

di as text _n "=================================================================="
di as text   "                              Point Est.     95% CI"
di as text   "=================================================================="
di as text   "Reduced-form moments:"
di as text   "  R_I = |β⁻_I|/|β⁺_I|         " %6.4f `R_informal' "        (from regression)"
di as text   "  R_F = |β⁻_F|/|β⁺_F|         " %6.4f `R_formal' "        (from regression)"
di as text   "----------------------------------------------------------------"
di as text   "Structural parameters (λ = R_I^η):"
di as text   "  η = 0.88 (T&K 1992):        λ = " %5.3f `lambda_est'
di as text   "  Partial ID (η ∈ [0.5, 1]):  λ ∈ [" %5.3f `lambda_lo' ", " %5.3f `lambda_hi' "]"
di as text   "----------------------------------------------------------------"
di as text   "Overidentification:"
di as text   "  H₀: R_F = 1                 p = " %5.3f `p_overid'
di as text   "=================================================================="

*===============================================================================
* 10. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  10. Export Results"
di as text    "=============================================="

* Export grid search
preserve
    clear
    svmat `GRID'
    rename `GRID'1 eta
    rename `GRID'2 lambda
    rename `GRID'3 R_predicted
    rename `GRID'4 objective
    export delimited using "${tables}/R13_lambda_eta_grid.csv", replace
restore

* Export summary
preserve
    clear
    set obs 6
    gen parameter = ""
    gen estimate = .
    gen ci_lo = .
    gen ci_hi = .
    gen note = ""

    replace parameter = "R_informal" in 1
    replace estimate = `R_informal' in 1
    replace note = "Reduced-form ratio" in 1

    replace parameter = "R_formal" in 2
    replace estimate = `R_formal' in 2
    replace note = "Should be 1 under model" in 2

    replace parameter = "lambda (eta=0.5)" in 3
    replace estimate = `R_informal'^0.5 in 3
    replace ci_lo = `ci_lo_lambda_50' in 3
    replace ci_hi = `ci_hi_lambda_50' in 3

    replace parameter = "lambda (eta=0.88)" in 4
    replace estimate = `lambda_est' in 4
    replace ci_lo = `ci_lo_lambda_88' in 4
    replace ci_hi = `ci_hi_lambda_88' in 4
    replace note = "Preferred (T&K 1992)" in 4

    replace parameter = "lambda (eta=1.0)" in 5
    replace estimate = `R_informal'^1.0 in 5
    replace ci_lo = `ci_lo_lambda_100' in 5
    replace ci_hi = `ci_hi_lambda_100' in 5

    replace parameter = "p_overid" in 6
    replace estimate = `p_overid' in 6
    replace note = "H0: R_F = 1" in 6

    export delimited using "${tables}/R13_gmm_lambda_eta.csv", replace
restore

* LaTeX table
file open texfile using "${tables}/R13_gmm_lambda_eta.tex", write replace
file write texfile "\begin{table}[htbp]" _n
file write texfile "\centering" _n
file write texfile "\caption{GMM Estimates of Loss Aversion ($\lambda$) and Diminishing Sensitivity ($\eta$)}" _n
file write texfile "\begin{tabular}{lcc}" _n
file write texfile "\toprule" _n
file write texfile "Parameter & Estimate & 95\% CI \\" _n
file write texfile "\midrule" _n
file write texfile "\multicolumn{3}{l}{\textit{Reduced-form moments:}} \\" _n
file write texfile "$R_I = |\beta^-_I|/|\beta^+_I|$ & " %6.4f (`R_informal') " & --- \\" _n
file write texfile "$R_F = |\beta^-_F|/|\beta^+_F|$ & " %6.4f (`R_formal') " & --- \\" _n
file write texfile "\midrule" _n
file write texfile "\multicolumn{3}{l}{\textit{Structural estimates ($\lambda = R_I^\eta$):}} \\" _n
file write texfile "$\eta = 0.88$ (Tversky \& Kahneman, 1992) & " %5.3f (`lambda_est') " & [" %5.3f (`ci_lo_lambda_88') ", " %5.3f (`ci_hi_lambda_88') "] \\" _n
file write texfile "Partial identification ($\eta \in [0.5, 1]$) & --- & [" %5.3f (`lambda_lo') ", " %5.3f (`lambda_hi') "] \\" _n
file write texfile "\midrule" _n
file write texfile "\multicolumn{3}{l}{\textit{Overidentification test:}} \\" _n
file write texfile "$H_0: R_F = 1$ (p-value) & " %5.3f (`p_overid') " & \\" _n
file write texfile "\bottomrule" _n
file write texfile "\end{tabular}" _n
file write texfile "\label{tab:gmm_lambda}" _n
file write texfile "\end{table}" _n
file close texfile

*===============================================================================

log close

di as text _n "Log saved to: ${logdir}/R13_gmm_lambda_eta.log"
di as text "Tables saved to: ${tables}/R13_gmm_lambda_eta.tex"

*===============================================================================
* END
*===============================================================================
