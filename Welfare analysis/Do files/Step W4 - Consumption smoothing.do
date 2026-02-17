/*==============================================================================
  Step W4 - Consumption smoothing estimation

  Project:  Welfare Cost of Labor Informality
  Purpose:  Estimate consumption smoothing coefficients and test whether
            informal workers are less able to smooth consumption
  Input:    Welfare analysis/Data/welfare_panel_shocks.dta
  Output:   Welfare analysis/Results/Tables/W4_*.csv

  Core specification:
    Δln(C_it) = α + β·Δln(Y_it) + γ·Informal_it + δ·(Δln(Y_it)×Informal_it)
                + X_it'θ + μ_i + ε_it

  Key coefficient: δ — excess consumption sensitivity for informal workers
    Full insurance → β = 0
    Larger δ → informal workers further from full insurance

  Author:
  Created:  February 2026
==============================================================================*/

clear all
capture set maxvar 32767
do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close
log using "$logdir/Step_W4_smoothing.log", replace

use "$data/welfare_panel_shocks.dta", clear
keep if analysis_sample == 1
xtset idind year

*===============================================================================
* 0. SETUP: CONTROL VARIABLES AND INTERACTION TERMS
*===============================================================================

* --- Control variable list ---
* Demographics + household composition + location + time
global X_demo  "age age2 i.female i.married i.educat hh_size n_children"
global X_loc   "i.urban i.region"
global X_time  "i.year"
global X_all   "$X_demo $X_loc $X_time"

* --- Interaction: Δln(Y) × Informal ---
gen double dlny_x_inf = dlny_lab * informal
label variable dlny_x_inf "Δln(Y) × Informal"

* Also for disposable income
gen double dlnyd_x_inf = dlny_dis * informal
label variable dlnyd_x_inf "Δln(Y_disp) × Informal"

* --- Change in household composition (control for taste shifters) ---
gen double d_hh_size = D.hh_size
gen double d_n_children = D.n_children
capture gen byte d_married = D.married
global X_taste "d_hh_size d_n_children d_married"

*===============================================================================
* 1. POOLED OLS — BASELINE
*===============================================================================

di as text _n "=============================================="
di as text    "  1. POOLED OLS"
di as text    "=============================================="

* --- (1a) Non-durable consumption, labor income ---
eststo clear

eststo ols1: regress dlnc dlny_lab informal dlny_x_inf ///
    $X_demo $X_time, vce(cluster idind)

eststo ols2: regress dlnc dlny_lab informal dlny_x_inf ///
    $X_demo $X_loc $X_time, vce(cluster idind)

eststo ols3: regress dlnc dlny_lab informal dlny_x_inf ///
    $X_demo $X_loc $X_time $X_taste, vce(cluster idind)

* --- (1b) Using disposable income ---
eststo ols4: regress dlnc dlny_dis informal dlnyd_x_inf ///
    $X_demo $X_loc $X_time $X_taste, vce(cluster idind)

* --- (1c) Durable-inclusive consumption ---
eststo ols5: regress dlncD dlny_lab informal dlny_x_inf ///
    $X_demo $X_loc $X_time $X_taste, vce(cluster idind)

* --- (1d) Food consumption only ---
eststo ols6: regress dlnfood dlny_lab informal dlny_x_inf ///
    $X_demo $X_loc $X_time $X_taste, vce(cluster idind)

