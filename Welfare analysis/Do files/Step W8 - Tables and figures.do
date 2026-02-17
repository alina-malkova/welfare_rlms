/*==============================================================================
  Step W8 - Tables and figures

  Project:  Welfare Cost of Labor Informality
  Purpose:  Generate publication-quality tables and figures for the paper
  Input:    Welfare analysis/Data/welfare_panel_shocks.dta
            Welfare analysis/Data/welfare_costs_by_year.dta
  Output:   Welfare analysis/Results/Tables/W8_*.csv
            Welfare analysis/Results/Figures/W8_*.png

  Tables:
    1. Summary statistics by formality status (with t-tests)
    2. Consumption smoothing coefficients (OLS, FE, IV, switchers, durable)
    3. Credit mechanism tests
    4. Welfare cost estimates under different gamma
    5. Heterogeneity analysis

  Figures:
    1. Event study: consumption around income shocks by sector
    2. Credit access by formality over time
    3. Welfare cost vs risk aversion gamma (line plot)
    4. Consumption variance over time (from welfare_costs_by_year.dta)
    5. Informality rate over time

  Author:
  Created:  February 2026
==============================================================================*/

clear all
capture set maxvar 32767
do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close
log using "$logdir/Step_W8_output.log", replace

set scheme s2color

*===============================================================================
* TABLE 1: SUMMARY STATISTICS BY FORMALITY STATUS
*===============================================================================

di as text _n "=============================================="
di as text    "  TABLE 1: SUMMARY STATISTICS"
di as text    "=============================================="

use "$data/welfare_panel_shocks.dta", clear
keep if analysis_sample == 1
xtset idind year

* --- Define variable lists for each panel ---
* Panel A: Demographics
local demovars "age female married educat hh_size n_children urban"

* Panel B: Income and consumption (levels)
local incvars "labor_inc_eq disp_inc_eq cons_nondur_eq cons_dur_eq"

* Panel C: Income and consumption growth
local growthvars "dlny_lab dlny_dis dlnc dlncD dlnfood"

* Panel D: Shocks
local shockvars "shock_health shock_job shock_regional shock_any"

* Panel E: Credit and savings
local creditvars "has_formal_credit has_informal_credit credit_constrained buffer_low"

* --- Display and build matrix ---
local allvars "`demovars' `incvars' `growthvars' `shockvars' `creditvars'"

* Count available variables
local nvars_avail = 0
foreach v of local allvars {
    capture confirm variable `v'
    if _rc == 0 {
        local ++nvars_avail
    }
}

tempname T1
matrix `T1' = J(`nvars_avail', 7, .)
matrix colnames `T1' = "mean_F" "sd_F" "mean_I" "sd_I" "diff" "tstat" "pval"

local row = 0
local varnames ""
foreach v of local allvars {
    capture confirm variable `v'
    if _rc == 0 {
        local ++row
        local varnames "`varnames' `v'"

        quietly summarize `v' if informal == 0
        matrix `T1'[`row', 1] = r(mean)
        matrix `T1'[`row', 2] = r(sd)
        local n_f = r(N)

        quietly summarize `v' if informal == 1
        matrix `T1'[`row', 3] = r(mean)
        matrix `T1'[`row', 4] = r(sd)
        local n_i = r(N)

        quietly ttest `v', by(informal)
        matrix `T1'[`row', 5] = r(mu_1) - r(mu_2)
        matrix `T1'[`row', 6] = r(t)
        matrix `T1'[`row', 7] = r(p)

        local sec_f = "F"
        local sec_i = "I"
        local stars ""
        if r(p) < 0.01      local stars "***"
        else if r(p) < 0.05 local stars "**"
        else if r(p) < 0.10 local stars "*"

        di as text "`v': " ///
            "Formal = " %9.3f `T1'[`row', 1] ///
            "  Informal = " %9.3f `T1'[`row', 3] ///
            "  Diff = " %9.3f `T1'[`row', 5] ///
            "  t = " %6.2f `T1'[`row', 6] " `stars'"
    }
}

