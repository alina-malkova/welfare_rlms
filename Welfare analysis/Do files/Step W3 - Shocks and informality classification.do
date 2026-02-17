/*==============================================================================
  Step W3 - Shocks and informality classification

  Project:  Welfare Cost of Labor Informality
  Purpose:  Construct informality classification, income/health/job shocks,
            credit constraint indicators, and demographic controls using
            raw RLMS variable names from merged IND+HH panel
  Input:    Welfare analysis/Data/welfare_panel_consumption.dta
  Output:   Welfare analysis/Data/welfare_panel_shocks.dta

  Informality definitions:
    1. Registration-based (PRIMARY): j11_1 (officially employed?), j60_1
       (self-employment), j11 (enterprise type)
    2. Envelope-based: j10_1 (% money officially registered), j10_3
       (all money officially?)
    3. Combined

  Key raw variables:
    Informality:  j11_1, j10_1, j10_3, j60_1, j11
    Health:       m3 (self-assessed 1-5), m20 (needs help dressing)
    Job shocks:   j14 (wage arrears), j6_2 (hours/week), j8 (hours 30d)
    Credit:       f14_8, f14_10, f14_2, f14_6, e16, e13_7b, e13_71b,
                  f14_9, f14_11, f14_3
    Demographics: age, female, marst, educ, status, region

  Author:
  Created:  February 2026
==============================================================================*/

clear all
capture set maxvar 32767
do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close
log using "$logdir/Step_W3_shocks.log", replace

use "$data/welfare_panel_consumption.dta", clear
xtset idind year

di as text _n "=============================================="
di as text    "  Step W3: Shocks and informality classification"
di as text    "  Observations loaded: " _N
di as text    "=============================================="

*===============================================================================
* 1. INFORMALITY CLASSIFICATION
*===============================================================================

di as text _n "=============================================="
di as text    "  1. INFORMALITY CLASSIFICATION"
di as text    "=============================================="

* -----------------------------------------------------------------------
* Definition 1: Registration-based (PRIMARY definition)
*
* j11_1: "Are you officially employed at this enterprise?"
*   1 = yes (formal), 2 = no (informal)
*
* Supplemented by:
*   j60_1: "Have you ever started your own business?" (self-employment proxy)
*   j11:   Enterprise type (state, private, individual entrepreneur, etc.)
*          Enterprise type codes suggestive of informality:
*          individual entrepreneur without registration, hired by individual, etc.
* -----------------------------------------------------------------------

gen byte informal_reg = .

* Primary: j11_1 — officially employed
capture confirm variable j11_1
if _rc == 0 {
    replace informal_reg = 0 if j11_1 == 1       /* officially employed = formal */
    replace informal_reg = 1 if j11_1 == 2       /* not officially employed = informal */
    di as text "j11_1 (officially employed): coded"
    tab j11_1, missing
}

* Supplement with j60_1 (self-employment) for those with missing j11_1
* Self-employed without official registration -> informal
capture confirm variable j60_1
if _rc == 0 {
    replace informal_reg = 1 if informal_reg == . & j60_1 == 1
    di as text "j60_1 (self-employment): supplemented"
}

* Supplement with j11 (enterprise type) for remaining missings
* Typical RLMS enterprise codes where informality is likely:
*   Individual entrepreneur (IEA) without employees, hired by private person,
*   working for private person at their home, etc.
* Formal enterprises: state, municipal, joint-stock, cooperative
capture confirm variable j11
if _rc == 0 {
    * State/municipal/joint-stock/cooperative enterprises = formal
    replace informal_reg = 0 if informal_reg == . & inlist(j11, 1, 2, 3, 4, 5)
    * Individual entrepreneur, hired by individual = likely informal
    replace informal_reg = 1 if informal_reg == . & inlist(j11, 6, 7, 8, 9)
    di as text "j11 (enterprise type): supplemented"
    tab j11, missing
}

label variable informal_reg "Informal worker (registration-based)"
label define yesno_inf 0 "Formal" 1 "Informal", replace
label values informal_reg yesno_inf

di as text _n "--- Registration-based informality by year ---"
tab informal_reg year, col missing

