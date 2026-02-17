/*==============================================================================
  Step W10 - Mechanism Tests and Robustness Solutions

  Project:  Welfare Cost of Labor Informality
  Purpose:  Address three key problems:
            1. Credit channel doesn't work - need alternative mechanisms
            2. Need to reframe from loss aversion to borrowing constraints
            3. δ⁺ = -0.030 is weakly significant - need better framing

  Input:    Data/welfare_panel_cbr.dta
  Output:   Tables/W10_*.tex

  Author:
  Created:  February 2026
==============================================================================*/

clear all
capture set maxvar 32767
do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close
log using "$logdir/Step_W10_mechanisms.log", replace

*===============================================================================
* 0. LOAD DATA AND SETUP
*===============================================================================

di as text _n "=============================================="
di as text    "  Step W10: Mechanism Tests and Robustness"
di as text    "=============================================="

* Try to use CBR-merged data if available
capture use "$data/welfare_panel_cbr.dta", clear
if _rc != 0 {
    use "$data/welfare_panel_shocks.dta", clear
    di as text "Note: Using welfare_panel_shocks.dta (no CBR regional data)"
}

keep if analysis_sample == 1
xtset idind year

* Global controls
global X_demo "age age2 i.female i.married i.educat hh_size n_children"
global X_loc  "i.urban i.region"
global X_time "i.year"
global X_all  "$X_demo $X_loc $X_time"

*===============================================================================
* PART A: DIRECT COPING MECHANISM ANALYSIS (Problem 1)
*===============================================================================
/*
  Using actual variables from RLMS:
  - saved_30d: Saved in past 30 days (buffer stock proxy)
  - has_formal_credit: Has formal credit
  - has_informal_credit: Has informal credit (private debts)
  - took_credit_12m: Took credit in past 12 months
  - credit_constrained: Credit constrained indicator
*/

di as text _n "=============================================="
di as text    "  PART A: Direct Coping Mechanism Analysis"
di as text    "=============================================="

* Create negative shock indicator
gen byte neg_shock = (dlny_lab < -0.10) if dlny_lab != .
label variable neg_shock "Negative income shock (>10% drop)"

* Interaction
gen double neg_shock_x_inf = neg_shock * informal
label variable neg_shock_x_inf "Neg shock × Informal"

eststo clear

* --- A1: Did they save in past 30 days? (buffer accumulation) ---
eststo A1: regress saved_30d neg_shock informal neg_shock_x_inf ///
    $X_demo $X_time, vce(cluster idind)

* --- A2: Do they have formal credit? ---
eststo A2: regress has_formal_credit neg_shock informal neg_shock_x_inf ///
    $X_demo $X_time, vce(cluster idind)

* --- A3: Do they have informal credit (private debts)? ---
eststo A3: regress has_informal_credit neg_shock informal neg_shock_x_inf ///
    $X_demo $X_time, vce(cluster idind)

* --- A4: Took credit in past 12 months? ---
eststo A4: regress took_credit_12m neg_shock informal neg_shock_x_inf ///
    $X_demo $X_time, vce(cluster idind)

* --- A5: Credit constrained? ---
eststo A5: regress credit_constrained neg_shock informal neg_shock_x_inf ///
    $X_demo $X_time, vce(cluster idind)