matrix list `T1', format(%9.4f) title("Table 1: Summary Statistics")

* --- Export to CSV ---
preserve
    clear
    svmat `T1'
    gen variable = ""
    local row = 0
    foreach v of local varnames {
        local ++row
        replace variable = "`v'" in `row'
    }
    rename `T1'1 mean_formal
    rename `T1'2 sd_formal
    rename `T1'3 mean_informal
    rename `T1'4 sd_informal
    rename `T1'5 difference
    rename `T1'6 t_statistic
    rename `T1'7 p_value
    order variable
    export delimited using "$tables/W8_Table1_summary.csv", replace
restore

di as text "  N (Formal):   " `n_f'
di as text "  N (Informal): " `n_i'

*===============================================================================
* TABLE 2: CONSUMPTION SMOOTHING COEFFICIENTS
*===============================================================================

di as text _n "=============================================="
di as text    "  TABLE 2: CONSUMPTION SMOOTHING"
di as text    "=============================================="

* Create interaction term
gen double dlny_x_inf = dlny_lab * informal
label variable dlny_x_inf "dlnY x Informal"

* --- Column (1): Pooled OLS ---
eststo clear

eststo t2_1: regress dlnc dlny_lab informal dlny_x_inf ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.region i.year, ///
    vce(cluster idind)

* --- Column (2): Individual FE ---
eststo t2_2: xtreg dlnc dlny_lab informal dlny_x_inf ///
    age age2 i.married hh_size n_children i.year, fe vce(cluster idind)

* --- Column (3): IV with health shocks ---
gen double shock_health_x_inf = shock_health * informal
label variable shock_health_x_inf "Health shock x Informal"

eststo t2_3: ivregress 2sls dlnc informal ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.year ///
    (dlny_lab dlny_x_inf = shock_health shock_health_x_inf), ///
    vce(cluster idind)

* --- Column (4): Switchers only (FE) ---
bysort idind: egen byte ever_f = max(informal == 0)
bysort idind: egen byte ever_i = max(informal == 1)
gen byte switcher = (ever_f == 1 & ever_i == 1)

eststo t2_4: xtreg dlnc dlny_lab informal dlny_x_inf ///
    age age2 i.married hh_size n_children i.year if switcher == 1, ///
    fe vce(cluster idind)

* --- Column (5): Durable-inclusive consumption ---
eststo t2_5: regress dlncD dlny_lab informal dlny_x_inf ///
    age age2 i.female i.married i.educat hh_size n_children i.urban i.region i.year, ///
    vce(cluster idind)

* Display and export
esttab t2_1 t2_2 t2_3 t2_4 t2_5, ///
    keep(dlny_lab informal dlny_x_inf) ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%9.0g %9.4f) labels("Observations" "R-squared")) ///
    title("Table 2: Consumption Smoothing Coefficients") ///
    mtitles("OLS" "FE" "IV" "Switchers FE" "Dur. OLS") ///
    addnote("Dependent variable: dlnC per equivalent adult." ///
            "Key: beta = dlnY, delta = dlnY x Informal." ///
            "delta > 0 indicates worse consumption smoothing for informal." ///
            "Clustered SE at individual level.")

esttab t2_1 t2_2 t2_3 t2_4 t2_5 using "$tables/W8_Table2_smoothing.csv", replace ///
    keep(dlny_lab informal dlny_x_inf) ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%9.0g %9.4f))

*===============================================================================
* TABLE 3: CREDIT MECHANISM TESTS
*===============================================================================

di as text _n "=============================================="
di as text    "  TABLE 3: CREDIT MECHANISM"
di as text    "=============================================="

gen double shock_any_x_inf = shock_any * informal
label variable shock_any_x_inf "Any shock x Informal"

eststo clear

* (1) Informal -> more credit constrained
capture confirm variable credit_constrained
if _rc == 0 {
    eststo t3_1: regress credit_constrained informal ///
        age age2 i.female i.married i.educat hh_size n_children i.urban i.region i.year, ///
        vce(cluster idind)
}

