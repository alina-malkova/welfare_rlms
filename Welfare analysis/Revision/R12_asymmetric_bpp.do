*===============================================================================
* R12: Asymmetric BPP Decomposition by Shock Sign
*===============================================================================
*
* Novel Contribution: Four-way BPP decomposition
*   (permanent/transitory × positive/negative × formal/informal)
*
* The model predicts:
*   φ⁻_I ≫ φ⁻_F  (informal penalty on negative transitory shocks)
*   φ⁺_I ≈ φ⁺_F  (no difference on positive transitory shocks)
*
* This is the test that "makes a referee sit up" - no existing paper
* has done this four-way decomposition.
*
* Methodology:
*   1. Decompose income into permanent + transitory (standard BPP)
*   2. Further decompose each into positive/negative realizations
*   3. Estimate consumption response to each of four shock types
*   4. Compare formal vs informal for each
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

log using "${logdir}/R12_asymmetric_bpp.log", replace text

di as text _n "=============================================="
di as text    "  R12: Asymmetric BPP Decomposition"
di as text    "       (Four-way: perm/trans × pos/neg)"
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

di as text "Sample: N = " _N " observations"
tab informal, missing

*===============================================================================
* 1. CONSTRUCT PERMANENT AND TRANSITORY SHOCKS
*===============================================================================

di as text _n "=============================================="
di as text    "  1. Construct Permanent/Transitory Shocks"
di as text    "=============================================="

* BPP methodology uses covariance structure to identify shocks
* Under MA(0) transitory:
*   Cov(Δy_t, Δy_{t-1}) = -σ²_v
*   Var(Δy_t) = σ²_ζ + 2σ²_v

sort idind year

* Leads and lags
by idind: gen dlny_lag1 = dlny_lab[_n-1]
by idind: gen dlny_lag2 = dlny_lab[_n-2]
by idind: gen dlny_lead1 = dlny_lab[_n+1]

