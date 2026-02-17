/*==============================================================================
  Step W4b - Extended Robustness Checks

  Project:  Welfare Cost of Labor Informality
  Purpose:  Additional specifications requested for robustness:
            1. IV for income growth (Bartik-style, regional unemployment)
            2. Asymmetric responses (positive vs negative shocks)
            3. Shock-based specifications (direct effect of shocks)
            4. Triple interaction with credit constraints
            5. Quantile regression
            6. Within-person transitions (event study)
            7. Correlated random effects / Mundlak specification
            8. Separate regressions by consumption component
            9. Aggregate shock interactions (crisis periods)

  Input:    Welfare analysis/Data/welfare_panel_shocks.dta
  Output:   Welfare analysis/Tables/W4b_*.csv

  Author:
  Created:  February 2026
==============================================================================*/

clear all
capture set maxvar 32767
do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close
log using "$logdir/Step_W4b_extended.log", replace

use "$data/welfare_panel_shocks.dta", clear
keep if analysis_sample == 1
xtset idind year

* Create interaction variables fresh
* (may or may not exist in dataset)
capture drop dlny_inf
gen double dlny_inf = dlny_lab * informal if dlny_lab < . & informal < .
label variable dlny_inf "Income growth × Informal"

* Shock interactions for IV
capture drop shock_health_x_inf shock_job_x_inf shock_regional_x_inf
gen byte shock_health_x_inf = shock_health * informal if shock_health < . & informal < .
gen byte shock_job_x_inf = shock_job * informal if shock_job < . & informal < .
gen byte shock_regional_x_inf = shock_regional * informal if shock_regional < . & informal < .
label variable shock_health_x_inf "Health shock × Informal"
label variable shock_job_x_inf "Job shock × Informal"
label variable shock_regional_x_inf "Regional shock × Informal"

di as text _n "=============================================="
di as text    "  Step W4b: Extended Robustness Checks"
di as text    "  Observations: " _N
di as text    "=============================================="

*===============================================================================
* 0. SETUP - Create additional variables needed
*===============================================================================

* Crisis period dummies
capture drop crisis_2008 crisis_2014 crisis_2020 any_crisis
gen byte crisis_2008 = (year >= 2008 & year <= 2009)
gen byte crisis_2014 = (year >= 2014 & year <= 2015)
gen byte crisis_2020 = (year == 2020)
gen byte any_crisis = (crisis_2008 | crisis_2014 | crisis_2020)

label variable crisis_2008 "2008-09 financial crisis"
label variable crisis_2014 "2014-15 sanctions/ruble crisis"
label variable crisis_2020 "2020 COVID crisis"
label variable any_crisis "Any crisis period"

* Positive and negative income changes
capture drop dlny_pos dlny_neg dlny_pos_x_inf dlny_neg_x_inf
gen double dlny_pos = max(dlny_lab, 0) if dlny_lab < .
gen double dlny_neg = min(dlny_lab, 0) if dlny_lab < .
gen double dlny_pos_x_inf = dlny_pos * informal
gen double dlny_neg_x_inf = dlny_neg * informal

label variable dlny_pos "Positive income growth (max(dlnY, 0))"
label variable dlny_neg "Negative income growth (min(dlnY, 0))"

* Interactions for crisis specifications
capture drop dlny_x_crisis dyInfCrisis
gen double dlny_x_crisis = dlny_lab * any_crisis if dlny_lab < .
gen double dyInfCrisis = dlny_lab * informal * any_crisis if dlny_lab < .

* Triple interaction with credit constraints
capture drop dlny_x_cc dyInfCC
gen double dlny_x_cc = dlny_lab * credit_constrained if dlny_lab < .
gen double dyInfCC = dlny_lab * informal * credit_constrained if dlny_lab < .

* Mundlak terms (individual means of time-varying variables)
foreach v in dlny_lab informal age hh_size {
    capture drop `v'_mean
    bysort idind: egen double `v'_mean = mean(`v')
    label variable `v'_mean "Individual mean of `v'"
}