* (2) Informal borrow less after shocks (formal credit)
capture confirm variable has_formal_credit
if _rc == 0 {
    eststo t3_2: regress has_formal_credit shock_any informal shock_any_x_inf ///
        age age2 i.female i.married i.educat hh_size n_children i.urban i.region i.year, ///
        vce(cluster idind)
}

* (3) Informal rely more on private debt
capture confirm variable has_informal_credit
if _rc == 0 {
    eststo t3_3: regress has_informal_credit shock_any informal shock_any_x_inf ///
        age age2 i.female i.married i.educat hh_size n_children i.urban i.region i.year, ///
        vce(cluster idind)
}

* (4) Buffer stock indicator
capture confirm variable buffer_low
if _rc == 0 {
    eststo t3_4: regress buffer_low informal ///
        age age2 i.female i.married i.educat hh_size n_children i.urban i.region i.year, ///
        vce(cluster idind)
}

esttab t3_*, ///
    keep(informal shock_any shock_any_x_inf) ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%9.0g %9.4f)) ///
    title("Table 3: Credit Mechanism Tests") ///
    addnote("Col 1: credit constrained on informal." ///
            "Col 2: formal credit on shock x informal." ///
            "Col 3: informal credit on shock x informal." ///
            "Col 4: low buffer stock on informal.")

esttab t3_* using "$tables/W8_Table3_credit.csv", replace ///
    keep(informal shock_any shock_any_x_inf) ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%9.0g %9.4f))

*===============================================================================
* TABLE 4: WELFARE COST ESTIMATES
*===============================================================================

di as text _n "=============================================="
di as text    "  TABLE 4: WELFARE COSTS"
di as text    "=============================================="

* Compute residual consumption variance by sector
quietly regress dlnc age age2 i.female i.married i.educat ///
    hh_size n_children i.urban i.year
predict double resid_dlnc, residuals

quietly summarize resid_dlnc if informal == 0
local rvar_f = r(Var)
quietly summarize resid_dlnc if informal == 1
local rvar_i = r(Var)

* Mean consumption for ruble amounts
quietly summarize cons_nondur_eq if informal == 0
local mean_c_f = r(mean)
quietly summarize cons_nondur_eq if informal == 1
local mean_c_i = r(mean)

* Build table: one row per gamma value
tempname T4
matrix `T4' = J(4, 8, .)
matrix colnames `T4' = "gamma" "VarC_F" "VarC_I" "W_F_pct" "W_I_pct" "W_gap_pct" "CV_pct" "CV_rub"

local row = 0
foreach gamma of numlist 1 2 3 5 {
    local ++row
    local W_f = 0.5 * `gamma' * `rvar_f'
    local W_i = 0.5 * `gamma' * `rvar_i'
    local cv  = 1 - exp(-0.5 * `gamma' * (`rvar_i' - `rvar_f'))

    matrix `T4'[`row', 1] = `gamma'
    matrix `T4'[`row', 2] = `rvar_f'
    matrix `T4'[`row', 3] = `rvar_i'
    matrix `T4'[`row', 4] = `W_f' * 100
    matrix `T4'[`row', 5] = `W_i' * 100
    matrix `T4'[`row', 6] = (`W_i' - `W_f') * 100
    matrix `T4'[`row', 7] = `cv' * 100
    matrix `T4'[`row', 8] = `cv' * `mean_c_i'

    di as text "gamma = `gamma':  W_F = " %6.3f `W_f'*100 "%  W_I = " %6.3f `W_i'*100 ///
        "%  Gap = " %6.3f (`W_i'-`W_f')*100 "%  CV = " %6.3f `cv'*100 ///
        "%  CV = " %8.0f `cv'*`mean_c_i' " rub/month"
}

matrix list `T4', format(%9.4f) title("Table 4: CRRA Welfare Costs")

preserve
    clear
    svmat `T4'
    rename `T4'1 gamma
    rename `T4'2 VarC_formal
    rename `T4'3 VarC_informal
    rename `T4'4 W_formal_pct
    rename `T4'5 W_informal_pct
    rename `T4'6 W_gap_pct
    rename `T4'7 CV_pct
    rename `T4'8 CV_rubles
    export delimited using "$tables/W8_Table4_welfare.csv", replace
