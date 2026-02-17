/*==============================================================================
  Step W5 - Credit access mechanism

  Project:  Welfare Cost of Labor Informality
  Purpose:  Test whether restricted credit access is the mechanism through
            which informality reduces consumption smoothing
  Input:    Welfare analysis/Data/welfare_panel_shocks.dta
  Output:   Welfare analysis/Results/Tables/W5_*.csv

  Tests:
    1. Do informal workers borrow less after shocks?
    2. Are informal workers more credit constrained?
    3. Do informal workers rely more on costly informal credit?
    4. Does credit market accessibility mediate the gap?
    5. Do informal workers dis-save more after shocks?

  Author:
  Created:  February 2026
==============================================================================*/

clear all
capture set maxvar 32767
do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close
log using "$logdir/Step_W5_credit.log", replace

use "$data/welfare_panel_shocks.dta", clear
keep if analysis_sample == 1
xtset idind year

*===============================================================================
* 0. SETUP
*===============================================================================

global X_demo "age age2 i.female i.married i.educat hh_size n_children"
global X_loc  "i.urban i.region"
global X_time "i.year"
global X_all  "$X_demo $X_loc $X_time"

* Interaction terms
gen double shock_x_inf      = shock_any * informal
gen double shock_h_x_inf    = shock_health * informal
gen double shock_j_x_inf    = shock_job * informal

label variable shock_x_inf   "Any shock × Informal"
label variable shock_h_x_inf "Health shock × Informal"
label variable shock_j_x_inf "Job shock × Informal"

*===============================================================================
* TEST 1: DO INFORMAL WORKERS BORROW LESS AFTER SHOCKS?
*===============================================================================

di as text _n "=============================================="
di as text    "  TEST 1: BORROWING RESPONSE TO SHOCKS"
di as text    "=============================================="

* Dependent: new formal loan indicator (or change in loan repayment)
* ΔLoan_it = α + β·Shock + γ·Informal + δ·(Shock × Informal) + X'θ + ε

eststo clear

* --- (1a) Has formal credit (level) ---
capture confirm variable has_formal_credit
if _rc == 0 {
    eststo t1a: regress has_formal_credit shock_any informal shock_x_inf ///
        $X_all, vce(cluster idind)

    eststo t1b: regress has_formal_credit shock_health informal shock_h_x_inf ///
        $X_all, vce(cluster idind)

    eststo t1c: regress has_formal_credit shock_job informal shock_j_x_inf ///
        $X_all, vce(cluster idind)
}

* --- (1d) Change in loan repayment ---
capture confirm variable hh_loan_repay
if _rc == 0 {
    gen double d_loan_repay = D.hh_loan_repay
    label variable d_loan_repay "Change in loan repayment"

    eststo t1d: regress d_loan_repay shock_any informal shock_x_inf ///
        $X_all, vce(cluster idind)
}

* --- (1e) FE specification ---
capture confirm variable has_formal_credit
if _rc == 0 {
    eststo t1e: xtreg has_formal_credit shock_any informal shock_x_inf ///
        age age2 $X_time, fe vce(cluster idind)
}