* -----------------------------------------------------------------------
* Definition 2: Envelope-earnings-based
*
* j10_1: "What percentage of your wages is officially registered?"
*   If < 100 -> receives some earnings "in envelope"
*
* j10_3: "Is all of your money received officially?"
*   1 = yes (all official), 2 = no (some unofficial / envelope)
* -----------------------------------------------------------------------

gen byte informal_env = .

* Primary: j10_1 — share of earnings officially registered
capture confirm variable j10_1
if _rc == 0 {
    * Recode: 100% officially registered = formal; <100% = envelope earner
    replace informal_env = 0 if j10_1 >= 100 & j10_1 < .
    replace informal_env = 1 if j10_1 < 100  & j10_1 >= 0 & j10_1 < .

    * Store share for analysis
    gen double share_official = j10_1 / 100 if j10_1 >= 0 & j10_1 < .
    replace share_official = 1 if share_official > 1 & share_official < .
    label variable share_official "Share of earnings officially registered (0-1)"
    di as text "j10_1 (% officially registered): coded"
}

* Supplement with j10_3 (all money officially?) where j10_1 missing
capture confirm variable j10_3
if _rc == 0 {
    replace informal_env = 0 if informal_env == . & j10_3 == 1   /* all official */
    replace informal_env = 1 if informal_env == . & j10_3 == 2   /* not all official */
    di as text "j10_3 (all money officially): supplemented"
}

label variable informal_env "Informal worker (envelope-earnings-based)"
label values informal_env yesno_inf

di as text _n "--- Envelope-based informality by year ---"
tab informal_env year, col missing

* -----------------------------------------------------------------------
* Definition 3: Combined indicator
* Informal if EITHER not officially registered OR receives envelope earnings
* -----------------------------------------------------------------------

gen byte informal = .
replace informal = 0 if informal_reg == 0 & (informal_env == 0 | informal_env == .)
replace informal = 1 if informal_reg == 1 | informal_env == 1
* If only one definition available, use that
replace informal = informal_reg if informal == . & informal_reg < .
replace informal = informal_env if informal == . & informal_env < .

label variable informal "Informal worker (combined definition)"
label values informal yesno_inf

di as text _n "--- Combined informality by year ---"
tab informal year, col missing

*===============================================================================
* 2. LAGGED INFORMALITY AND TRANSITIONS
*===============================================================================

di as text _n "=============================================="
di as text    "  2. INFORMALITY TRANSITIONS"
di as text    "=============================================="

* Lagged status
gen byte L_informal     = L.informal
gen byte L_informal_reg = L.informal_reg
gen byte L_informal_env = L.informal_env

label variable L_informal     "Informal status (t-1)"
label variable L_informal_reg "Informal status, registration (t-1)"
label variable L_informal_env "Informal status, envelope (t-1)"

* Transition indicators
gen byte trans_form_to_inf = (informal == 1 & L_informal == 0) ///
    if informal < . & L_informal < .
gen byte trans_inf_to_form = (informal == 0 & L_informal == 1) ///
    if informal < . & L_informal < .
gen byte trans_stayer_form = (informal == 0 & L_informal == 0) ///
    if informal < . & L_informal < .
gen byte trans_stayer_inf  = (informal == 1 & L_informal == 1) ///
    if informal < . & L_informal < .

label variable trans_form_to_inf "Transition: formal -> informal"
label variable trans_inf_to_form "Transition: informal -> formal"
label variable trans_stayer_form "Stayer: formal both periods"
label variable trans_stayer_inf  "Stayer: informal both periods"

* Transition matrix
di as text _n "--- Transition matrix ---"
tab L_informal informal, row

di as text _n "--- Transition indicator frequencies ---"
tab1 trans_form_to_inf trans_inf_to_form trans_stayer_form trans_stayer_inf, missing

*===============================================================================
* 3. HEALTH SHOCKS
*===============================================================================

di as text _n "=============================================="
di as text    "  3. HEALTH SHOCKS"
di as text    "=============================================="