restore

*===============================================================================
* TABLE 5: HETEROGENEITY
*===============================================================================

di as text _n "=============================================="
di as text    "  TABLE 5: HETEROGENEITY"
di as text    "=============================================="

eststo clear

* (1) Male
eststo h_male: regress dlnc dlny_lab informal dlny_x_inf ///
    age age2 i.married i.educat hh_size n_children i.urban i.region i.year ///
    if female == 0, vce(cluster idind)

* (2) Female
eststo h_female: regress dlnc dlny_lab informal dlny_x_inf ///
    age age2 i.married i.educat hh_size n_children i.urban i.region i.year ///
    if female == 1, vce(cluster idind)

* (3) Low education (educat <= 2)
eststo h_lowedu: regress dlnc dlny_lab informal dlny_x_inf ///
    age age2 i.female i.married hh_size n_children i.urban i.region i.year ///
    if educat <= 2, vce(cluster idind)

* (4) High education (educat == 3)
eststo h_highedu: regress dlnc dlny_lab informal dlny_x_inf ///
    age age2 i.female i.married hh_size n_children i.urban i.region i.year ///
    if educat == 3, vce(cluster idind)

* (5) Urban
eststo h_urban: regress dlnc dlny_lab informal dlny_x_inf ///
    age age2 i.female i.married i.educat hh_size n_children i.region i.year ///
    if urban == 1, vce(cluster idind)

* (6) Rural
eststo h_rural: regress dlnc dlny_lab informal dlny_x_inf ///
    age age2 i.female i.married i.educat hh_size n_children i.region i.year ///
    if urban == 0, vce(cluster idind)

esttab h_male h_female h_lowedu h_highedu h_urban h_rural, ///
    keep(dlny_lab informal dlny_x_inf) ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%9.0g %9.4f)) ///
    title("Table 5: Heterogeneity") ///
    mtitles("Male" "Female" "Low edu" "High edu" "Urban" "Rural") ///
    addnote("Dependent variable: dlnC per equivalent adult." ///
            "All specifications include age, year FE, and demographic controls.")

esttab h_male h_female h_lowedu h_highedu h_urban h_rural ///
    using "$tables/W8_Table5_heterogeneity.csv", replace ///
    keep(dlny_lab informal dlny_x_inf) ///
    b(4) se(4) star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N r2, fmt(%9.0g %9.4f))

*===============================================================================
* FIGURE 1: CONSUMPTION RESPONSE -- EVENT STUDY
*===============================================================================

di as text _n "=============================================="
di as text    "  FIGURE 1: CONSUMPTION EVENT STUDY"
di as text    "=============================================="

* Event: large income drop (dlny_lab < -0.30)
* Track consumption growth in years around the shock

preserve

    * Define event: first large income drop for each individual
    gen byte event = (dlny_lab < -0.30 & dlny_lab < .)
    bysort idind (year): gen byte first_event = (event == 1 & event[_n-1] != 1)

    * Identify event year for each individual
    gen int event_year = year if first_event == 1
    bysort idind: egen int eyear = min(event_year)

    * Relative time to event
    gen int rel_time = year - eyear if eyear < .

    * Keep window [-3, +3]
    keep if rel_time >= -3 & rel_time <= 3 & rel_time < .

    * Collapse: mean consumption growth by relative time and sector
    collapse (mean) mean_dlnc = dlnc (semean) se_dlnc = dlnc ///
        (count) n = dlnc, by(rel_time informal)

    * 95% confidence intervals
    gen double ci_lo = mean_dlnc - 1.96 * se_dlnc
    gen double ci_hi = mean_dlnc + 1.96 * se_dlnc

    * Plot
    twoway (connected mean_dlnc rel_time if informal == 0, ///
                lcolor(navy) mcolor(navy) msymbol(circle) lwidth(medthick)) ///
           (rcap ci_lo ci_hi rel_time if informal == 0, ///
                lcolor(navy%50)) ///
           (connected mean_dlnc rel_time if informal == 1, ///
                lcolor(cranberry) mcolor(cranberry) msymbol(diamond) lwidth(medthick)) ///
           (rcap ci_lo ci_hi rel_time if informal == 1, ///
                lcolor(cranberry%50)), ///
        xline(0, lcolor(gs10) lpattern(dash)) ///
        yline(0, lcolor(gs10) lpattern(dot)) ///
        xtitle("Years relative to income shock") ///
        ytitle("Mean {&Delta}ln(consumption)") ///
        title("Consumption response to income shocks") ///
        subtitle("Event: {&Delta}ln(Y) < -0.30") ///
        legend(order(1 "Formal" 3 "Informal") rows(1) position(6)) ///
        graphregion(color(white)) plotregion(margin(small))

    graph export "$figures/W8_Fig1_event_study.png", replace width(1200)