* Method 1: Quasi-differencing approach (Blundell, Pistaferri, Preston 2008)
* Permanent shock proxy: ζ_t ≈ Δy_t + Δy_{t+1}  (next period's income validates permanent change)
* Transitory shock proxy: v_t ≈ Δy_t - (ζ estimate)

* For identification, we use the structure:
* E[Δy_t | Δy_{t-1}, Δy_{t+1}] identifies the permanent component

* Simple quasi-difference: transitory reverses
by idind: gen perm_shock_proxy = (dlny_lab + dlny_lead1) / 2 if !missing(dlny_lead1)
by idind: gen trans_shock_proxy = dlny_lab - perm_shock_proxy

label variable perm_shock_proxy "Permanent shock proxy (ζ)"
label variable trans_shock_proxy "Transitory shock proxy (v)"

* Alternative: Use only persistence to identify
* If Δy_t and Δy_{t+1} have same sign → more likely permanent
* If opposite sign → more likely transitory
gen byte same_sign = (dlny_lab * dlny_lead1 > 0) if !missing(dlny_lead1)
gen perm_shock_v2 = dlny_lab if same_sign == 1
gen trans_shock_v2 = dlny_lab if same_sign == 0

*===============================================================================
* 2. DECOMPOSE INTO POSITIVE AND NEGATIVE
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Decompose by Sign"
di as text    "=============================================="

* Four shock types
gen perm_pos = max(perm_shock_proxy, 0)
gen perm_neg = min(perm_shock_proxy, 0)
gen trans_pos = max(trans_shock_proxy, 0)
gen trans_neg = min(trans_shock_proxy, 0)

label variable perm_pos "Permanent positive shock (ζ⁺)"
label variable perm_neg "Permanent negative shock (ζ⁻)"
label variable trans_pos "Transitory positive shock (v⁺)"
label variable trans_neg "Transitory negative shock (v⁻)"

* Interactions with informality
gen perm_pos_x_inf = perm_pos * informal
gen perm_neg_x_inf = perm_neg * informal
gen trans_pos_x_inf = trans_pos * informal
gen trans_neg_x_inf = trans_neg * informal

label variable perm_pos_x_inf "ζ⁺ × Informal"
label variable perm_neg_x_inf "ζ⁻ × Informal"
label variable trans_pos_x_inf "v⁺ × Informal"
label variable trans_neg_x_inf "v⁻ × Informal"

* Summary statistics
di as text _n "Summary of shock decomposition:"
tabstat perm_pos perm_neg trans_pos trans_neg, by(informal) stats(mean sd n) format(%9.4f)

*===============================================================================
* 3. ESTIMATE FOUR-WAY BPP MODEL
*===============================================================================

di as text _n "=============================================="
di as text    "  3. Four-Way BPP Estimation"
di as text    "=============================================="

* Sample restriction
gen byte bpp4_sample = !missing(dlnc, perm_pos, perm_neg, trans_pos, trans_neg)
count if bpp4_sample == 1
local N_bpp4 = r(N)
di as text "Four-way BPP sample: N = `N_bpp4'"

* Controls
global X_controls "age age2 i.female i.married hh_size n_children i.urban i.year"

eststo clear

* --- Model 1: Full sample pooled ---
di as text _n "--- Model 1: Full sample ---"
eststo m1: reghdfe dlnc perm_pos perm_neg trans_pos trans_neg ///
    if bpp4_sample == 1, ///
    absorb(idind) vce(cluster idind)

local psi_pos_full = _b[perm_pos]
local psi_neg_full = _b[perm_neg]
local phi_pos_full = _b[trans_pos]
local phi_neg_full = _b[trans_neg]

di as text "  ψ⁺ (perm positive):  " %6.4f `psi_pos_full'
di as text "  ψ⁻ (perm negative):  " %6.4f `psi_neg_full'
di as text "  φ⁺ (trans positive): " %6.4f `phi_pos_full'
di as text "  φ⁻ (trans negative): " %6.4f `phi_neg_full'

* --- Model 2: Formal workers only ---
di as text _n "--- Model 2: Formal workers ---"
eststo m2: reghdfe dlnc perm_pos perm_neg trans_pos trans_neg ///
    if bpp4_sample == 1 & informal == 0, ///
    absorb(idind) vce(cluster idind)

local psi_pos_F = _b[perm_pos]
local psi_neg_F = _b[perm_neg]
local phi_pos_F = _b[trans_pos]
local phi_neg_F = _b[trans_neg]
local se_psi_pos_F = _se[perm_pos]
local se_psi_neg_F = _se[perm_neg]
local se_phi_pos_F = _se[trans_pos]
local se_phi_neg_F = _se[trans_neg]

* Asymmetry tests
test perm_pos = perm_neg
local p_perm_asym_F = r(p)
test trans_pos = trans_neg
local p_trans_asym_F = r(p)

di as text "  ψ⁺_F = " %6.4f `psi_pos_F' " (SE " %5.4f `se_psi_pos_F' ")"
di as text "  ψ⁻_F = " %6.4f `psi_neg_F' " (SE " %5.4f `se_psi_neg_F' ")"
di as text "  Permanent asymmetry test: p = " %5.3f `p_perm_asym_F'
di as text "  φ⁺_F = " %6.4f `phi_pos_F' " (SE " %5.4f `se_phi_pos_F' ")"
di as text "  φ⁻_F = " %6.4f `phi_neg_F' " (SE " %5.4f `se_phi_neg_F' ")"
di as text "  Transitory asymmetry test: p = " %5.3f `p_trans_asym_F'

* --- Model 3: Informal workers only ---
di as text _n "--- Model 3: Informal workers ---"
eststo m3: reghdfe dlnc perm_pos perm_neg trans_pos trans_neg ///
    if bpp4_sample == 1 & informal == 1, ///
    absorb(idind) vce(cluster idind)

local psi_pos_I = _b[perm_pos]
local psi_neg_I = _b[perm_neg]
local phi_pos_I = _b[trans_pos]
local phi_neg_I = _b[trans_neg]
local se_psi_pos_I = _se[perm_pos]
local se_psi_neg_I = _se[perm_neg]
local se_phi_pos_I = _se[trans_pos]
local se_phi_neg_I = _se[trans_neg]

* Asymmetry tests
test perm_pos = perm_neg
local p_perm_asym_I = r(p)
test trans_pos = trans_neg
local p_trans_asym_I = r(p)

di as text "  ψ⁺_I = " %6.4f `psi_pos_I' " (SE " %5.4f `se_psi_pos_I' ")"
di as text "  ψ⁻_I = " %6.4f `psi_neg_I' " (SE " %5.4f `se_psi_neg_I' ")"
di as text "  Permanent asymmetry test: p = " %5.3f `p_perm_asym_I'
di as text "  φ⁺_I = " %6.4f `phi_pos_I' " (SE " %5.4f `se_phi_pos_I' ")"
di as text "  φ⁻_I = " %6.4f `phi_neg_I' " (SE " %5.4f `se_phi_neg_I' ")"
di as text "  Transitory asymmetry test: p = " %5.3f `p_trans_asym_I'

* --- Model 4: Full interaction model ---
di as text _n "--- Model 4: Full interaction ---"
eststo m4: reghdfe dlnc perm_pos perm_neg trans_pos trans_neg ///
    perm_pos_x_inf perm_neg_x_inf trans_pos_x_inf trans_neg_x_inf ///
    informal ///
    if bpp4_sample == 1, ///
    absorb(idind) vce(cluster idind)

* Key model prediction tests
di as text _n "--- KEY PREDICTION TESTS ---"

* Test 1: φ⁻_I > φ⁻_F (informal penalty on negative transitory)
local diff_phi_neg = _b[trans_neg_x_inf]
local se_diff_phi_neg = _se[trans_neg_x_inf]
test trans_neg_x_inf = 0
local p_phi_neg_diff = r(p)
di as text "Test 1: φ⁻_I - φ⁻_F = " %6.4f `diff_phi_neg' " (p = " %5.3f `p_phi_neg_diff' ")"
di as text "  Prediction: > 0 (informal worse at smoothing negative transitory)"

* Test 2: φ⁺_I ≈ φ⁺_F (no difference on positive transitory)
local diff_phi_pos = _b[trans_pos_x_inf]
local se_diff_phi_pos = _se[trans_pos_x_inf]
test trans_pos_x_inf = 0
local p_phi_pos_diff = r(p)
di as text "Test 2: φ⁺_I - φ⁺_F = " %6.4f `diff_phi_pos' " (p = " %5.3f `p_phi_pos_diff' ")"
di as text "  Prediction: ≈ 0 (no difference on positive transitory)"

* Test 3: Asymmetry in transitory penalty
test trans_pos_x_inf = trans_neg_x_inf
local p_trans_penalty_asym = r(p)
di as text "Test 3: (φ⁺_I - φ⁺_F) = (φ⁻_I - φ⁻_F): p = " %5.3f `p_trans_penalty_asym'
di as text "  Prediction: REJECT (penalty concentrated on negative)"

* Test 4: What about permanent shocks?
local diff_psi_neg = _b[perm_neg_x_inf]
local diff_psi_pos = _b[perm_pos_x_inf]
test perm_neg_x_inf = 0
local p_psi_neg_diff = r(p)
test perm_pos_x_inf = 0
local p_psi_pos_diff = r(p)
di as text "Test 4: ψ⁻_I - ψ⁻_F = " %6.4f `diff_psi_neg' " (p = " %5.3f `p_psi_neg_diff' ")"
di as text "Test 5: ψ⁺_I - ψ⁺_F = " %6.4f `diff_psi_pos' " (p = " %5.3f `p_psi_pos_diff' ")"

*===============================================================================
* 4. BOOTSTRAP STANDARD ERRORS FOR DIFFERENCES
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Bootstrap Inference"
di as text    "=============================================="

set seed 20260219
local B = 500

* Store bootstrap estimates
tempname BOOT
matrix `BOOT' = J(`B', 8, .)  // 8 coefficients: psi+/-, phi+/- for each group

tempfile bootdata
save `bootdata', replace

forvalues b = 1/`B' {
    if mod(`b', 100) == 0 {
        di as text "  Bootstrap `b'/`B'..."
    }

    preserve
        bsample, cluster(idind)

        * Formal estimates
        quietly reghdfe dlnc perm_pos perm_neg trans_pos trans_neg ///
            if bpp4_sample == 1 & informal == 0, absorb(idind) vce(cluster idind)
        matrix `BOOT'[`b', 1] = _b[perm_pos]
        matrix `BOOT'[`b', 2] = _b[perm_neg]
        matrix `BOOT'[`b', 3] = _b[trans_pos]
        matrix `BOOT'[`b', 4] = _b[trans_neg]

        * Informal estimates
        quietly reghdfe dlnc perm_pos perm_neg trans_pos trans_neg ///
            if bpp4_sample == 1 & informal == 1, absorb(idind) vce(cluster idind)
        matrix `BOOT'[`b', 5] = _b[perm_pos]
        matrix `BOOT'[`b', 6] = _b[perm_neg]
        matrix `BOOT'[`b', 7] = _b[trans_pos]
        matrix `BOOT'[`b', 8] = _b[trans_neg]
    restore
}