* -----------------------------------------------------------------------
* m3: Self-assessed health evaluation (1-5 scale)
*   RLMS coding: 1 = very good, 2 = good, 3 = average, 4 = bad, 5 = very bad
*   Health deterioration = increase in m3 from t-1 to t
* -----------------------------------------------------------------------

gen byte shock_health_det = .
capture confirm variable m3
if _rc == 0 {
    gen double L_m3 = L.m3
    * Deterioration: m3 increased (health worsened) by at least 1 category
    replace shock_health_det = 0 if m3 < . & L_m3 < .
    replace shock_health_det = 1 if m3 > L_m3 & m3 < . & L_m3 < .
    label variable shock_health_det "Health shock: self-assessed health deterioration"
    drop L_m3
    di as text "m3 (self-assessed health): deterioration coded"
    tab shock_health_det, missing
}

* -----------------------------------------------------------------------
* m20: "Do you need help dressing?" — proxy for severe health/disability
*   Change from not needing help to needing help = disability shock
*   RLMS: 1 = no help needed, 2 = needs some help, 3 = cannot dress alone
* -----------------------------------------------------------------------

gen byte shock_disability = .
capture confirm variable m20
if _rc == 0 {
    gen byte needs_help = (m20 >= 2 & m20 < .) if m20 < .
    gen byte L_needs_help = L.needs_help
    replace shock_disability = 0 if needs_help < . & L_needs_help < .
    replace shock_disability = 1 if needs_help == 1 & L_needs_help == 0
    label variable shock_disability "Health shock: new need for help (disability onset)"
    drop needs_help L_needs_help
    di as text "m20 (needs help dressing): disability onset coded"
    tab shock_disability, missing
}

* Composite health shock (any of the above)
gen byte shock_health = .
replace shock_health = 0 if shock_health_det == 0 | shock_disability == 0
replace shock_health = 1 if shock_health_det == 1 | shock_disability == 1
label variable shock_health "Any health shock"

tab shock_health, missing

*===============================================================================
* 4. JOB SHOCKS
*===============================================================================

di as text _n "=============================================="
di as text    "  4. JOB SHOCKS"
di as text    "=============================================="

* -----------------------------------------------------------------------
* j14: Wage arrears — "Does your employer owe you money for work done?"
*   1 = yes, 2 = no (or similar coding)
*   New wage arrears = arrears at t but not at t-1
* -----------------------------------------------------------------------

gen byte shock_arrears = .
capture confirm variable j14
if _rc == 0 {
    gen byte arrears_now = (j14 == 1) if j14 < .
    gen byte L_arrears   = L.arrears_now
    replace shock_arrears = 0 if arrears_now < . & L_arrears < .
    replace shock_arrears = 1 if arrears_now == 1 & L_arrears == 0
    label variable shock_arrears "Job shock: new wage arrears"
    drop arrears_now L_arrears
    di as text "j14 (wage arrears): new arrears coded"
    tab shock_arrears, missing
}

* -----------------------------------------------------------------------
* Hours reduction > 20% decline from t-1 to t
* j6_2: usual hours per week at primary job
* j8:   total hours worked in past 30 days
* Use j6_2 as primary; supplement with j8 where j6_2 is missing
* -----------------------------------------------------------------------

gen byte shock_hours = .

* Try j6_2 first (hours/week)
capture confirm variable j6_2
if _rc == 0 {
    gen double hours_week = j6_2 if j6_2 > 0 & j6_2 < .
    gen double L_hours_week = L.hours_week
    gen double hours_change_w = (hours_week - L_hours_week) / L_hours_week ///
        if L_hours_week > 0 & L_hours_week < . & hours_week >= 0 & hours_week < .
    replace shock_hours = (hours_change_w < -0.20) if hours_change_w < .
    label variable shock_hours "Job shock: hours reduction > 20%"
    drop hours_week L_hours_week hours_change_w
    di as text "j6_2 (hours/week): hours reduction coded"
}