restore

*===============================================================================
* FIGURE 2: CREDIT ACCESS BY FORMALITY STATUS OVER TIME
*===============================================================================

di as text _n "=============================================="
di as text    "  FIGURE 2: CREDIT ACCESS"
di as text    "=============================================="

preserve

    capture confirm variable has_formal_credit
    if _rc == 0 {
        * Collapse credit variables by year and sector
        collapse (mean) formal_credit = has_formal_credit ///
                 (mean) informal_credit = has_informal_credit ///
                 (mean) constrained = credit_constrained ///
                 (mean) buffer = buffer_low, ///
            by(year informal)

        * Panel A: Formal credit access over time
        twoway (connected formal_credit year if informal == 0, ///
                    lcolor(navy) mcolor(navy) msymbol(circle) lwidth(medthick)) ///
               (connected formal_credit year if informal == 1, ///
                    lcolor(cranberry) mcolor(cranberry) msymbol(diamond) lwidth(medthick)), ///
            xtitle("Year") ///
            ytitle("Share with formal credit") ///
            title("Formal credit access by sector") ///
            legend(order(1 "Formal workers" 2 "Informal workers") ///
                rows(1) position(6)) ///
            graphregion(color(white)) plotregion(margin(small))

        graph export "$figures/W8_Fig2a_formal_credit.png", replace width(1200)

        * Panel B: Credit constrained share
        twoway (connected constrained year if informal == 0, ///
                    lcolor(navy) mcolor(navy) msymbol(circle) lwidth(medthick)) ///
               (connected constrained year if informal == 1, ///
                    lcolor(cranberry) mcolor(cranberry) msymbol(diamond) lwidth(medthick)), ///
            xtitle("Year") ///
            ytitle("Share credit constrained") ///
            title("Credit constraints by formality status") ///
            legend(order(1 "Formal workers" 2 "Informal workers") ///
                rows(1) position(6)) ///
            graphregion(color(white)) plotregion(margin(small))

        graph export "$figures/W8_Fig2b_constrained.png", replace width(1200)
    }
    else {
        di as text "  Credit variables not available -- skipping Figure 2."
    }

restore

*===============================================================================
* FIGURE 3: WELFARE COST AS FUNCTION OF RISK AVERSION
*===============================================================================

di as text _n "=============================================="
di as text    "  FIGURE 3: WELFARE COST vs RISK AVERSION"
di as text    "=============================================="

preserve

    clear
    set obs 50
    gen double gamma = _n / 10  /* 0.1 to 5.0 */

    gen double W_formal   = 0.5 * gamma * `rvar_f' * 100
    gen double W_informal = 0.5 * gamma * `rvar_i' * 100
    gen double W_gap      = W_informal - W_formal

    twoway (line W_formal gamma, lcolor(navy) lwidth(medthick)) ///
           (line W_informal gamma, lcolor(cranberry) lwidth(medthick)) ///
           (line W_gap gamma, lcolor(forest_green) lwidth(medthick) lpattern(dash)), ///
        xtitle("Risk aversion ({&gamma})") ///
        ytitle("Welfare cost (% of consumption)") ///
        title("Welfare cost of consumption volatility") ///
        subtitle("Based on residual Var({&Delta}ln C)") ///
        legend(order(1 "Formal" 2 "Informal" 3 "Gap (I - F)") ///
            rows(1) position(6)) ///
        graphregion(color(white)) plotregion(margin(small))

    graph export "$figures/W8_Fig3_welfare_gamma.png", replace width(1200)

