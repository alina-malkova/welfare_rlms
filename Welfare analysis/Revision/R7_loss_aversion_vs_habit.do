*===============================================================================
* R7: Loss Aversion vs Habit Formation Test
*===============================================================================
*
* Problem: Asymmetric consumption response could reflect:
* (a) Loss aversion (reference-dependent preferences, Kahneman-Tversky)
* (b) Habit formation (slow adjustment to new consumption levels)
*
* Distinguishing Test:
* - Loss aversion: Asymmetry should be contemporaneous
* - Habit formation: Asymmetry should persist over time (lagged consumption matters)
*
* Solution: Estimate model with lagged consumption and test whether asymmetry
* in δ⁻ is absorbed by habit formation term.
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
log using "${logdir}/R7_loss_aversion_habit.log", replace text

di as text _n "=============================================="
di as text    "  R7: Loss Aversion vs Habit Formation"
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
* 1. CREATE LAGGED CONSUMPTION TERMS
*===============================================================================

di as text _n "=============================================="
di as text    "  1. Create Lagged Consumption Terms"
di as text    "=============================================="

sort idind year

* Lagged consumption levels and changes
by idind: gen L_lnc = lnc[_n-1]
by idind: gen L2_lnc = lnc[_n-2]
by idind: gen L_dlnc = dlnc[_n-1]
by idind: gen L2_dlnc = dlnc[_n-2]

label variable L_lnc "Lagged log consumption"
label variable L2_lnc "Twice-lagged log consumption"
label variable L_dlnc "Lagged Δln(C)"
label variable L2_dlnc "Twice-lagged Δln(C)"

* Lagged income changes (for Δln(Y) persistence)
by idind: gen L_dlny = dlny_lab[_n-1]
by idind: gen L2_dlny = dlny_lab[_n-2]
label variable L_dlny "Lagged Δln(Y)"
label variable L2_dlny "Twice-lagged Δln(Y)"

* Sample with lags
gen byte habit_sample = !missing(dlnc, dlny_pos, dlny_neg, informal, L_dlnc)
count if habit_sample == 1
local N_habit = r(N)
di as text "Habit formation sample: N = `N_habit'"

*===============================================================================
* 2. BASELINE MODEL (WITHOUT HABIT FORMATION)
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Baseline Model (No Habit)"
di as text    "=============================================="

regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if habit_sample == 1, vce(cluster idind)

est store baseline

local delta_neg_base = _b[dlny_neg_x_inf]
local delta_neg_se_base = _se[dlny_neg_x_inf]
local delta_pos_base = _b[dlny_pos_x_inf]

* Wald test for asymmetry
test dlny_pos_x_inf = dlny_neg_x_inf
local wald_F_base = r(F)
local wald_p_base = r(p)

di as text "Baseline estimates:"
di as text "  δ⁺ = " %7.4f `delta_pos_base'
di as text "  δ⁻ = " %7.4f `delta_neg_base' " (SE " %6.4f `delta_neg_se_base' ")"
di as text "  Wald test (δ⁺ = δ⁻): F = " %6.2f `wald_F_base' ", p = " %5.3f `wald_p_base'

*===============================================================================
* 3. HABIT FORMATION MODEL
*===============================================================================

di as text _n "=============================================="
di as text    "  3. Habit Formation Model"
di as text    "=============================================="

* External habit formation: consumption depends on lagged consumption level
* Δc_t = ρ * Δc_{t-1} + ... (partial adjustment)

* Model 3a: Lagged consumption change
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    L_dlnc ///
    $X_demo $X_time if habit_sample == 1, vce(cluster idind)

est store habit_lag1

local delta_neg_habit1 = _b[dlny_neg_x_inf]
local delta_neg_se_habit1 = _se[dlny_neg_x_inf]
local rho_1 = _b[L_dlnc]
local rho_1_se = _se[L_dlnc]

di as text "With lagged Δln(C):"
di as text "  δ⁻ = " %7.4f `delta_neg_habit1' " (SE " %6.4f `delta_neg_se_habit1' ")"
di as text "  ρ (habit) = " %7.4f `rho_1' " (SE " %6.4f `rho_1_se' ")"