* Supplement with j8 (hours in 30 days) where j6_2 missing
capture confirm variable j8
if _rc == 0 {
    if _rc == 0 {
        gen double hours_30d = j8 if j8 > 0 & j8 < .
        gen double L_hours_30d = L.hours_30d
        gen double hours_change_m = (hours_30d - L_hours_30d) / L_hours_30d ///
            if L_hours_30d > 0 & L_hours_30d < . & hours_30d >= 0 & hours_30d < .
        replace shock_hours = (hours_change_m < -0.20) ///
            if shock_hours == . & hours_change_m < .
        drop hours_30d L_hours_30d hours_change_m
        di as text "j8 (hours 30d): supplemented hours reduction"
    }
}

tab shock_hours, missing

* Composite job shock (arrears or hours reduction)
gen byte shock_job = .
replace shock_job = 0 if shock_arrears == 0 | shock_hours == 0
replace shock_job = 1 if shock_arrears == 1 | shock_hours == 1
label variable shock_job "Any job shock (arrears or hours)"

tab shock_job, missing

*===============================================================================
* 5. REGIONAL ECONOMIC SHOCKS
*===============================================================================

di as text _n "=============================================="
di as text    "  5. REGIONAL ECONOMIC SHOCKS"
di as text    "=============================================="

* Deviation of regional mean log labor income from region-specific trend
* Negative deviation = below-trend regional labor market conditions

capture confirm variable region
if _rc == 0 {
    * Compute region-year mean log labor income
    bysort region year: egen double reg_mean_lny = mean(lny_lab)

    * Region-specific long-run mean (trend approximation)
    bysort region: egen double reg_trend_lny = mean(reg_mean_lny)

    * Deviation from trend
    gen double reg_shock_income = reg_mean_lny - reg_trend_lny
    label variable reg_shock_income "Regional income deviation from trend"

    * Binary indicator: below-trend = negative shock
    gen byte shock_regional = (reg_shock_income < 0) if reg_shock_income < .
    label variable shock_regional "Regional shock: below-trend regional income"

    di as text "Regional shocks constructed."
    tab shock_regional year, col
}
else {
    gen double reg_shock_income = .
    gen byte shock_regional = .
    di as text "WARNING: region variable not found. Regional shocks set to missing."
}

* -----------------------------------------------------------------------
* Composite: any shock (health, job, or regional)
* -----------------------------------------------------------------------

gen byte shock_any = .
replace shock_any = 0 if shock_health == 0 | shock_job == 0 | shock_regional == 0
replace shock_any = 1 if shock_health == 1 | shock_job == 1 | shock_regional == 1
label variable shock_any "Any income shock (health, job, or regional)"

*===============================================================================
* 6. INCOME CHANGE CLASSIFICATION
*===============================================================================

di as text _n "=============================================="
di as text    "  6. INCOME CHANGE CLASSIFICATION"
di as text    "=============================================="

* Large negative income change (bottom quartile of dlny_lab)
quietly summarize dlny_lab, detail
gen byte large_inc_drop = (dlny_lab < r(p25)) if dlny_lab < .
label variable large_inc_drop "Large income drop (bottom quartile Delta ln y)"

* Positive vs negative income change
gen byte inc_decrease = (dlny_lab < 0) if dlny_lab < .
label variable inc_decrease "Income decreased (Delta ln y < 0)"

tab large_inc_drop, missing
tab inc_decrease, missing

*===============================================================================
* 7. CREDIT CONSTRAINT INDICATORS
*===============================================================================

di as text _n "=============================================="
di as text    "  7. CREDIT CONSTRAINT INDICATORS"
di as text    "=============================================="

* -----------------------------------------------------------------------
* 7a. Has credit debts: f14_8
*   1 = yes (has credit debts), 2 = no
* -----------------------------------------------------------------------

gen byte has_credit_debts = .
capture confirm variable f14_8
if _rc == 0 {
    replace has_credit_debts = 1 if f14_8 == 1
    replace has_credit_debts = 0 if f14_8 == 2
    label variable has_credit_debts "Has credit debts (f14_8)"
    tab has_credit_debts, missing
}

* -----------------------------------------------------------------------
* 7b. Has money debts (private): f14_10
*   1 = yes, 2 = no
* -----------------------------------------------------------------------