restore

*===============================================================================
* FIGURE 4: CONSUMPTION VARIANCE OVER TIME
*===============================================================================

di as text _n "=============================================="
di as text    "  FIGURE 4: VARIANCE OVER TIME"
di as text    "=============================================="

capture confirm file "$data/welfare_costs_by_year.dta"
if _rc == 0 {
    preserve

        use "$data/welfare_costs_by_year.dta", clear

        * Panel A: Var(dlnC) over time by sector
        twoway (connected var_formal year, ///
                    lcolor(navy) mcolor(navy) msymbol(circle) lwidth(medthick)) ///
               (connected var_informal year, ///
                    lcolor(cranberry) mcolor(cranberry) msymbol(diamond) lwidth(medthick)), ///
            xtitle("Year") ///
            ytitle("Var({&Delta}ln consumption)") ///
            title("Consumption variance by sector over time") ///
            legend(order(1 "Formal" 2 "Informal") rows(1) position(6)) ///
            graphregion(color(white)) plotregion(margin(small))

        graph export "$figures/W8_Fig4a_variance_time.png", replace width(1200)

        * Panel B: Welfare gap over time (gamma = 2)
        twoway (connected welfare_gap_g2 year, ///
                    lcolor(forest_green) mcolor(forest_green) msymbol(square) ///
                    lwidth(medthick)), ///
            xtitle("Year") ///
            ytitle("Welfare gap ({&gamma} = 2)") ///
            title("Welfare cost gap: informal minus formal") ///
            yline(0, lcolor(gs10) lpattern(dash)) ///
            graphregion(color(white)) plotregion(margin(small))

        graph export "$figures/W8_Fig4b_gap_time.png", replace width(1200)

    restore
}
else {
    di as text "  welfare_costs_by_year.dta not found -- run Step W6 first."
}

*===============================================================================
* FIGURE 5: INFORMALITY RATE OVER TIME
*===============================================================================

di as text _n "=============================================="
di as text    "  FIGURE 5: INFORMALITY RATE"
di as text    "=============================================="

preserve

    collapse (mean) inf_rate = informal (count) n = informal, by(year)

    twoway (connected inf_rate year, ///
                lcolor(navy) mcolor(navy) msymbol(circle) lwidth(medthick)), ///
        xtitle("Year") ///
        ytitle("Informality rate") ///
        title("Share of informal workers (prime age 20-59)") ///
        graphregion(color(white)) plotregion(margin(small))

    graph export "$figures/W8_Fig5_informality_rate.png", replace width(1200)

restore

*===============================================================================
* SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  OUTPUT FILES"
di as text    "=============================================="
di as text "Tables:"
di as text "  $tables/W8_Table1_summary.csv"
di as text "  $tables/W8_Table2_smoothing.csv"
di as text "  $tables/W8_Table3_credit.csv"
di as text "  $tables/W8_Table4_welfare.csv"
di as text "  $tables/W8_Table5_heterogeneity.csv"
di as text ""
di as text "Figures:"
di as text "  $figures/W8_Fig1_event_study.png"
di as text "  $figures/W8_Fig2a_formal_credit.png"
di as text "  $figures/W8_Fig2b_constrained.png"
di as text "  $figures/W8_Fig3_welfare_gamma.png"
di as text "  $figures/W8_Fig4a_variance_time.png"
di as text "  $figures/W8_Fig4b_gap_time.png"
di as text "  $figures/W8_Fig5_informality_rate.png"

di as text _n "=============================================="
di as text    "  Step W8 complete."
di as text    "  All tables and figures generated."
di as text    "=============================================="

log close
