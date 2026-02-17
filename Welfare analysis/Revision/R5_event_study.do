*===============================================================================
* R5: Staggered Event Study (Callaway & Sant'Anna 2021)
*===============================================================================
*
* Problem: Standard event study designs can be biased when treatment timing
* varies and treatment effects are heterogeneous across cohorts.
*
* Solution: Use Callaway & Sant'Anna (2021) doubly-robust difference-in-differences
* estimator with clean comparisons (never-treated or not-yet-treated as controls).
*
* Event: Large negative income shock (≥20% drop in labor income)
* Outcome: Consumption response in formal vs informal workers
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
log using "${logdir}/R5_event_study.log", replace text

di as text _n "=============================================="
di as text    "  R5: Staggered Event Study"
di as text    "      (Callaway & Sant'Anna 2021)"
di as text    "=============================================="

*===============================================================================
* 0. SETUP AND DATA
*===============================================================================

* Check for required package
capture which csdid
if _rc {
    di as error "Package 'csdid' not found. Installing..."
    ssc install csdid, replace
    ssc install drdid, replace
}

* Load data
capture use "$data/welfare_panel_cbr.dta", clear
if _rc != 0 {
    use "$data/welfare_panel_shocks.dta", clear
}

keep if analysis_sample == 1
xtset idind year

* Controls
global X_controls "age age2 female married hh_size"

*===============================================================================
* 1. DEFINE THE EVENT: LARGE NEGATIVE INCOME SHOCK
*===============================================================================

di as text _n "=============================================="
di as text    "  1. Define Treatment Event"
di as text    "=============================================="

* Large negative shock: ≥20% drop in labor income
gen byte large_neg_shock = (dlny_lab <= -0.20 & !missing(dlny_lab))
label variable large_neg_shock "Large negative shock (≥20% drop)"

* First large shock year for each individual
bysort idind (year): gen first_shock_year = year if large_neg_shock == 1
bysort idind: egen treatment_year = min(first_shock_year)
drop first_shock_year
label variable treatment_year "Year of first large negative shock"

* Treatment cohort (for csdid)
* Never-treated individuals have treatment_year = .
gen gvar = treatment_year
replace gvar = 0 if missing(treatment_year)  // csdid convention: 0 = never treated
label variable gvar "Treatment cohort (0 = never treated)"

* Summary
tab treatment_year if !missing(treatment_year), missing
count if gvar == 0
local N_never = r(N)
count if gvar > 0
local N_treated = r(N)
di as text _n "Sample composition:"
di as text "  Ever treated (large shock): `N_treated'"
di as text "  Never treated:              `N_never'"

*===============================================================================
* 2. EVENT STUDY: FULL SAMPLE
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Event Study - Full Sample"
di as text    "=============================================="

* Consumption level as outcome (for CSDID we typically use levels)
gen consumption = exp(lnc)
label variable consumption "Consumption level"

* Callaway & Sant'Anna estimator
csdid consumption $X_controls, ivar(idind) time(year) gvar(gvar) ///
    agg(event) wboot reps(999)

est store csdid_full

* Store event-time coefficients
matrix ES_full = e(b)
matrix V_full = e(V)

* Event study plot
csdid_plot, title("Event Study: Consumption Response to Large Shock") ///
    xtitle("Years Relative to Shock") ytitle("ATT") ///
    style(rcap)

graph export "${figures}/R5_event_study_full.png", replace width(1200)
graph save "${figures}/R5_event_study_full.gph", replace

*===============================================================================
* 3. EVENT STUDY BY INFORMALITY STATUS
*===============================================================================

di as text _n "=============================================="
di as text    "  3. Event Study by Informality Status"
di as text    "=============================================="

* Get pre-shock informality status
bysort idind (year): gen pre_shock_informal = informal[_n-1] if year == treatment_year
bysort idind: egen informal_at_shock = max(pre_shock_informal)
label variable informal_at_shock "Informal at time of shock"

* Formal workers only
di as text _n "--- Formal Workers ---"
preserve
    keep if informal_at_shock == 0 | gvar == 0

    csdid consumption $X_controls, ivar(idind) time(year) gvar(gvar) ///
        agg(event) wboot reps(499)

    est store csdid_formal

    csdid_plot, title("Formal Workers: Consumption Response") ///
        xtitle("Years Relative to Shock") ytitle("ATT") ///
        style(rcap)

    graph export "${figures}/R5_event_study_formal.png", replace width(1200)
restore

* Informal workers only
di as text _n "--- Informal Workers ---"
preserve
    keep if informal_at_shock == 1 | gvar == 0

    csdid consumption $X_controls, ivar(idind) time(year) gvar(gvar) ///
        agg(event) wboot reps(499)

    est store csdid_informal

    csdid_plot, title("Informal Workers: Consumption Response") ///
        xtitle("Years Relative to Shock") ytitle("ATT") ///
        style(rcap)

    graph export "${figures}/R5_event_study_informal.png", replace width(1200)
restore

*===============================================================================
* 4. TRADITIONAL EVENT STUDY (FOR COMPARISON)
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Traditional Event Study (Comparison)"
di as text    "=============================================="

* Create event-time dummies
gen event_time = year - treatment_year if !missing(treatment_year)
label variable event_time "Event time (years from shock)"

* Create indicators for event time (window: -5 to +5)
forvalues t = -5/5 {
    if `t' < 0 {
        local tlab = abs(`t')
        gen byte e_m`tlab' = (event_time == `t')
    }
    else if `t' == 0 {
        gen byte e_0 = (event_time == 0)
    }
    else {
        gen byte e_p`t' = (event_time == `t')
    }
}