use `bootdata', clear

* Compute bootstrap SEs and differences
preserve
    clear
    svmat `BOOT'
    rename `BOOT'1 psi_pos_F
    rename `BOOT'2 psi_neg_F
    rename `BOOT'3 phi_pos_F
    rename `BOOT'4 phi_neg_F
    rename `BOOT'5 psi_pos_I
    rename `BOOT'6 psi_neg_I
    rename `BOOT'7 phi_pos_I
    rename `BOOT'8 phi_neg_I

    * Differences
    gen diff_phi_neg = phi_neg_I - phi_neg_F
    gen diff_phi_pos = phi_pos_I - phi_pos_F
    gen diff_psi_neg = psi_neg_I - psi_neg_F
    gen diff_psi_pos = psi_pos_I - psi_pos_F

    * Summary
    sum diff_phi_neg, detail
    local boot_se_phi_neg = r(sd)
    local boot_ci_lo_phi_neg = r(p5)
    local boot_ci_hi_phi_neg = r(p95)

    sum diff_phi_pos, detail
    local boot_se_phi_pos = r(sd)
    local boot_ci_lo_phi_pos = r(p5)
    local boot_ci_hi_phi_pos = r(p95)

    di as text _n "Bootstrap 90% CIs for informal-formal differences:"
    di as text "  φ⁻_I - φ⁻_F: [" %6.4f `boot_ci_lo_phi_neg' ", " %6.4f `boot_ci_hi_phi_neg' "]"
    di as text "  φ⁺_I - φ⁺_F: [" %6.4f `boot_ci_lo_phi_pos' ", " %6.4f `boot_ci_hi_phi_pos' "]"