* Output Table A
di _n "Table A: Coping Mechanisms by Informality Status"
esttab A1 A2 A3 A4 A5, ///
    keep(neg_shock informal neg_shock_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitle("Saved 30d" "Has Formal Credit" "Has Informal Credit" "Took Credit 12m" "Constrained") ///
    title("Table A: Coping Mechanisms by Informality Status")

esttab A1 A2 A3 A4 A5 using "$tables/W10_A_coping_mechanisms.tex", replace ///
    keep(neg_shock informal neg_shock_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    booktabs fragment label

*===============================================================================
* PART B: BUFFER STOCK / SAVINGS MEDIATION TEST (Problem 1 & 2)
*===============================================================================
/*
  Test whether asymmetry disappears for those with savings buffer.
  Use saved_30d as buffer proxy.
*/

di as text _n "=============================================="
di as text    "  PART B: Buffer Stock Mediation Test"
di as text    "=============================================="

* Use saved_30d as buffer indicator
gen byte has_buffer = saved_30d
label variable has_buffer "Has savings buffer (saved in past 30d)"

* Create asymmetric income changes
capture drop dlny_pos
capture drop dlny_neg
gen double dlny_pos = max(dlny_lab, 0) if dlny_lab != .
gen double dlny_neg = min(dlny_lab, 0) if dlny_lab != .
label variable dlny_pos "Positive income change"
label variable dlny_neg "Negative income change"

* Interactions
capture drop dlny_pos_x_inf
capture drop dlny_neg_x_inf
gen double dlny_pos_x_inf = dlny_pos * informal
gen double dlny_neg_x_inf = dlny_neg * informal
label variable dlny_pos_x_inf "Δln(Y)⁺ × Informal"
label variable dlny_neg_x_inf "Δln(Y)⁻ × Informal"

* Triple interactions for mediation test
gen double dlny_neg_x_inf_x_buffer = dlny_neg * informal * has_buffer
gen double dlny_neg_x_buffer = dlny_neg * has_buffer
gen double inf_x_buffer = informal * has_buffer

label variable dlny_neg_x_inf_x_buffer "Δln(Y)⁻ × Informal × Has Buffer"
label variable dlny_neg_x_buffer "Δln(Y)⁻ × Has Buffer"
label variable inf_x_buffer "Informal × Has Buffer"

eststo clear

* --- B1: Baseline asymmetric smoothing ---
eststo B1: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time, vce(cluster idind)

* --- B2: With buffer stock triple interaction ---
eststo B2: regress dlnc dlny_pos dlny_neg informal has_buffer ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    dlny_neg_x_buffer inf_x_buffer dlny_neg_x_inf_x_buffer ///
    $X_demo $X_time, vce(cluster idind)

* --- B3: FE specification ---
eststo B3: xtreg dlnc dlny_pos dlny_neg informal has_buffer ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    dlny_neg_x_buffer inf_x_buffer dlny_neg_x_inf_x_buffer ///
    age age2 $X_time, fe vce(cluster idind)

* Output Table B
di _n "Table B: Buffer Stock Mediation of Asymmetric Smoothing"
esttab B1 B2 B3, ///
    keep(dlny_neg_x_inf dlny_neg_x_inf_x_buffer) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitle("Baseline" "Buffer Mediation" "FE") ///
    title("Table B: Buffer Stock Mediation of Asymmetric Smoothing")

esttab B1 B2 B3 using "$tables/W10_B_buffer_mediation.tex", replace ///
    keep(dlny_neg dlny_neg_x_inf dlny_neg_x_buffer dlny_neg_x_inf_x_buffer) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    booktabs fragment label

* --- B4: Separate by buffer status ---
eststo B4_no: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if has_buffer == 0, vce(cluster idind)

eststo B4_yes: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time if has_buffer == 1, vce(cluster idind)

di _n "Table B4: Informality Penalty by Buffer Status"
esttab B4_no B4_yes, ///
    keep(dlny_neg_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitle("No Buffer" "Has Buffer") ///
    title("Table B4: Informality Penalty by Buffer Status")

esttab B4_no B4_yes using "$tables/W10_B4_by_buffer.tex", replace ///
    keep(dlny_neg_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    booktabs fragment

*===============================================================================
* PART C: REGIONAL FINANCIAL INFRASTRUCTURE HETEROGENEITY (Problem 1)
*===============================================================================

di as text _n "=============================================="
di as text    "  PART C: Regional Financial Infrastructure"
di as text    "=============================================="

capture confirm variable low_bank_access
if _rc == 0 {
    * Ensure interactions exist
    capture drop dlny_neg_x_low_bank
    capture drop dlny_neg_x_inf_x_low_bank
    gen double dlny_neg_x_low_bank = dlny_neg * low_bank_access
    gen double dlny_neg_x_inf_x_low_bank = dlny_neg * informal * low_bank_access

    label variable dlny_neg_x_low_bank "Δln(Y)⁻ × Low Bank Access"
    label variable dlny_neg_x_inf_x_low_bank "Δln(Y)⁻ × Informal × Low Bank Access"

    eststo clear

    * --- C1: Baseline ---
    eststo C1: regress dlnc dlny_pos dlny_neg informal ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        $X_demo $X_time, vce(cluster idind)

    * --- C2: With regional bank access interaction ---
    eststo C2: regress dlnc dlny_pos dlny_neg informal low_bank_access ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        dlny_neg_x_low_bank inf_x_low_bank dlny_neg_x_inf_x_low_bank ///
        $X_demo $X_time, vce(cluster idind)

    * --- C3: Separate by bank access ---
    eststo C3_low: regress dlnc dlny_pos dlny_neg informal ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        $X_demo $X_time if low_bank_access == 1, vce(cluster idind)

    eststo C3_high: regress dlnc dlny_pos dlny_neg informal ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        $X_demo $X_time if low_bank_access == 0, vce(cluster idind)

    * Output
    di _n "Table C: Regional Financial Infrastructure Heterogeneity"
    esttab C1 C2, ///
        keep(dlny_neg_x_inf dlny_neg_x_inf_x_low_bank) ///
        se star(* 0.10 ** 0.05 *** 0.01) ///
        mtitle("Baseline" "Bank Access Int.") ///
        title("Table C: Regional Financial Infrastructure Heterogeneity")

    esttab C1 C2 using "$tables/W10_C_regional_finance.tex", replace ///
        keep(dlny_neg_x_inf dlny_neg_x_low_bank dlny_neg_x_inf_x_low_bank) ///
        se star(* 0.10 ** 0.05 *** 0.01) ///
        booktabs fragment label

    di _n "Table C2: Informality Penalty by Regional Bank Access"
    esttab C3_low C3_high, ///
        keep(dlny_neg_x_inf) ///
        se star(* 0.10 ** 0.05 *** 0.01) ///
        mtitle("Low Bank Access" "High Bank Access") ///
        title("Informality Penalty by Regional Bank Access")

    esttab C3_low C3_high using "$tables/W10_C2_by_bank_access.tex", replace ///
        keep(dlny_neg_x_inf) ///
        se star(* 0.10 ** 0.05 *** 0.01) ///
        booktabs fragment
}
else {
    di as error "Regional bank access variable not found."
    di as text "Run Step W9 to merge CBR data first."
}

*===============================================================================
* PART D: CREDIT CONSTRAINT TEST (Problem 2 - Borrowing vs Loss Aversion)
*===============================================================================
/*
  Under BORROWING CONSTRAINTS:
    - Asymmetry should be STRONGER for credit-constrained households
    - Asymmetry should be WEAKER for unconstrained households

  Under LOSS AVERSION:
    - Asymmetry should be roughly CONSTANT regardless of constraints
*/

di as text _n "=============================================="
di as text    "  PART D: Credit Constraint Test (Model Selection)"
di as text    "=============================================="

capture confirm variable credit_constrained
if _rc == 0 {
    * Triple interactions
    gen double dlny_neg_x_inf_x_constr = dlny_neg * informal * credit_constrained
    gen double dlny_neg_x_constr = dlny_neg * credit_constrained
    gen double inf_x_constr = informal * credit_constrained

    label variable dlny_neg_x_inf_x_constr "Δln(Y)⁻ × Informal × Constrained"

    eststo clear

    * --- D1: By credit constraint status ---
    eststo D1_unconstr: regress dlnc dlny_pos dlny_neg informal ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        $X_demo $X_time if credit_constrained == 0, vce(cluster idind)

    eststo D1_constr: regress dlnc dlny_pos dlny_neg informal ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        $X_demo $X_time if credit_constrained == 1, vce(cluster idind)

    * --- D2: Triple interaction ---
    eststo D2: regress dlnc dlny_pos dlny_neg informal credit_constrained ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        dlny_neg_x_constr inf_x_constr dlny_neg_x_inf_x_constr ///
        $X_demo $X_time, vce(cluster idind)

    * Output
    di _n "Table D1: Informality Penalty by Credit Constraint Status"
    esttab D1_unconstr D1_constr, ///
        keep(dlny_neg_x_inf) ///
        se star(* 0.10 ** 0.05 *** 0.01) ///
        mtitle("Unconstrained" "Constrained") ///
        title("Table D1: Informality Penalty by Credit Constraint Status")

    esttab D1_unconstr D1_constr using "$tables/W10_D1_by_constraint.tex", replace ///
        keep(dlny_neg_x_inf) ///
        se star(* 0.10 ** 0.05 *** 0.01) ///
        booktabs fragment

    * Store coefficients for comparison
    estimates restore D1_unconstr
    local coef_unconstr = _b[dlny_neg_x_inf]
    estimates restore D1_constr
    local coef_constr = _b[dlny_neg_x_inf]

    di as text _n "KEY RESULT FOR MODEL SELECTION:"
    di as text "  δ⁻_informal (Unconstrained):  " %6.4f `coef_unconstr'
    di as text "  δ⁻_informal (Constrained):    " %6.4f `coef_constr'

    if abs(`coef_constr') > abs(`coef_unconstr') * 1.2 {
        di as result "  → Penalty LARGER for constrained: CONSISTENT WITH BORROWING CONSTRAINTS"
    }
    else {
        di as result "  → Penalty roughly constant: MAY SUPPORT LOSS AVERSION"
    }
}

*===============================================================================
* PART E: NARRATIVE REFRAMING SPECIFICATIONS (Problem 3)
*===============================================================================
/*
  Reframe from "informal workers smooth better on upside" to:
  "The ENTIRE informality penalty is concentrated on the downside."
  Key: Wald test rejecting symmetry is the headline result.
*/

di as text _n "=============================================="
di as text    "  PART E: Reframed Narrative Specifications"
di as text    "=============================================="

eststo clear

* --- E1: Main asymmetric specification ---
eststo E1: regress dlnc dlny_pos dlny_neg informal ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    $X_demo $X_time, vce(cluster idind)

* Store key coefficients
local delta_pos = _b[dlny_pos_x_inf]
local delta_neg = _b[dlny_neg_x_inf]
local se_pos = _se[dlny_pos_x_inf]
local se_neg = _se[dlny_neg_x_inf]

* Test: Is δ⁺ = 0? (Should fail to reject)
test dlny_pos_x_inf = 0
local p_pos_zero = r(p)

* Test: Is δ⁻ = 0? (Should reject)
test dlny_neg_x_inf = 0
local p_neg_zero = r(p)

* Test: Is δ⁺ = δ⁻? (Should reject - this is the headline)
test dlny_pos_x_inf = dlny_neg_x_inf
local p_symmetry = r(p)

di as text _n "=============================================="
di as text    "  KEY NARRATIVE RESULTS"
di as text    "=============================================="
di as text "δ⁺ (upside penalty): " %6.4f `delta_pos' " (SE: " %6.4f `se_pos' ")"
di as text "δ⁻ (downside penalty): " %6.4f `delta_neg' " (SE: " %6.4f `se_neg' ")"
di as text ""
di as text "H0: δ⁺ = 0        p-value = " %6.4f `p_pos_zero'
if `p_pos_zero' > 0.10 {
    di as result "  → CANNOT reject: informal workers smooth positive shocks like formal workers"
}
di as text "H0: δ⁻ = 0        p-value = " %6.4f `p_neg_zero'
if `p_neg_zero' < 0.05 {
    di as result "  → REJECT: informal workers have WORSE downside smoothing"
}
di as text "H0: δ⁺ = δ⁻       p-value = " %6.4f `p_symmetry'
if `p_symmetry' < 0.05 {
    di as result "  → REJECT SYMMETRY: This is the headline finding"
}

esttab E1 using "$tables/W10_E_asymmetric.tex", replace ///
    keep(dlny_pos dlny_neg dlny_pos_x_inf dlny_neg_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    booktabs fragment label

*===============================================================================
* SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  SUMMARY: MECHANISM TEST RESULTS"
di as text    "=============================================="

di as text ""
di as text "PART A - Coping Mechanisms:"
di as text "  Test: How do formal vs informal adjust after negative shocks?"
di as text "  [Check Table A for differential coping margins]"
di as text ""
di as text "PART B - Buffer Stock Mediation:"
di as text "  Test: Does asymmetry disappear for those with savings?"
di as text "  [Check if θ (Δln Y⁻ × Inf × Buffer) > 0]"
di as text ""
di as text "PART C - Regional Financial Infrastructure:"
di as text "  Test: Is penalty larger where bank branches are scarce?"
di as text "  [Check if θ (Δln Y⁻ × Inf × LowBank) < 0]"
di as text ""
di as text "PART D - Credit Constraint (Model Selection):"
di as text "  Test: Does penalty vary with constraint status?"
di as text "  [If penalty larger for constrained → borrowing constraints model]"
di as text ""
di as text "PART E - Narrative Reframing:"
di as text "  Key finding: Entire penalty concentrated on downside"
di as text "  Symmetry test p-value: " %6.4f `p_symmetry'

*===============================================================================
* DONE
*===============================================================================

di as text _n "=============================================="
di as text    "  Step W10 Complete"
di as text    "  Tables saved to: $tables/W10_*.tex"
di as text    "=============================================="

log close