* Formal-to-informal transition indicator
sort idind year
foreach v in L_informal switch_to_informal switch_to_formal {
    capture drop `v'
}
by idind: gen byte L_informal = informal[_n-1]
gen byte switch_to_informal = (informal == 1 & L_informal == 0) if L_informal < .
gen byte switch_to_formal = (informal == 0 & L_informal == 1) if L_informal < .

label variable switch_to_informal "Switched from formal to informal"
label variable switch_to_formal "Switched from informal to formal"

* Time relative to switch (for event study)
* For each individual who ever switches to informal, calculate time relative to first switch
capture drop ever_switch_to_inf first_switch_year rel_time
gen byte ever_switch_to_inf = 0
bysort idind: replace ever_switch_to_inf = 1 if sum(switch_to_informal) > 0

* Find first switch year for each person
gen int first_switch_year = .
bysort idind (year): replace first_switch_year = year if switch_to_informal == 1 & first_switch_year[_n-1] == .
bysort idind (year): replace first_switch_year = first_switch_year[_n-1] if first_switch_year == .

* Time relative to switch
gen int rel_time = year - first_switch_year if ever_switch_to_inf == 1

* Regional unemployment (create if not exists)
capture confirm variable regional_unemp
if _rc != 0 {
    * Create regional unemployment from shock_regional as proxy
    gen double regional_unemp = shock_regional
}

* Bartik-style instrument: Use regional shock interacted with initial informality rate
* First, compute regional informality rate in first year of sample for each region
capture confirm variable region
if _rc != 0 {
    * Create region proxy from available data
    egen region = group(id_h), label
}

* Compute baseline (2006) regional informality rate
capture drop reg_inf_rate_2006 reg_inf_rate_base bartik_iv
bysort region: egen double reg_inf_rate_2006 = mean(informal) if year == 2006
bysort region: egen double reg_inf_rate_base = max(reg_inf_rate_2006)
drop reg_inf_rate_2006

* Bartik instrument: regional shock × baseline informality rate
gen double bartik_iv = shock_regional * reg_inf_rate_base

label variable bartik_iv "Bartik IV: regional shock × baseline informality"

*===============================================================================
* 1. INSTRUMENTAL VARIABLES FOR INCOME GROWTH
*===============================================================================

di as text _n "=============================================="
di as text    "  1. IV FOR INCOME GROWTH"
di as text    "=============================================="

* Baseline OLS for comparison
eststo clear
quietly regress dlnc dlny_lab informal dlny_inf ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo ols_base

* IV using health shocks as instruments
* First stage diagnostics
di as text _n "--- First stage: health shock instruments ---"
quietly regress dlny_lab shock_health shock_health_x_inf ///
    informal age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
local F_health = e(F)
di as text "First stage F-statistic (health shocks): " %6.2f `F_health'

* IV estimation with health shocks
di as text _n "--- 2SLS with health shock instruments ---"
capture ivregress 2sls dlnc (dlny_lab dlny_inf = shock_health shock_health_x_inf) ///
    informal age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
if _rc == 0 {
    eststo iv_health
    di as text "IV estimate of beta (dlny_lab): " _b[dlny_lab]
    di as text "IV estimate of delta (dlny_inf): " _b[dlny_inf]
}
else {
    di as error "IV with health shocks failed"
}

* IV using regional shocks
di as text _n "--- 2SLS with regional shock instruments ---"
capture ivregress 2sls dlnc (dlny_lab dlny_inf = shock_regional shock_job) ///
    informal age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
if _rc == 0 {
    eststo iv_regional
}

* IV using Bartik instrument
di as text _n "--- 2SLS with Bartik instrument ---"
gen double bartik_x_inf = bartik_iv * informal
capture ivregress 2sls dlnc (dlny_lab dlny_inf = bartik_iv bartik_x_inf shock_health) ///
    informal age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
if _rc == 0 {
    eststo iv_bartik
}

* Export IV results
esttab ols_base iv_health iv_regional iv_bartik using "$tables/W4b_1_IV.csv", replace ///
    keep(dlny_lab informal dlny_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4b.1: IV Estimates for Income Growth") ///
    mtitles("OLS" "IV: Health" "IV: Regional" "IV: Bartik") ///
    addnotes("Instruments: health shocks, regional shocks, Bartik-style")

*===============================================================================
* 2. ASYMMETRIC RESPONSES (POSITIVE VS NEGATIVE SHOCKS)
*===============================================================================

di as text _n "=============================================="
di as text    "  2. ASYMMETRIC RESPONSES"
di as text    "=============================================="

* Pooled OLS with asymmetric effects
eststo clear
quietly regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo asym_ols

di as text "Positive income shock (beta+): " _b[dlny_pos] " (SE: " _se[dlny_pos] ")"
di as text "Negative income shock (beta-): " _b[dlny_neg] " (SE: " _se[dlny_neg] ")"
di as text "Interaction positive (delta+): " _b[dlny_pos_x_inf] " (SE: " _se[dlny_pos_x_inf] ")"
di as text "Interaction negative (delta-): " _b[dlny_neg_x_inf] " (SE: " _se[dlny_neg_x_inf] ")"

* Test if responses are symmetric: beta+ = |beta-|
test dlny_pos = -dlny_neg
local p_sym = r(p)
di as text _n "Test beta+ = |beta-|: p = " %6.4f `p_sym'

* Test if informal interaction differs for positive vs negative
test dlny_pos_x_inf = -dlny_neg_x_inf
local p_sym_inf = r(p)
di as text "Test delta+ = |delta-|: p = " %6.4f `p_sym_inf'

* Individual FE version
quietly xtreg dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
    age age2 i.married i.educat hh_size n_children i.year, ///
    fe vce(cluster idind)
eststo asym_fe

* Export asymmetric results
esttab asym_ols asym_fe using "$tables/W4b_2_asymmetric.csv", replace ///
    keep(dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4b.2: Asymmetric Responses to Income Changes") ///
    mtitles("Pooled OLS" "Individual FE") ///
    addnotes("dlny_pos = max(dlnY, 0); dlny_neg = min(dlnY, 0)")

*===============================================================================
* 3. SHOCK-BASED SPECIFICATIONS
*===============================================================================

di as text _n "=============================================="
di as text    "  3. SHOCK-BASED SPECIFICATIONS"
di as text    "=============================================="

* Direct effect of shocks on consumption (no endogenous income)
eststo clear

* Health shocks
quietly regress dlnc shock_health informal c.shock_health#c.informal ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo shock_health

di as text "Health shock effect: " _b[shock_health] " (SE: " _se[shock_health] ")"
di as text "Health × Informal: " _b[c.shock_health#c.informal] " (SE: " _se[c.shock_health#c.informal] ")"

* Job shocks
quietly regress dlnc shock_job informal c.shock_job#c.informal ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo shock_job

di as text "Job shock effect: " _b[shock_job] " (SE: " _se[shock_job] ")"
di as text "Job × Informal: " _b[c.shock_job#c.informal] " (SE: " _se[c.shock_job#c.informal] ")"

* Regional shocks
quietly regress dlnc shock_regional informal c.shock_regional#c.informal ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo shock_regional

* All shocks together
quietly regress dlnc shock_health shock_job shock_regional informal ///
    c.shock_health#c.informal c.shock_job#c.informal c.shock_regional#c.informal ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo shock_all

* Export shock-based results
esttab shock_health shock_job shock_regional shock_all using "$tables/W4b_3_shocks.csv", replace ///
    keep(shock_health shock_job shock_regional informal ///
         c.shock_health#c.informal c.shock_job#c.informal c.shock_regional#c.informal) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4b.3: Shock-Based Specifications") ///
    mtitles("Health" "Job" "Regional" "All Shocks")

*===============================================================================
* 4. TRIPLE INTERACTION WITH CREDIT CONSTRAINTS
*===============================================================================

di as text _n "=============================================="
di as text    "  4. TRIPLE INTERACTION: CREDIT CONSTRAINTS"
di as text    "=============================================="

eststo clear

* Baseline with credit constraint interaction
quietly regress dlnc dlny_lab informal credit_constrained ///
    dlny_inf dlny_x_cc ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo cc_double

* Triple interaction
quietly regress dlnc dlny_lab informal credit_constrained ///
    dlny_inf dlny_x_cc dyInfCC ///
    c.informal#c.credit_constrained ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo cc_triple

di as text "Triple interaction (dlnY × Inf × CC): " _b[dyInfCC] " (SE: " _se[dyInfCC] ")"
test dyInfCC
local p_triple = r(p)
di as text "p-value: " %6.4f `p_triple'

* Export credit constraint results
esttab cc_double cc_triple using "$tables/W4b_4_credit_triple.csv", replace ///
    keep(dlny_lab informal credit_constrained dlny_inf dlny_x_cc dyInfCC) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4b.4: Triple Interaction with Credit Constraints") ///
    mtitles("Double Interactions" "Triple Interaction")

*===============================================================================
* 5. QUANTILE REGRESSION
*===============================================================================

di as text _n "=============================================="
di as text    "  5. QUANTILE REGRESSION"
di as text    "=============================================="

* Quantile regressions at 10th, 25th, 50th, 75th, 90th percentiles
eststo clear

foreach q in 10 25 50 75 90 {
    di as text _n "--- Quantile `q' ---"
    quietly qreg dlnc dlny_lab informal dlny_inf ///
        age age2 i.female i.married hh_size i.urban i.year, ///
        quantile(0.`q') vce(robust)
    eststo q`q'

    di as text "Q`q': beta = " _b[dlny_lab] " delta = " _b[dlny_inf]
}

* Export quantile results
esttab q10 q25 q50 q75 q90 using "$tables/W4b_5_quantile.csv", replace ///
    keep(dlny_lab informal dlny_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4b.5: Quantile Regression Results") ///
    mtitles("Q10" "Q25" "Q50" "Q75" "Q90")

*===============================================================================
* 6. WITHIN-PERSON TRANSITIONS (EVENT STUDY)
*===============================================================================

di as text _n "=============================================="
di as text    "  6. EVENT STUDY: FORMAL-TO-INFORMAL TRANSITIONS"
di as text    "=============================================="

* Count transitions
count if switch_to_informal == 1
local n_switch = r(N)
di as text "Number of formal-to-informal transitions: `n_switch'"

* Event study regression
* Restrict to those who switch and have data around the switch
eststo clear

* Create event time dummies (relative to switch year)
* Use -3 to +3 window, with -1 as reference
forvalues k = -3/3 {
    if `k' != -1 {
        gen byte rel_time_`=cond(`k'<0,"m","p")'`=abs(`k')' = (rel_time == `k') if ever_switch_to_inf == 1
    }
}

* Event study regression with individual FE
capture xtreg dlnc rel_time_m3 rel_time_m2 rel_time_p0 rel_time_p1 rel_time_p2 rel_time_p3 ///
    age age2 i.married hh_size i.year if ever_switch_to_inf == 1, ///
    fe vce(cluster idind)

if _rc == 0 {
    eststo event_study

    * Collect coefficients for plotting
    matrix E = J(7, 3, .)
    local row = 1
    foreach k in -3 -2 -1 0 1 2 3 {
        matrix E[`row', 1] = `k'
        if `k' == -1 {
            matrix E[`row', 2] = 0
            matrix E[`row', 3] = 0
        }
        else {
            local vname = "rel_time_`=cond(`k'<0,"m","p")'`=abs(`k')'"
            matrix E[`row', 2] = _b[`vname']
            matrix E[`row', 3] = _se[`vname']
        }
        local ++row
    }

    * Save event study coefficients
    preserve
        clear
        svmat E
        rename E1 rel_time
        rename E2 coef
        rename E3 se
        gen ci_lo = coef - 1.96 * se
        gen ci_hi = coef + 1.96 * se
        export delimited using "$tables/W4b_6_event_study.csv", replace
    restore

    di as text "Event study coefficients (relative to t=-1):"
    matrix list E
}
else {
    di as error "Event study regression failed - insufficient transitions"
}

* Clean up event time dummies
capture drop rel_time_m* rel_time_p*

*===============================================================================
* 7. CORRELATED RANDOM EFFECTS / MUNDLAK SPECIFICATION
*===============================================================================

di as text _n "=============================================="
di as text    "  7. MUNDLAK SPECIFICATION"
di as text    "=============================================="

eststo clear

* Standard RE for comparison
quietly xtreg dlnc dlny_lab informal dlny_inf ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    re vce(cluster idind)
eststo re_standard

* Mundlak specification (add individual means)
quietly xtreg dlnc dlny_lab informal dlny_inf ///
    dlny_lab_mean informal_mean age_mean hh_size_mean ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    re vce(cluster idind)
eststo re_mundlak

* Test significance of Mundlak terms (test for selection)
test dlny_lab_mean informal_mean age_mean hh_size_mean
local p_mundlak = r(p)
di as text "Joint test of Mundlak terms: p = " %6.4f `p_mundlak'
di as text "  (Significant = evidence of selection)"

* Fixed effects for comparison
quietly xtreg dlnc dlny_lab informal dlny_inf ///
    age age2 i.married i.educat hh_size n_children i.year, ///
    fe vce(cluster idind)
eststo fe_compare

* Hausman-like test: compare RE-Mundlak to FE
di as text _n "Mundlak RE coefficient on dlny_inf: " _b[dlny_inf]
estimates restore fe_compare
di as text "FE coefficient on dlny_inf: " _b[dlny_inf]

* Export Mundlak results
esttab re_standard re_mundlak fe_compare using "$tables/W4b_7_mundlak.csv", replace ///
    keep(dlny_lab informal dlny_inf dlny_lab_mean informal_mean) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4b.7: Mundlak Specification") ///
    mtitles("Standard RE" "Mundlak RE" "FE")

*===============================================================================
* 8. SEPARATE REGRESSIONS BY CONSUMPTION COMPONENT
*===============================================================================

di as text _n "=============================================="
di as text    "  8. BY CONSUMPTION COMPONENT"
di as text    "=============================================="

eststo clear

* Food consumption
quietly regress dlnfood dlny_lab informal dlny_inf ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo comp_food

di as text "Food: beta = " _b[dlny_lab] " delta = " _b[dlny_inf]

* Non-durable consumption (already done, but for comparison)
quietly regress dlnc dlny_lab informal dlny_inf ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo comp_nondur

* Durable-inclusive consumption
quietly regress dlncD dlny_lab informal dlny_inf ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo comp_durable

di as text "Durables: beta = " _b[dlny_lab] " delta = " _b[dlny_inf]

* Export by-component results
esttab comp_food comp_nondur comp_durable using "$tables/W4b_8_components.csv", replace ///
    keep(dlny_lab informal dlny_inf) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4b.8: Consumption Smoothing by Component") ///
    mtitles("Food" "Non-durables" "Durable-incl.")

*===============================================================================
* 9. AGGREGATE SHOCK INTERACTIONS (CRISIS PERIODS)
*===============================================================================

di as text _n "=============================================="
di as text    "  9. CRISIS PERIOD INTERACTIONS"
di as text    "=============================================="

eststo clear

* Baseline with crisis dummy
quietly regress dlnc dlny_lab informal dlny_inf ///
    any_crisis ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo crisis_base

* Double interaction: income × crisis
quietly regress dlnc dlny_lab informal dlny_inf ///
    any_crisis dlny_x_crisis ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo crisis_double

di as text "Income × Crisis: " _b[dlny_x_crisis] " (SE: " _se[dlny_x_crisis] ")"

* Triple interaction: income × informal × crisis
quietly regress dlnc dlny_lab informal dlny_inf ///
    any_crisis dlny_x_crisis c.informal#c.any_crisis dyInfCrisis ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo crisis_triple

di as text "Income × Informal × Crisis: " _b[dyInfCrisis] " (SE: " _se[dyInfCrisis] ")"

* Test if informality cost increases during crisis
test dyInfCrisis
local p_crisis = r(p)
di as text "Test: informality cost increases during crisis: p = " %6.4f `p_crisis'

* Separate by crisis type
quietly regress dlnc dlny_lab informal dlny_inf ///
    crisis_2008 crisis_2014 crisis_2020 ///
    c.dlny_lab#c.crisis_2008 c.dlny_lab#c.crisis_2014 c.dlny_lab#c.crisis_2020 ///
    c.dlny_inf#c.crisis_2008 c.dlny_inf#c.crisis_2014 c.dlny_inf#c.crisis_2020 ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year, ///
    vce(cluster idind)
eststo crisis_sep

di as text _n "Informal interaction by crisis:"
di as text "  2008-09: " _b[c.dlny_inf#c.crisis_2008]
di as text "  2014-15: " _b[c.dlny_inf#c.crisis_2014]
di as text "  2020:    " _b[c.dlny_inf#c.crisis_2020]

* Export crisis results
esttab crisis_base crisis_double crisis_triple using "$tables/W4b_9_crisis.csv", replace ///
    keep(dlny_lab informal dlny_inf any_crisis dlny_x_crisis dyInfCrisis) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Table W4b.9: Crisis Period Interactions") ///
    mtitles("Baseline" "Double" "Triple")

*===============================================================================
* SUMMARY OF KEY FINDINGS
*===============================================================================

di as text _n "=============================================="
di as text    "  SUMMARY OF EXTENDED ROBUSTNESS CHECKS"
di as text    "=============================================="

di as text _n "1. IV Estimates:"
di as text "   Health shock IV likely weak (check F-stat)"
di as text "   IV estimates typically larger if measurement error present"

di as text _n "2. Asymmetric Responses:"
di as text "   Compare beta+ vs |beta-| and delta+ vs |delta-|"
di as text "   If delta- significant but delta+ not: downside risk matters"

di as text _n "3. Shock-Based:"
di as text "   Direct effect of shocks on consumption (no endogenous income)"

di as text _n "4. Credit Triple Interaction:"
di as text "   If delta3 significant: credit matters for informal workers specifically"

di as text _n "5. Quantile Regression:"
di as text "   Check if effects differ at tails of consumption distribution"

di as text _n "6. Event Study:"
di as text "   Causal effect of formal->informal transition on consumption volatility"

di as text _n "7. Mundlak:"
di as text "   Tests selection: are Mundlak terms jointly significant?"

di as text _n "8. By Component:"
di as text "   Food smoothed better than non-durables/durables?"

di as text _n "9. Crisis Interactions:"
di as text "   Does informality cost spike during crises?"

*===============================================================================

di as text _n "=============================================="
di as text    "  Step W4b complete."
di as text    "  Output files in: $tables/W4b_*.csv"
di as text    "=============================================="

log close