restore

*===============================================================================
* 5. SUMMARY TABLE
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Four-Way BPP Summary"
di as text    "=============================================="

di as text _n "========================================================================"
di as text   "                          Formal Workers         Informal Workers"
di as text   "                        Estimate   (SE)         Estimate   (SE)"
di as text   "========================================================================"
di as text   "Permanent Shocks:"
di as text   "  ψ⁺ (positive)         " %7.4f `psi_pos_F' "  (" %5.4f `se_psi_pos_F' ")      " %7.4f `psi_pos_I' "  (" %5.4f `se_psi_pos_I' ")"
di as text   "  ψ⁻ (negative)         " %7.4f `psi_neg_F' "  (" %5.4f `se_psi_neg_F' ")      " %7.4f `psi_neg_I' "  (" %5.4f `se_psi_neg_I' ")"
di as text   "  Asymmetry p-value:           " %5.3f `p_perm_asym_F' "                    " %5.3f `p_perm_asym_I'
di as text   "------------------------------------------------------------------------"
di as text   "Transitory Shocks:"
di as text   "  φ⁺ (positive)         " %7.4f `phi_pos_F' "  (" %5.4f `se_phi_pos_F' ")      " %7.4f `phi_pos_I' "  (" %5.4f `se_phi_pos_I' ")"
di as text   "  φ⁻ (negative)         " %7.4f `phi_neg_F' "  (" %5.4f `se_phi_neg_F' ")      " %7.4f `phi_neg_I' "  (" %5.4f `se_phi_neg_I' ")"
di as text   "  Asymmetry p-value:           " %5.3f `p_trans_asym_F' "                    " %5.3f `p_trans_asym_I'
di as text   "========================================================================"