* Omit t = -1 as reference
drop e_m1

* Traditional event study regression (with individual FE)
reghdfe dlnc e_m5 e_m4 e_m3 e_m2 e_0 e_p1 e_p2 e_p3 e_p4 e_p5 ///
    $X_controls i.year, absorb(idind) vce(cluster idind)

est store trad_event_study

* Store coefficients for plotting
matrix TRAD_ES = J(10, 3, .)  // 10 periods, 3 columns (coef, se, t)
local row = 0
foreach var in e_m5 e_m4 e_m3 e_m2 e_0 e_p1 e_p2 e_p3 e_p4 e_p5 {
    local ++row
    matrix TRAD_ES[`row', 1] = _b[`var']
    matrix TRAD_ES[`row', 2] = _se[`var']
    matrix TRAD_ES[`row', 3] = _b[`var'] / _se[`var']
}

* Event study plot (traditional)
coefplot, keep(e_m5 e_m4 e_m3 e_m2 e_0 e_p1 e_p2 e_p3 e_p4 e_p5) ///
    vertical ///
    yline(0, lcolor(black) lpattern(dash)) ///
    xline(4.5, lcolor(red) lpattern(dash)) ///
    xtitle("Years Relative to Shock") ytitle("Effect on Δln(C)") ///
    title("Traditional Event Study") ///
    coeflabels(e_m5 = "-5" e_m4 = "-4" e_m3 = "-3" e_m2 = "-2" ///
               e_0 = "0" e_p1 = "+1" e_p2 = "+2" e_p3 = "+3" e_p4 = "+4" e_p5 = "+5") ///
    note("Reference period: t = -1. Red line indicates shock timing.")

graph export "${figures}/R5_event_study_traditional.png", replace width(1200)

*===============================================================================
* 5. TRIPLE-DIFFERENCE: INFORMAL × EVENT × POST
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Triple Difference Design"
di as text    "=============================================="

* Post-shock indicator
gen byte post_shock = (event_time >= 0) if !missing(event_time)
label variable post_shock "Post-shock period"

* Informal at shock × Post interaction
gen informal_post = informal_at_shock * post_shock
label variable informal_post "Informal × Post"

* Event indicator (any shock)
gen byte treated = (gvar > 0)

* Triple difference
reghdfe dlnc c.treated##c.informal_at_shock##c.post_shock ///
    $X_controls, absorb(idind year) vce(cluster idind)

est store triple_diff

* Key coefficient: treated × informal × post
local triple_coef = _b[c.treated#c.informal_at_shock#c.post_shock]
local triple_se = _se[c.treated#c.informal_at_shock#c.post_shock]
local triple_t = `triple_coef' / `triple_se'
local triple_p = 2 * (1 - normal(abs(`triple_t')))

di as text _n "Triple Difference Estimate:"
di as text "  Treated × Informal × Post = " %7.4f `triple_coef'
di as text "  SE = " %7.4f `triple_se'
di as text "  t = " %5.2f `triple_t' ", p = " %5.3f `triple_p'

*===============================================================================
* 6. HETEROGENEOUS TREATMENT EFFECTS BY COHORT
*===============================================================================

di as text _n "=============================================="
di as text    "  6. Heterogeneous Effects by Cohort"
di as text    "=============================================="

* Group-time ATT (cohort-specific)
csdid consumption $X_controls, ivar(idind) time(year) gvar(gvar) ///
    agg(group) wboot reps(499)

est store csdid_group

* Cohort plot
csdid_plot, group ///
    title("Treatment Effects by Cohort") ///
    xtitle("Treatment Cohort") ytitle("Group ATT")

graph export "${figures}/R5_event_study_cohorts.png", replace width(1200)

*===============================================================================
* 7. COMPARISON: CSDID vs TRADITIONAL
*===============================================================================

di as text _n "=============================================="
di as text    "  7. CSDID vs Traditional Comparison"
di as text    "=============================================="

* For period 0 (impact effect), compare estimates
* Extract from CSDID
capture quietly csdid consumption $X_controls, ivar(idind) time(year) gvar(gvar) agg(event)
matrix CSDID_b = e(b)
local csdid_t0 = CSDID_b[1, 1]  // First element is typically t=0

* From traditional
local trad_t0 = _b[e_0] if _b[e_0] != .

di as text "Impact Effect (t = 0) Comparison:"
di as text "  CSDID estimate:       (see event study plot)"
di as text "  Traditional estimate: " %7.4f `trad_t0'

*===============================================================================
* 8. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  8. Export Results"
di as text    "=============================================="

* Export regression table
esttab csdid_full trad_event_study triple_diff ///
    using "${tables}/R5_event_study.tex", replace ///
    mtitles("CSDID" "Traditional" "Triple-Diff") ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Event Study: Large Negative Income Shocks") ///
    label booktabs

* Export summary statistics
preserve
    clear
    set obs 3
    gen model = ""
    gen estimate = .
    gen se = .
    gen p_value = .

    replace model = "CSDID (full)" in 1

    replace model = "Traditional (t=0)" in 2
    replace estimate = `trad_t0' in 2

    replace model = "Triple-Diff" in 3
    replace estimate = `triple_coef' in 3
    replace se = `triple_se' in 3
    replace p_value = `triple_p' in 3

    export delimited using "${tables}/R5_event_study_summary.csv", replace
restore

*===============================================================================
* 9. SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  R5 SUMMARY: Event Study"
di as text    "=============================================="

di as text _n "METHODOLOGY:"
di as text "  Event: Large negative income shock (≥20% drop)"
di as text "  Method: Callaway & Sant'Anna (2021) CSDID"
di as text "  - Robust to heterogeneous treatment effects across cohorts"
di as text "  - Uses never-treated/not-yet-treated as clean controls"
di as text "  - Wild cluster bootstrap for inference"

di as text _n "SAMPLE:"
di as text "  Ever treated: `N_treated' obs"
di as text "  Never treated (controls): `N_never' obs"

di as text _n "KEY FINDINGS:"
di as text "  1. Pre-trends: Check figures for parallel pre-trends"
di as text "  2. Triple-diff (Treated × Informal × Post):"
di as text "     Coefficient: " %7.4f `triple_coef' " (p = " %5.3f `triple_p' ")"

if `triple_p' < 0.05 {
    di as text _n "  INTERPRETATION:"
    di as text "  *** Informal workers have significantly different response to ***"
    di as text "  *** negative shocks compared to formal workers ***"
}
else {
    di as text _n "  INTERPRETATION:"
    di as text "  No significant difference in shock response by informality"
    di as text "  (in the event study framework)"
}

log close

di as text _n "Log saved to: ${logdir}/R5_event_study.log"
di as text "Figures saved to: ${figures}/R5_event_study_*.png"
di as text "Tables saved to: ${tables}/R5_event_study.tex"

*===============================================================================
* END
*===============================================================================