* Wald test
test dlny_pos_x_inf = dlny_neg_x_inf
local wald_F_habit1 = r(F)
local wald_p_habit1 = r(p)
di as text "  Wald test (δ⁺ = δ⁻): F = " %6.2f `wald_F_habit1' ", p = " %5.3f `wald_p_habit1'

* Model 3b: Two lags of consumption change
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    L_dlnc L2_dlnc ///
    $X_demo $X_time if habit_sample == 1 & !missing(L2_dlnc), vce(cluster idind)

est store habit_lag2

local delta_neg_habit2 = _b[dlny_neg_x_inf]
local rho_2a = _b[L_dlnc]
local rho_2b = _b[L2_dlnc]

di as text _n "With two lags of Δln(C):"
di as text "  δ⁻ = " %7.4f `delta_neg_habit2'
di as text "  ρ₁ = " %7.4f `rho_2a' ", ρ₂ = " %7.4f `rho_2b'

test dlny_pos_x_inf = dlny_neg_x_inf
local wald_F_habit2 = r(F)
local wald_p_habit2 = r(p)
di as text "  Wald test (δ⁺ = δ⁻): F = " %6.2f `wald_F_habit2' ", p = " %5.3f `wald_p_habit2'

*===============================================================================
* 4. INTERNAL HABIT FORMATION (CONSUMPTION LEVEL)
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Internal Habit Formation (Levels)"
di as text    "=============================================="

* Internal habit: utility depends on difference from past consumption level
* Δc_t = γ * (c_{t-1} - c̄) + ... where c̄ is habit stock

* Use lagged consumption level directly
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    L_lnc ///
    $X_demo $X_time if habit_sample == 1, vce(cluster idind)

est store habit_internal

local delta_neg_internal = _b[dlny_neg_x_inf]
local gamma_internal = _b[L_lnc]

di as text "With lagged ln(C) (internal habit):"
di as text "  δ⁻ = " %7.4f `delta_neg_internal'
di as text "  γ = " %7.4f `gamma_internal'

test dlny_pos_x_inf = dlny_neg_x_inf
local wald_F_internal = r(F)
local wald_p_internal = r(p)
di as text "  Wald test (δ⁺ = δ⁻): F = " %6.2f `wald_F_internal' ", p = " %5.3f `wald_p_internal'

*===============================================================================
* 5. COMBINED MODEL: HABIT + ASYMMETRY
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Combined Model"
di as text    "=============================================="

* Full model with habit and income persistence
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    L_dlnc L_dlny ///
    $X_demo $X_time if habit_sample == 1 & !missing(L_dlny), vce(cluster idind)

est store combined

local delta_neg_combined = _b[dlny_neg_x_inf]
local delta_neg_se_combined = _se[dlny_neg_x_inf]

di as text "Combined model (habit + income persistence):"
di as text "  δ⁻ = " %7.4f `delta_neg_combined' " (SE " %6.4f `delta_neg_se_combined' ")"
di as text "  ρ (consumption habit) = " %7.4f _b[L_dlnc]
di as text "  λ (income persistence) = " %7.4f _b[L_dlny]

test dlny_pos_x_inf = dlny_neg_x_inf
local wald_F_combined = r(F)
local wald_p_combined = r(p)
di as text "  Wald test (δ⁺ = δ⁻): F = " %6.2f `wald_F_combined' ", p = " %5.3f `wald_p_combined'

*===============================================================================
* 6. FORMAL TEST: DOES HABIT ABSORB ASYMMETRY?
*===============================================================================

di as text _n "=============================================="
di as text    "  6. Formal Test"
di as text    "=============================================="

* If habit formation explains asymmetry:
* - δ⁻ should shrink substantially when habit terms added
* - Asymmetry (Wald test) should become insignificant