gen byte has_money_debts = .
capture confirm variable f14_10
if _rc == 0 {
    replace has_money_debts = 1 if f14_10 == 1
    replace has_money_debts = 0 if f14_10 == 2
    label variable has_money_debts "Has money debts/private (f14_10)"
    tab has_money_debts, missing
}

* -----------------------------------------------------------------------
* 7c. Family has debt: f14_2
*   1 = yes, 2 = no
* -----------------------------------------------------------------------

gen byte family_has_debt = .
capture confirm variable f14_2
if _rc == 0 {
    replace family_has_debt = 1 if f14_2 == 1
    replace family_has_debt = 0 if f14_2 == 2
    label variable family_has_debt "Family has debt (f14_2)"
    tab family_has_debt, missing
}

* -----------------------------------------------------------------------
* 7d. Took credit in past 12 months: f14_6 (indicates credit ACCESS)
*   1 = yes, 2 = no
* -----------------------------------------------------------------------

gen byte took_credit_12m = .
capture confirm variable f14_6
if _rc == 0 {
    replace took_credit_12m = 1 if f14_6 == 1
    replace took_credit_12m = 0 if f14_6 == 2
    label variable took_credit_12m "Took credit in past 12m (f14_6) - credit access"
    tab took_credit_12m, missing
}

* -----------------------------------------------------------------------
* 7e. Savings behavior: e16
*   1 = saved in past 30d, 2 = did not save
*   Proxy for buffer stock / precautionary savings
* -----------------------------------------------------------------------

gen byte saved_30d = .
capture confirm variable e16
if _rc == 0 {
    replace saved_30d = 1 if e16 == 1
    replace saved_30d = 0 if e16 == 2
    label variable saved_30d "Saved in past 30 days (e16) - buffer stock proxy"
    tab saved_30d, missing
}

* Savings amount
capture confirm variable e17
if _rc == 0 {
    gen double savings_amt = e17 if e17 > 0 & e17 < .
    replace savings_amt = 0 if savings_amt == . & saved_30d == 0
    label variable savings_amt "Savings amount past 30d (e17, nominal rubles)"
}

* -----------------------------------------------------------------------
* 7f. Making credit repayments: e13_7b > 0 (has formal credit)
*   e13_7b: total credit repayment in past 30 days
* -----------------------------------------------------------------------

gen byte has_formal_credit = .
capture confirm variable e13_7b
if _rc == 0 {
    replace has_formal_credit = 1 if e13_7b > 0 & e13_7b < .
    replace has_formal_credit = 0 if e13_7b == 0 | (e13_7b == . & has_formal_credit == .)
    label variable has_formal_credit "Has formal credit (e13_7b > 0, making repayments)"
    tab has_formal_credit, missing
}

* -----------------------------------------------------------------------
* 7g. Has private/informal debts: e13_71b > 0
*   e13_71b: repayment of private debts in past 30 days
* -----------------------------------------------------------------------

gen byte has_informal_credit = .
capture confirm variable e13_71b
if _rc == 0 {
    replace has_informal_credit = 1 if e13_71b > 0 & e13_71b < .
    replace has_informal_credit = 0 if e13_71b == 0 | (e13_71b == . & has_informal_credit == .)
    label variable has_informal_credit "Has informal credit (e13_71b > 0, private debts)"
    tab has_informal_credit, missing
}

* -----------------------------------------------------------------------
* 7h. Debt stock values (for magnitude analysis)
* -----------------------------------------------------------------------

* Credit debt value (f14_9)
capture confirm variable f14_9
if _rc == 0 {
    gen double credit_debt_value = f14_9 if f14_9 > 0 & f14_9 < .
    label variable credit_debt_value "Credit debt value (f14_9, nominal rubles)"
}

* Money debt value (f14_11)
capture confirm variable f14_11
if _rc == 0 {
    gen double money_debt_value = f14_11 if f14_11 > 0 & f14_11 < .
    label variable money_debt_value "Money/private debt value (f14_11, nominal rubles)"
}

* Family debt amount (f14_3)
capture confirm variable f14_3
if _rc == 0 {
    gen double family_debt_value = f14_3 if f14_3 > 0 & f14_3 < .
    label variable family_debt_value "Family debt amount (f14_3, nominal rubles)"
}