esttab ols1 ols2 ols3 ols4 ols5 ols6, ///
    keep(dlny_lab dlny_dis informal dlny_x_inf dlnyd_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4.1: Consumption smoothing — Pooled OLS") ///
    mtitles("(1)" "(2)" "(3)" "(4) Disp.Y" "(5) Dur." "(6) Food") ///
    note("Clustered SE at individual level. Controls: demographics, location, year FE.")

esttab ols1 ols2 ols3 ols4 ols5 ols6 using "$tables/W4_1_OLS.csv", replace ///
    keep(dlny_lab dlny_dis informal dlny_x_inf dlnyd_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Consumption smoothing — Pooled OLS")

*===============================================================================
* 2. INDIVIDUAL FIXED EFFECTS
*===============================================================================

di as text _n "=============================================="
di as text    "  2. INDIVIDUAL FIXED EFFECTS"
di as text    "=============================================="

eststo clear

* (2a) Basic FE
eststo fe1: xtreg dlnc dlny_lab informal dlny_x_inf ///
    $X_time, fe vce(cluster idind)

* (2b) With demographic controls (time-varying)
eststo fe2: xtreg dlnc dlny_lab informal dlny_x_inf ///
    age age2 i.married hh_size n_children $X_time, fe vce(cluster idind)

* (2c) With taste shifters
eststo fe3: xtreg dlnc dlny_lab informal dlny_x_inf ///
    age age2 i.married hh_size n_children $X_taste $X_time, fe vce(cluster idind)

* (2d) Disposable income
eststo fe4: xtreg dlnc dlny_dis informal dlnyd_x_inf ///
    age age2 i.married hh_size n_children $X_taste $X_time, fe vce(cluster idind)

* (2e) Durable-inclusive
eststo fe5: xtreg dlncD dlny_lab informal dlny_x_inf ///
    age age2 i.married hh_size n_children $X_taste $X_time, fe vce(cluster idind)

esttab fe1 fe2 fe3 fe4 fe5, ///
    keep(dlny_lab dlny_dis informal dlny_x_inf dlnyd_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4.2: Consumption smoothing — Individual FE") ///
    mtitles("(1)" "(2)" "(3)" "(4) Disp.Y" "(5) Dur.")

esttab fe1 fe2 fe3 fe4 fe5 using "$tables/W4_2_FE.csv", replace ///
    keep(dlny_lab dlny_dis informal dlny_x_inf dlnyd_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Consumption smoothing — Individual FE")

*===============================================================================
* 3. IV APPROACH — INSTRUMENT Δln(Y) WITH EXOGENOUS SHOCKS
*===============================================================================

di as text _n "=============================================="
di as text    "  3. IV ESTIMATION"
di as text    "=============================================="

* Instruments: health shocks (most exogenous), regional shocks
* Endogenous: dlny_lab, dlny_x_inf
* Excluded instruments: shock_health, shock_health × informal,
*                       shock_regional, shock_regional × informal

gen double shock_health_x_inf = shock_health * informal
gen double shock_job_x_inf    = shock_job * informal
gen double shock_reg_x_inf    = shock_regional * informal

label variable shock_health_x_inf "Health shock × Informal"
label variable shock_job_x_inf    "Job shock × Informal"
label variable shock_reg_x_inf    "Regional shock × Informal"

eststo clear

* --- First stage diagnostics ---
di as text _n "--- First stage: Δln(Y) ---"
regress dlny_lab shock_health shock_health_x_inf ///
    shock_regional shock_reg_x_inf ///
    informal $X_demo $X_time, vce(cluster idind)
test shock_health shock_health_x_inf shock_regional shock_reg_x_inf
di as text "First-stage F-statistic: " r(F)

* --- (3a) IV with health shocks only ---
eststo iv1: ivregress 2sls dlnc informal $X_demo $X_time ///
    (dlny_lab dlny_x_inf = shock_health shock_health_x_inf), ///
    vce(cluster idind)
estat firststage
capture estat overid

* --- (3b) IV with health + regional shocks ---
eststo iv2: ivregress 2sls dlnc informal $X_demo $X_time ///
    (dlny_lab dlny_x_inf = shock_health shock_health_x_inf ///
     shock_regional shock_reg_x_inf), ///
    vce(cluster idind)
estat firststage
capture estat overid

* --- (3c) IV with all shocks (health + job + regional) ---
eststo iv3: ivregress 2sls dlnc informal $X_demo $X_loc $X_time ///
    (dlny_lab dlny_x_inf = shock_health shock_health_x_inf ///
     shock_job shock_job_x_inf ///
     shock_regional shock_reg_x_inf), ///
    vce(cluster idind)
estat firststage
capture estat overid

esttab iv1 iv2 iv3, ///
    keep(dlny_lab informal dlny_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4.3: Consumption smoothing — IV") ///
    mtitles("Health IV" "Health+Reg IV" "All shocks IV")

esttab iv1 iv2 iv3 using "$tables/W4_3_IV.csv", replace ///
    keep(dlny_lab informal dlny_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Consumption smoothing — IV")

*===============================================================================
* 4. BY SHOCK TYPE — REDUCED-FORM ESTIMATES
*===============================================================================

di as text _n "=============================================="
di as text    "  4. BY SHOCK TYPE (REDUCED FORM)"
di as text    "=============================================="

eststo clear

* (4a) Health shocks
eststo rf_health: regress dlnc shock_health informal shock_health_x_inf ///
    $X_demo $X_loc $X_time, vce(cluster idind)

* (4b) Job shocks
eststo rf_job: regress dlnc shock_job informal shock_job_x_inf ///
    $X_demo $X_loc $X_time, vce(cluster idind)

* (4c) Regional shocks
eststo rf_reg: regress dlnc shock_regional informal shock_reg_x_inf ///
    $X_demo $X_loc $X_time, vce(cluster idind)

* (4d) Any shock
gen double shock_any_x_inf = shock_any * informal
eststo rf_any: regress dlnc shock_any informal shock_any_x_inf ///
    $X_demo $X_loc $X_time, vce(cluster idind)

esttab rf_health rf_job rf_reg rf_any, ///
    keep(shock_health shock_job shock_regional shock_any ///
         informal shock_health_x_inf shock_job_x_inf ///
         shock_reg_x_inf shock_any_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4.4: Consumption response by shock type")

esttab rf_health rf_job rf_reg rf_any using "$tables/W4_4_shocktype.csv", replace ///
    keep(shock_health shock_job shock_regional shock_any ///
         informal shock_health_x_inf shock_job_x_inf ///
         shock_reg_x_inf shock_any_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Consumption response by shock type")

*===============================================================================
* 5. TRANSITION ANALYSIS — WITHIN-PERSON VARIATION
*===============================================================================

di as text _n "=============================================="
di as text    "  5. TRANSITION ANALYSIS"
di as text    "=============================================="

* Restrict to individuals observed in BOTH formal and informal status
* This provides the strongest identification

bysort idind: egen byte ever_formal   = max(informal == 0)
bysort idind: egen byte ever_informal = max(informal == 1)
gen byte switcher = (ever_formal == 1 & ever_informal == 1)
label variable switcher "Observed in both formal and informal status"

di as text "Switchers: " _N " obs from switchers"
tab switcher

eststo clear

* (5a) Full sample vs switchers only
eststo sw1: xtreg dlnc dlny_lab informal dlny_x_inf ///
    age age2 $X_taste $X_time, fe vce(cluster idind)

eststo sw2: xtreg dlnc dlny_lab informal dlny_x_inf ///
    age age2 $X_taste $X_time if switcher == 1, fe vce(cluster idind)

* (5b) Asymmetric effects: formal→informal vs informal→formal
gen double dlny_x_f2i = dlny_lab * trans_form_to_inf
gen double dlny_x_i2f = dlny_lab * trans_inf_to_form

eststo sw3: xtreg dlnc dlny_lab trans_form_to_inf trans_inf_to_form ///
    dlny_x_f2i dlny_x_i2f ///
    age age2 $X_taste $X_time if switcher == 1, fe vce(cluster idind)

esttab sw1 sw2 sw3, ///
    keep(dlny_lab informal dlny_x_inf dlny_x_f2i dlny_x_i2f ///
         trans_form_to_inf trans_inf_to_form) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4.5: Transition analysis")

esttab sw1 sw2 sw3 using "$tables/W4_5_transitions.csv", replace ///
    keep(dlny_lab informal dlny_x_inf dlny_x_f2i dlny_x_i2f ///
         trans_form_to_inf trans_inf_to_form) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Transition analysis")

*===============================================================================
* 6. HETEROGENEITY ANALYSIS
*===============================================================================

di as text _n "=============================================="
di as text    "  6. HETEROGENEITY"
di as text    "=============================================="

eststo clear

* (6a) By gender
eststo het_male: regress dlnc dlny_lab informal dlny_x_inf ///
    $X_demo $X_loc $X_time if female == 0, vce(cluster idind)

eststo het_female: regress dlnc dlny_lab informal dlny_x_inf ///
    $X_demo $X_loc $X_time if female == 1, vce(cluster idind)

* (6b) By education
eststo het_lowedu: regress dlnc dlny_lab informal dlny_x_inf ///
    $X_demo $X_loc $X_time if educat <= 2, vce(cluster idind)

eststo het_highedu: regress dlnc dlny_lab informal dlny_x_inf ///
    $X_demo $X_loc $X_time if educat == 3, vce(cluster idind)

* (6c) By urban/rural
eststo het_urban: regress dlnc dlny_lab informal dlny_x_inf ///
    $X_demo $X_time if urban == 1, vce(cluster idind)

eststo het_rural: regress dlnc dlny_lab informal dlny_x_inf ///
    $X_demo $X_time if urban == 0, vce(cluster idind)

* (6d) By credit accessibility
capture confirm variable cma_high
if _rc == 0 {
    eststo het_cma_hi: regress dlnc dlny_lab informal dlny_x_inf ///
        $X_demo $X_time if cma_high == 1, vce(cluster idind)

    eststo het_cma_lo: regress dlnc dlny_lab informal dlny_x_inf ///
        $X_demo $X_time if cma_high == 0, vce(cluster idind)
}

esttab het_male het_female het_lowedu het_highedu het_urban het_rural, ///
    keep(dlny_lab informal dlny_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4.6: Heterogeneity analysis") ///
    mtitles("Male" "Female" "Low edu" "High edu" "Urban" "Rural")

esttab het_male het_female het_lowedu het_highedu het_urban het_rural ///
    using "$tables/W4_6_heterogeneity.csv", replace ///
    keep(dlny_lab informal dlny_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Heterogeneity analysis")

*===============================================================================
* 7. ROBUSTNESS: ALTERNATIVE INFORMALITY DEFINITIONS
*===============================================================================

di as text _n "=============================================="
di as text    "  7. ROBUSTNESS — INFORMALITY DEFINITIONS"
di as text    "=============================================="

eststo clear

* (7a) Registration-based definition
gen double dlny_x_inf_reg = dlny_lab * informal_reg
eststo rob1: regress dlnc dlny_lab informal_reg dlny_x_inf_reg ///
    $X_demo $X_loc $X_time $X_taste, vce(cluster idind)

* (7b) Envelope-earnings definition
gen double dlny_x_inf_env = dlny_lab * informal_env
eststo rob2: regress dlnc dlny_lab informal_env dlny_x_inf_env ///
    $X_demo $X_loc $X_time $X_taste, vce(cluster idind)

* (7c) Combined definition (baseline)
eststo rob3: regress dlnc dlny_lab informal dlny_x_inf ///
    $X_demo $X_loc $X_time $X_taste, vce(cluster idind)

esttab rob1 rob2 rob3, ///
    keep(dlny_lab informal_reg informal_env informal ///
         dlny_x_inf_reg dlny_x_inf_env dlny_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4.7: Robustness — informality definitions") ///
    mtitles("Registration" "Envelope" "Combined")

esttab rob1 rob2 rob3 using "$tables/W4_7_robustness_def.csv", replace ///
    keep(dlny_lab informal_reg informal_env informal ///
         dlny_x_inf_reg dlny_x_inf_env dlny_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Robustness — informality definitions")

*===============================================================================
* 8. SUMMARY OF KEY COEFFICIENTS
*===============================================================================

di as text _n "=============================================="
di as text    "  SUMMARY OF KEY RESULTS"
di as text    "=============================================="

di as text _n "Key coefficient: δ (excess consumption sensitivity for informal)"
di as text    "Full insurance → β = 0; larger δ → worse smoothing for informal"
di as text    ""

* Collect key estimates
foreach m in ols3 fe3 iv2 {
    capture estimates restore `m'
    di as text "`m':"
    di as text "  β (Δln Y)           = " _b[dlny_lab] " (SE = " _se[dlny_lab] ")"
    di as text "  δ (Δln Y × Informal) = " _b[dlny_x_inf] " (SE = " _se[dlny_x_inf] ")"
    di as text ""
}

*===============================================================================

di as text _n "=============================================="
di as text    "  Step W4 complete."
di as text    "  Tables saved to: $tables/W4_*.csv"
di as text    "=============================================="

log close