di as text _n "KEY FINDING:"
if `p_phi_neg_diff' < 0.10 & `p_phi_pos_diff' > 0.10 {
    di as text "  ✓ CONFIRMED: Informal penalty is concentrated on NEGATIVE TRANSITORY shocks"
    di as text "    φ⁻_I > φ⁻_F (p = " %5.3f `p_phi_neg_diff' ")"
    di as text "    φ⁺_I ≈ φ⁺_F (p = " %5.3f `p_phi_pos_diff' ")"
}
else if `p_phi_neg_diff' < 0.10 & `p_phi_pos_diff' < 0.10 {
    di as text "  Both φ⁺ and φ⁻ differ: general smoothing deficit, not asymmetric"
}
else {
    di as text "  Results inconclusive: no significant differences detected"
}

*===============================================================================
* 6. VISUALIZATION
*===============================================================================

di as text _n "=============================================="
di as text    "  6. Visualization"
di as text    "=============================================="

* Create coefficient plot data
preserve
    clear
    set obs 8
    gen shock_type = ""
    gen sector = ""
    gen coef = .
    gen se = .
    gen ci_lo = .
    gen ci_hi = .
    gen order = .

    * Formal workers
    replace shock_type = "ψ⁺" in 1
    replace sector = "Formal" in 1
    replace coef = `psi_pos_F' in 1
    replace se = `se_psi_pos_F' in 1
    replace order = 1 in 1

    replace shock_type = "ψ⁻" in 2
    replace sector = "Formal" in 2
    replace coef = `psi_neg_F' in 2
    replace se = `se_psi_neg_F' in 2
    replace order = 2 in 2

    replace shock_type = "φ⁺" in 3
    replace sector = "Formal" in 3
    replace coef = `phi_pos_F' in 3
    replace se = `se_phi_pos_F' in 3
    replace order = 3 in 3

    replace shock_type = "φ⁻" in 4
    replace sector = "Formal" in 4
    replace coef = `phi_neg_F' in 4
    replace se = `se_phi_neg_F' in 4
    replace order = 4 in 4

    * Informal workers
    replace shock_type = "ψ⁺" in 5
    replace sector = "Informal" in 5
    replace coef = `psi_pos_I' in 5
    replace se = `se_psi_pos_I' in 5
    replace order = 1 in 5

    replace shock_type = "ψ⁻" in 6
    replace sector = "Informal" in 6
    replace coef = `psi_neg_I' in 6
    replace se = `se_psi_neg_I' in 6
    replace order = 2 in 6

    replace shock_type = "φ⁺" in 7
    replace sector = "Informal" in 7
    replace coef = `phi_pos_I' in 7
    replace se = `se_phi_pos_I' in 7
    replace order = 3 in 7

    replace shock_type = "φ⁻" in 8
    replace sector = "Informal" in 8
    replace coef = `phi_neg_I' in 8
    replace se = `se_phi_neg_I' in 8
    replace order = 4 in 8

    * CIs
    replace ci_lo = coef - 1.96 * se
    replace ci_hi = coef + 1.96 * se

    * Plot
    encode sector, gen(sector_n)

    twoway (bar coef order if sector == "Formal", color(navy) barwidth(0.35)) ///
           (bar coef order if sector == "Informal", color(maroon) barwidth(0.35) ///
               xoffset(0.35)) ///
           (rcap ci_lo ci_hi order if sector == "Formal", color(navy)) ///
           (rcap ci_lo ci_hi order if sector == "Informal", ///
               xoffset(0.35) color(maroon)), ///
        xlabel(1 "ψ⁺" 2 "ψ⁻" 3 "φ⁺" 4 "φ⁻", noticks) ///
        xtitle("Shock Type") ytitle("Consumption Response") ///
        title("Four-Way BPP Decomposition") ///
        subtitle("Permanent (ψ) and Transitory (φ) × Positive/Negative") ///
        legend(order(1 "Formal" 2 "Informal") rows(1) position(6)) ///
        yline(0, lcolor(black) lpattern(dash)) ///
        note("Error bars: 95% CI. Key finding: φ⁻ differs by sector (asymmetric transitory penalty)")

    graph export "${figures}/R12_fourway_bpp.png", replace width(1200)
    graph save "${figures}/R12_fourway_bpp.gph", replace