* -----------------------------------------------------------------------
* 7i. Recent credit activity (past 30 days)
* -----------------------------------------------------------------------

* f13_11a: took credit in past 30d (1=yes, 2=no)
gen byte took_credit_30d = .
capture confirm variable f13_11a
if _rc == 0 {
    replace took_credit_30d = 1 if f13_11a == 1
    replace took_credit_30d = 0 if f13_11a == 2
    label variable took_credit_30d "Took credit in past 30d (f13_11a)"
}

* f13_1a: received a loan in past 30d (1=yes, 2=no)
gen byte received_loan_30d = .
capture confirm variable f13_1a
if _rc == 0 {
    replace received_loan_30d = 1 if f13_1a == 1
    replace received_loan_30d = 0 if f13_1a == 2
    label variable received_loan_30d "Received loan in past 30d (f13_1a)"
}

* -----------------------------------------------------------------------
* 7j. Composite credit constraint indicator
*   Credit constrained = has debts but no savings (buffer) and no credit access
* -----------------------------------------------------------------------

gen byte credit_constrained = .
replace credit_constrained = 0 if has_credit_debts < . | has_money_debts < . | ///
    family_has_debt < . | saved_30d < .
* Constrained: has debts AND does not save AND did not take new credit
replace credit_constrained = 1 if ///
    (has_credit_debts == 1 | has_money_debts == 1 | family_has_debt == 1) & ///
    saved_30d == 0 & took_credit_12m == 0
label variable credit_constrained "Credit constrained (has debt, no savings, no new credit)"

tab credit_constrained, missing

*===============================================================================
* 8. CREDIT MARKET ACCESSIBILITY (from existing project, if available)
*===============================================================================

di as text _n "=============================================="
di as text    "  8. CREDIT MARKET ACCESSIBILITY"
di as text    "=============================================="

* Merge CMA from existing credit market project workfile
capture merge 1:1 idind year using "$crdata/rlms_credit_workfile.dta", ///
    keepusing(schadjC lnpopsite) nogenerate keep(master match)

capture confirm variable schadjC
if _rc == 0 {
    quietly summarize schadjC, detail
    gen byte cma_high = (schadjC > r(p50)) if schadjC < .
    label variable cma_high "High credit market accessibility (above median)"
    di as text "Credit market accessibility merged."
    tab cma_high, missing
}
else {
    gen byte cma_high = .
    di as text "CMA variable not available. cma_high set to missing."
}

*===============================================================================
* 9. DEMOGRAPHIC CONTROLS
*===============================================================================

di as text _n "=============================================="
di as text    "  9. DEMOGRAPHIC CONTROLS"
di as text    "=============================================="

* --- Age squared ---
capture confirm variable age
if _rc == 0 {
    gen double age2 = age^2
    label variable age2 "Age squared"
}

* --- Female indicator ---
* Already in data as 'female' (created in W1 from h5)
capture confirm variable female
if _rc == 0 {
    label variable female "Female (1=yes)"
    tab female, missing
}

* --- Married indicator from marst ---
* RLMS marst codes: 1 = never married, 2 = married (registered),
*   3 = civil marriage, 4 = divorced, 5 = widowed, 6 = separated
gen byte married = .
capture confirm variable marst
if _rc == 0 {
    replace married = 1 if inlist(marst, 2, 3)    /* married or civil union */
    replace married = 0 if inlist(marst, 1, 4, 5, 6) /* single/divorced/widowed */
    label variable married "Married or cohabiting"
    tab married, missing
}

* --- Education categories from educ ---
* RLMS education (educ) coding:
*   1 = no primary, 2 = primary, 3 = incomplete secondary,
*   4 = complete secondary, 5 = incomplete higher, 6 = higher (completed),
*   7 = graduate degree
gen byte educat = .
capture confirm variable educ
if _rc == 0 {
    replace educat = 1 if educ <= 3                  /* less than secondary */
    replace educat = 2 if educ == 4                  /* complete secondary */
    replace educat = 3 if educ == 5                  /* vocational / incomplete higher */
    replace educat = 4 if educ >= 6 & educ < .       /* higher or graduate */
    label variable educat "Education category (4 groups)"
    label define educat_lbl 1 "Below secondary" 2 "Complete secondary" ///
        3 "Vocational/inc. higher" 4 "Higher education", replace
    label values educat educat_lbl
    tab educat, missing
}