* Compute percentage reduction in δ⁻
local pct_reduction = 100 * (`delta_neg_base' - `delta_neg_habit1') / `delta_neg_base'

di as text "Effect of controlling for habit formation:"
di as text "  δ⁻ without habit: " %7.4f `delta_neg_base'
di as text "  δ⁻ with habit:    " %7.4f `delta_neg_habit1'
di as text "  Reduction:        " %5.1f `pct_reduction' "%"

di as text _n "Asymmetry significance:"
di as text "  Without habit: p = " %5.3f `wald_p_base'
di as text "  With habit:    p = " %5.3f `wald_p_habit1'

if `wald_p_habit1' < 0.05 & abs(`pct_reduction') < 20 {
    di as text _n "CONCLUSION: Asymmetry is NOT explained by habit formation"
    di as text "            → Supports LOSS AVERSION interpretation"
}
else if `wald_p_habit1' >= 0.05 {
    di as text _n "CONCLUSION: Asymmetry becomes insignificant with habit controls"
    di as text "            → Supports HABIT FORMATION interpretation"
}
else if abs(`pct_reduction') >= 20 {
    di as text _n "CONCLUSION: δ⁻ substantially reduced by habit controls"
    di as text "            → Habit formation plays PARTIAL role"
}

*===============================================================================
* 7. ADDITIONAL TEST: ASYMMETRIC HABIT ADJUSTMENT
*===============================================================================

di as text _n "=============================================="
di as text    "  7. Asymmetric Habit Adjustment"
di as text    "=============================================="

* If losses create stronger habit reference than gains:
* - Lagged positive changes should differ from lagged negative changes

gen L_dlnc_pos = max(L_dlnc, 0) if !missing(L_dlnc)
gen L_dlnc_neg = min(L_dlnc, 0) if !missing(L_dlnc)
label variable L_dlnc_pos "Lagged positive Δln(C)"
label variable L_dlnc_neg "Lagged negative Δln(C)"

regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    L_dlnc_pos L_dlnc_neg ///
    $X_demo $X_time if habit_sample == 1, vce(cluster idind)

est store asymmetric_habit

local rho_pos = _b[L_dlnc_pos]
local rho_neg = _b[L_dlnc_neg]

di as text "Asymmetric habit adjustment:"
di as text "  ρ⁺ (after gains):  " %7.4f `rho_pos'
di as text "  ρ⁻ (after losses): " %7.4f `rho_neg'

test L_dlnc_pos = L_dlnc_neg
local F_asym_habit = r(F)
local p_asym_habit = r(p)
di as text "  Test ρ⁺ = ρ⁻: F = " %6.2f `F_asym_habit' ", p = " %5.3f `p_asym_habit'

*===============================================================================
* 8. DYNAMIC PANEL MODEL (SYSTEM GMM)
*===============================================================================

di as text _n "=============================================="
di as text    "  8. Dynamic Panel (System GMM)"
di as text    "=============================================="

* Check for xtabond2
capture which xtabond2
if _rc {
    di as text "(xtabond2 not installed, skipping dynamic panel)"
}
else {
    * System GMM with lagged dependent variable
    * Addresses Nickell bias in short T panel
    capture xtabond2 dlnc L.dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
        $X_demo i.year, ///
        gmm(L.dlnc, lag(2 4)) iv($X_demo i.year dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf) ///
        robust twostep

    if _rc == 0 {
        est store gmm_dynamic

        di as text "System GMM estimates:"
        di as text "  δ⁻ = " %7.4f _b[dlny_neg_x_inf]
        di as text "  ρ (L.dlnc) = " %7.4f _b[L.dlnc]

        * AR tests
        di as text "  AR(1) p-value: " e(ar1p)
        di as text "  AR(2) p-value: " e(ar2p)
        di as text "  Hansen J p-value: " e(hansenp)
    }
    else {
        di as text "(GMM estimation failed)"
    }
}

*===============================================================================
* 9. COMPARISON TABLE
*===============================================================================

di as text _n "=============================================="
di as text    "  9. Comparison Table"
di as text    "=============================================="