esttab t1*, ///
    keep(shock_any shock_health shock_job informal ///
         shock_x_inf shock_h_x_inf shock_j_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W5.1: Borrowing response to shocks") ///
    note("δ < 0 → informal workers borrow less after shocks")

esttab t1* using "$tables/W5_1_borrowing.csv", replace ///
    keep(shock_any shock_health shock_job informal ///
         shock_x_inf shock_h_x_inf shock_j_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Borrowing response to shocks")

*===============================================================================
* TEST 2: ARE INFORMAL WORKERS MORE CREDIT CONSTRAINED?
*===============================================================================

di as text _n "=============================================="
di as text    "  TEST 2: CREDIT CONSTRAINTS BY INFORMALITY"
di as text    "=============================================="

* CreditConstrained_it = α + β·Informal + X'θ + ε

eststo clear

* --- (2a) Buffer stock < 1 month ---
capture confirm variable buffer_low
if _rc == 0 {
    eststo t2a: regress buffer_low informal $X_all, vce(cluster idind)
    eststo t2a_fe: xtreg buffer_low informal age age2 $X_time, ///
        fe vce(cluster idind)
}

* --- (2b) Buffer stock < 3 months ---
capture confirm variable buffer_med
if _rc == 0 {
    eststo t2b: regress buffer_med informal $X_all, vce(cluster idind)
}

* --- (2c) Loan denied ---
capture confirm variable loan_denied
if _rc == 0 {
    eststo t2c: regress loan_denied informal $X_all, vce(cluster idind)
}

* --- (2d) Discouraged borrower ---
capture confirm variable discouraged
if _rc == 0 {
    eststo t2d: regress discouraged informal $X_all, vce(cluster idind)
}

* --- (2e) Composite credit constraint ---
capture confirm variable credit_constrained
if _rc == 0 {
    eststo t2e: regress credit_constrained informal $X_all, vce(cluster idind)
    eststo t2e_fe: xtreg credit_constrained informal age age2 $X_time, ///
        fe vce(cluster idind)
}

esttab t2*, ///
    keep(informal) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W5.2: Credit constraints by informality") ///
    note("β > 0 → informal workers more credit constrained")

esttab t2* using "$tables/W5_2_constraints.csv", replace ///
    keep(informal) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Credit constraints by informality")

*===============================================================================
* TEST 3: DO INFORMAL WORKERS RELY MORE ON INFORMAL CREDIT?
*===============================================================================

di as text _n "=============================================="
di as text    "  TEST 3: INFORMAL CREDIT RELIANCE"
di as text    "=============================================="

* InformalCredit_it = α + β·Informal + γ·Shock + δ·(Shock × Informal) + X'θ + ε

eststo clear

* --- (3a) Private debt (HYCDEPP > 0) ---
capture confirm variable has_informal_credit
if _rc == 0 {
    eststo t3a: regress has_informal_credit informal shock_any shock_x_inf ///
        $X_all, vce(cluster idind)
}

* --- (3b) Private debt amount ---
capture confirm variable hh_priv_debt
if _rc == 0 {
    gen double ln_priv_debt = ln(hh_priv_debt + 1) if hh_priv_debt >= 0

    eststo t3b: regress ln_priv_debt informal shock_any shock_x_inf ///
        $X_all, vce(cluster idind)
}

* --- (3c) Family transfers received ---
capture confirm variable hh_help_received
if _rc == 0 {
    gen byte received_help = (hh_help_received > 0 & hh_help_received < .)
    gen double ln_help = ln(hh_help_received + 1) if hh_help_received >= 0

    eststo t3c: regress received_help informal shock_any shock_x_inf ///
        $X_all, vce(cluster idind)

    eststo t3d: regress ln_help informal shock_any shock_x_inf ///
        $X_all, vce(cluster idind)
}

* --- (3e) FE specification ---
capture confirm variable has_informal_credit
if _rc == 0 {
    eststo t3e: xtreg has_informal_credit informal shock_any shock_x_inf ///
        age age2 $X_time, fe vce(cluster idind)
}

esttab t3*, ///
    keep(informal shock_any shock_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W5.3: Informal credit reliance") ///
    note("δ > 0 → informal workers rely more on informal credit after shocks")

esttab t3* using "$tables/W5_3_informal_credit.csv", replace ///
    keep(informal shock_any shock_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Informal credit reliance")

*===============================================================================
* TEST 4: DOES CREDIT MARKET ACCESSIBILITY MEDIATE THE GAP?
*===============================================================================

di as text _n "=============================================="
di as text    "  TEST 4: CREDIT MARKET ACCESSIBILITY MEDIATION"
di as text    "=============================================="

* Triple interaction:
* Δln(C) = ... + δ₁·(ΔlnY × Informal) + δ₂·(ΔlnY × Informal × CMA) + ...
* If δ₂ < 0: better credit access reduces the informal smoothing penalty

gen double dlny_x_inf     = dlny_lab * informal
capture drop dlny_x_inf_cma
gen double dlny_x_cma     = .
gen double dlny_x_inf_cma = .
gen double inf_x_cma      = .

capture confirm variable cma_high
if _rc == 0 {
    replace dlny_x_cma     = dlny_lab * cma_high
    replace dlny_x_inf_cma = dlny_lab * informal * cma_high
    replace inf_x_cma      = informal * cma_high

    label variable dlny_x_cma     "Δln(Y) × High CMA"
    label variable dlny_x_inf_cma "Δln(Y) × Informal × High CMA"
    label variable inf_x_cma      "Informal × High CMA"
}

eststo clear

capture confirm variable cma_high
if _rc == 0 {
    * --- (4a) OLS triple interaction ---
    eststo t4a: regress dlnc dlny_lab informal cma_high ///
        dlny_x_inf dlny_x_cma inf_x_cma dlny_x_inf_cma ///
        $X_demo $X_time, vce(cluster idind)

    * --- (4b) With location controls ---
    eststo t4b: regress dlnc dlny_lab informal cma_high ///
        dlny_x_inf dlny_x_cma inf_x_cma dlny_x_inf_cma ///
        $X_demo $X_loc $X_time, vce(cluster idind)

    * --- (4c) FE ---
    eststo t4c: xtreg dlnc dlny_lab informal cma_high ///
        dlny_x_inf dlny_x_cma inf_x_cma dlny_x_inf_cma ///
        age age2 $X_time, fe vce(cluster idind)

    esttab t4a t4b t4c, ///
        keep(dlny_lab informal cma_high ///
             dlny_x_inf dlny_x_cma inf_x_cma dlny_x_inf_cma) ///
        se star(* 0.10 ** 0.05 *** 0.01) ///
        title("Table W5.4: Credit market accessibility mediation") ///
        note("δ₂ (Δln Y × Informal × CMA) < 0 → CMA reduces informality penalty")

    esttab t4a t4b t4c using "$tables/W5_4_CMA_mediation.csv", replace ///
        keep(dlny_lab informal cma_high ///
             dlny_x_inf dlny_x_cma inf_x_cma dlny_x_inf_cma) ///
        se star(* 0.10 ** 0.05 *** 0.01) ///
        title("Credit market accessibility mediation")
}
else {
    di as text "CMA variable not available — skipping Test 4."
    di as text "Consider constructing from regional banking data."
}

*===============================================================================
* TEST 5: SAVINGS RESPONSE TO SHOCKS
*===============================================================================

di as text _n "=============================================="
di as text    "  TEST 5: SAVINGS RESPONSE"
di as text    "=============================================="

eststo clear

* Do informal workers dis-save more after shocks?
capture confirm variable hh_saved
if _rc == 0 {
    eststo t5a: regress hh_saved shock_any informal shock_x_inf ///
        $X_all, vce(cluster idind)

    esttab t5a, ///
        keep(shock_any informal shock_x_inf) ///
        se star(* 0.10 ** 0.05 *** 0.01) ///
        title("Table W5.5: Savings response to shocks")

    esttab t5a using "$tables/W5_5_savings.csv", replace ///
        keep(shock_any informal shock_x_inf) ///
        se star(* 0.10 ** 0.05 *** 0.01) ///
        title("Savings response to shocks")
}

*===============================================================================
* SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  CREDIT MECHANISM SUMMARY"
di as text    "=============================================="

di as text "Test 1: δ < 0 → informal workers borrow less after shocks"
di as text "Test 2: β > 0 → informal workers are more credit constrained"
di as text "Test 3: δ > 0 → informal workers rely more on informal credit"
di as text "Test 4: δ₂ < 0 → credit market accessibility mitigates the gap"
di as text "Test 5: δ < 0 → informal workers dis-save more after shocks"

di as text _n "=============================================="
di as text    "  Step W5 complete."
di as text    "  Tables saved to: $tables/W5_*.csv"
di as text    "=============================================="

log close