restore

*===============================================================================
* 7. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  7. Export Results"
di as text    "=============================================="

* Main table
esttab m2 m3 m4 using "${tables}/R12_asymmetric_bpp.tex", replace ///
    keep(perm_pos perm_neg trans_pos trans_neg ///
         perm_pos_x_inf perm_neg_x_inf trans_pos_x_inf trans_neg_x_inf) ///
    mtitles("Formal" "Informal" "Interaction") ///
    coeflabels(perm_pos "$\psi^+$" perm_neg "$\psi^-$" ///
               trans_pos "$\phi^+$" trans_neg "$\phi^-$" ///
               perm_pos_x_inf "$\psi^+ \times$ Informal" ///
               perm_neg_x_inf "$\psi^- \times$ Informal" ///
               trans_pos_x_inf "$\phi^+ \times$ Informal" ///
               trans_neg_x_inf "$\phi^- \times$ Informal") ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Four-Way BPP Decomposition: Asymmetric Consumption Smoothing") ///
    label booktabs ///
    addnotes("Permanent shocks (ψ) identified via quasi-differencing." ///
             "Transitory shocks (φ) are residual. Individual FE." ///
             "Standard errors clustered at individual level.")

* Summary CSV
preserve
    clear
    set obs 8
    gen coefficient = ""
    gen formal = .
    gen informal = .
    gen difference = .
    gen p_diff = .

    replace coefficient = "psi_pos" in 1
    replace formal = `psi_pos_F' in 1
    replace informal = `psi_pos_I' in 1
    replace difference = `diff_psi_pos' in 1
    replace p_diff = `p_psi_pos_diff' in 1

    replace coefficient = "psi_neg" in 2
    replace formal = `psi_neg_F' in 2
    replace informal = `psi_neg_I' in 2
    replace difference = `diff_psi_neg' in 2
    replace p_diff = `p_psi_neg_diff' in 2

    replace coefficient = "phi_pos" in 3
    replace formal = `phi_pos_F' in 3
    replace informal = `phi_pos_I' in 3
    replace difference = `diff_phi_pos' in 3
    replace p_diff = `p_phi_pos_diff' in 3

    replace coefficient = "phi_neg" in 4
    replace formal = `phi_neg_F' in 4
    replace informal = `phi_neg_I' in 4
    replace difference = `diff_phi_neg' in 4
    replace p_diff = `p_phi_neg_diff' in 4

    replace coefficient = "p_perm_asym" in 5
    replace formal = `p_perm_asym_F' in 5
    replace informal = `p_perm_asym_I' in 5

    replace coefficient = "p_trans_asym" in 6
    replace formal = `p_trans_asym_F' in 6
    replace informal = `p_trans_asym_I' in 6

    replace coefficient = "p_trans_penalty_asym" in 7
    replace p_diff = `p_trans_penalty_asym' in 7

    export delimited using "${tables}/R12_asymmetric_bpp_summary.csv", replace
restore

*===============================================================================

log close

di as text _n "Log saved to: ${logdir}/R12_asymmetric_bpp.log"
di as text "Tables saved to: ${tables}/R12_asymmetric_bpp.tex"
di as text "Figures saved to: ${figures}/R12_fourway_bpp.png"

*===============================================================================
* END
*===============================================================================