* --- Urban/rural indicator from status ---
* RLMS status variable: settlement type
*   1 = rural, 2 = PGT (urban-type settlement), 3 = city
*   or similar coding where higher = more urban
gen byte urban = .
capture confirm variable status
if _rc == 0 {
    replace urban = 0 if status == 1          /* rural */
    replace urban = 1 if status >= 2 & status < . /* urban or PGT */
    label variable urban "Urban residence"
    tab urban, missing
}

* --- Region (keep as-is for FE) ---
capture confirm variable region
if _rc == 0 {
    label variable region "RLMS region code"
    tab region, missing
}

*===============================================================================
* 10. ANALYSIS SAMPLE FLAG (2006-2023)
*===============================================================================

di as text _n "=============================================="
di as text    "  10. ANALYSIS SAMPLE FLAG"
di as text    "=============================================="

* Keep 2004-2005 for lags; flag main analysis period
gen byte analysis_sample = (year >= 2006 & year <= 2023)
label variable analysis_sample "In analysis period (2006-2023)"

di as text "Full sample:"
tab year, missing

di as text _n "Analysis sample (2006-2023):"
count if analysis_sample == 1
di as text "Observations in analysis sample: " r(N)

*===============================================================================
* 11. TABULATIONS AND CROSS-TABULATIONS
*===============================================================================

di as text _n "=============================================="
di as text    "  11. TABULATIONS"
di as text    "=============================================="

* --- Informality rates over time ---
di as text _n "=== Informality rates by year ==="
tab informal year if analysis_sample, col nofreq

di as text _n "=== Registration-based informality by year ==="
tab informal_reg year if analysis_sample, col nofreq

di as text _n "=== Envelope-based informality by year ==="
tab informal_env year if analysis_sample, col nofreq

* --- Shock frequencies by informality ---
di as text _n "=== Shocks by informality status ==="
foreach v in shock_health shock_health_det shock_disability ///
             shock_job shock_arrears shock_hours shock_regional shock_any {
    capture confirm variable `v'
    if _rc == 0 {
        di as text _n "--- `v' ---"
        tab `v' informal if analysis_sample, col chi2
    }
}

* --- Credit constraints by informality ---
di as text _n "=== Credit indicators by informality status ==="
foreach v in has_credit_debts has_money_debts family_has_debt took_credit_12m ///
             saved_30d has_formal_credit has_informal_credit credit_constrained {
    capture confirm variable `v'
    if _rc == 0 {
        di as text _n "--- `v' ---"
        tab `v' informal if analysis_sample, col chi2
    }
}

* --- Demographics by informality ---
di as text _n "=== Demographics by informality status ==="
foreach v in female married educat urban {
    capture confirm variable `v'
    if _rc == 0 {
        di as text _n "--- `v' ---"
        tab `v' informal if analysis_sample, col
    }
}

* --- Summary statistics for continuous variables by informality ---
di as text _n "=== Continuous variables by informality ==="
foreach v in age labor_inc_eq disp_inc_eq cons_nondur_eq lnc lny_lab {
    capture confirm variable `v'
    if _rc == 0 {
        di as text _n "--- `v' ---"
        tabstat `v' if analysis_sample, by(informal) stats(N mean sd p25 p50 p75) ///
            columns(statistics)
    }
}

*===============================================================================
* 12. SAVE
*===============================================================================

di as text _n "=============================================="
di as text    "  SAVING OUTPUT"
di as text    "=============================================="

compress
label data "Welfare analysis - shocks and informality (Step W3)"
save "$data/welfare_panel_shocks.dta", replace

di as text _n "=============================================="
di as text    "  Step W3 complete."
di as text    "  Output: $data/welfare_panel_shocks.dta"
di as text    "  Observations: " _N
di as text    "  Next: Run Steps W4/W5/W6 (can run in parallel)."
di as text    "=============================================="

log close