di as text _n "================================================================"
di as text   "Specification           δ⁻        SE       Wald p   Δ from base"
di as text   "================================================================"
di as text   "Baseline (no habit)   " %7.4f `delta_neg_base' "   " %6.4f `delta_neg_se_base' "    " %5.3f `wald_p_base' "    ---"
di as text   "+ Lagged Δln(C)       " %7.4f `delta_neg_habit1' "   " %6.4f `delta_neg_se_habit1' "    " %5.3f `wald_p_habit1' "    " %+5.1f (100*(`delta_neg_habit1'-`delta_neg_base')/`delta_neg_base') "%"
di as text   "+ Two lags Δln(C)     " %7.4f `delta_neg_habit2' "                " %5.3f `wald_p_habit2'
di as text   "+ Lagged ln(C)        " %7.4f `delta_neg_internal' "                " %5.3f `wald_p_internal'
di as text   "Combined model        " %7.4f `delta_neg_combined' "   " %6.4f `delta_neg_se_combined' "    " %5.3f `wald_p_combined'
di as text   "================================================================"

*===============================================================================
* 10. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  10. Export Results"
di as text    "=============================================="

esttab baseline habit_lag1 habit_lag2 habit_internal combined ///
    using "${tables}/R7_habit_formation.tex", replace ///
    keep(dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf L_dlnc L2_dlnc L_lnc L_dlny) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Baseline" "+Lag(1)" "+Lag(2)" "Internal" "Combined") ///
    title("Loss Aversion vs Habit Formation") ///
    label booktabs

* CSV summary
preserve
    clear
    set obs 5
    gen model = ""
    gen delta_neg = .
    gen se = .
    gen wald_p = .

    replace model = "Baseline" in 1
    replace delta_neg = `delta_neg_base' in 1
    replace se = `delta_neg_se_base' in 1
    replace wald_p = `wald_p_base' in 1

    replace model = "Habit(1)" in 2
    replace delta_neg = `delta_neg_habit1' in 2
    replace se = `delta_neg_se_habit1' in 2
    replace wald_p = `wald_p_habit1' in 2

    replace model = "Habit(2)" in 3
    replace delta_neg = `delta_neg_habit2' in 3
    replace wald_p = `wald_p_habit2' in 3

    replace model = "Internal" in 4
    replace delta_neg = `delta_neg_internal' in 4
    replace wald_p = `wald_p_internal' in 4

    replace model = "Combined" in 5
    replace delta_neg = `delta_neg_combined' in 5
    replace se = `delta_neg_se_combined' in 5
    replace wald_p = `wald_p_combined' in 5

    export delimited using "${tables}/R7_habit_comparison.csv", replace
restore

*===============================================================================
* 11. SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  R7 SUMMARY: Loss Aversion vs Habit"
di as text    "=============================================="

di as text _n "DISTINGUISHING TEST:"
di as text "  Loss aversion: Reference point = recent income level"
di as text "                 Asymmetry is CONTEMPORANEOUS"
di as text "  Habit formation: Reference point = past consumption"
di as text "                   Asymmetry PERSISTS over time"

di as text _n "KEY RESULTS:"
di as text "  δ⁻ without habit controls: " %7.4f `delta_neg_base' " (p = " %5.3f `wald_p_base' ")"
di as text "  δ⁻ with habit controls:    " %7.4f `delta_neg_habit1' " (p = " %5.3f `wald_p_habit1' ")"
di as text "  Reduction in δ⁻:           " %5.1f `pct_reduction' "%"
di as text "  Habit coefficient (ρ):     " %7.4f `rho_1' " (SE " %6.4f `rho_1_se' ")"

di as text _n "CONCLUSION:"
if `wald_p_habit1' < 0.05 & abs(`pct_reduction') < 20 {
    di as text "  *** LOSS AVERSION interpretation supported ***"
    di as text "  Asymmetry persists after controlling for habit formation"
    di as text "  The δ⁻ penalty is NOT driven by slow adjustment to past consumption"
}
else if `wald_p_habit1' >= 0.10 {
    di as text "  Habit formation MAY explain part of the asymmetry"
    di as text "  Further investigation needed"
}

log close

di as text _n "Log saved to: ${logdir}/R7_loss_aversion_habit.log"
di as text "Tables saved to: ${tables}/R7_habit_formation.tex"
di as text "                 ${tables}/R7_habit_comparison.csv"

*===============================================================================
* END
*===============================================================================
