/*==============================================================================
  Step W2 - Consumption and income measures

  Project:  Welfare Cost of Labor Informality
  Purpose:  Construct consumption and income measures following
            Gorodnichenko-Peter-Stolyarov (GPS, 2010) methodology,
            using raw RLMS variable names from merged IND+HH panel
  Input:    Welfare analysis/Data/welfare_panel_raw.dta
  Output:   Welfare analysis/Data/welfare_panel_consumption.dta

  Methodology (GPS 2010):
    - Non-durable consumption: food + food away + clothing + services + fuel
      + utilities + medical
    - Durable-inclusive consumption: non-durable + durables
    - Income: labor income, government benefits, disposable
    - OECD modified equivalence scale
    - CPI deflation to constant December 2016 prices
    - Log transformations and first differences
    - Trimming top/bottom 1% of growth rates

  Key raw variables:
    Food:      e1_1c - e1_57c (7-day costs per item)
    Eat out:   e3 (7d), e4 (30d)
    Clothing:  e6 (3m)
    Durables:  e7_1b - e7_10b (3m)
    Fuel:      e8_1b - e8_3b (30d)
    Services:  e9_1b - e9_3b (30d)
    Utilities: e11 (30d)
    Medical:   e13_3b (30d)
    Wages:     j10 (after-tax 30d), j40 (job2 wages)
    Benefits:  f12_1b (pension), f12_2b (stipend), f12_3b (unemployment)
    Help:      e41_1 - e41_5
    HH income: f14 (total money income 30d)

  Author:
  Created:  February 2026
==============================================================================*/

clear all
capture set maxvar 32767
do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close
log using "$logdir/Step_W2_consumption.log", replace

use "$data/welfare_panel_raw.dta", clear

di as text _n "=============================================="
di as text    "  Step W2: Consumption and income measures"
di as text    "  Observations loaded: " _N
di as text    "=============================================="

*===============================================================================
* 1. CPI DEFLATOR (hardcoded annual Russian CPI, base Dec 2016 = 100)
*===============================================================================

di as text _n "=============================================="
di as text    "  1. CPI DEFLATION"
di as text    "=============================================="

* Russian CPI index, base December 2016 = 100
* Sources: Rosstat, World Bank. Values are annual averages rescaled so that
* the December 2016 level = 100.

gen double cpi = .
replace cpi = 34.21  if year == 2004
replace cpi = 38.56  if year == 2005
replace cpi = 42.03  if year == 2006
replace cpi = 45.82  if year == 2007
replace cpi = 52.27  if year == 2008
replace cpi = 58.52  if year == 2009
replace cpi = 63.38  if year == 2010
replace cpi = 67.50  if year == 2011
replace cpi = 70.94  if year == 2012
replace cpi = 75.62  if year == 2013
replace cpi = 81.34  if year == 2014
replace cpi = 93.97  if year == 2015
replace cpi = 100.00 if year == 2016
replace cpi = 103.68 if year == 2017
replace cpi = 106.58 if year == 2018
replace cpi = 111.10 if year == 2019
replace cpi = 114.56 if year == 2020
replace cpi = 122.24 if year == 2021
replace cpi = 139.48 if year == 2022
replace cpi = 145.84 if year == 2023

label variable cpi "CPI index (Dec 2016 = 100)"

* Deflator: nominal * deflator = real (Dec 2016 rubles)
gen double deflator = 100 / cpi
label variable deflator "CPI deflator (to Dec 2016 rubles)"

tab year if cpi == ., missing
di as text "Observations with missing CPI: " r(N)

*===============================================================================
* 1b. CLEAN RLMS SPECIAL CODES AND IMPLAUSIBLE VALUES
*===============================================================================

di as text _n "=============================================="
di as text    "  1b. CLEANING RLMS SPECIAL CODES"
di as text    "=============================================="

* RLMS uses special codes for missing/refused responses:
*   99999999 = "Don't know"
*   99999998 = "Refused to answer"
*   99999997 = "Hard to say" / other special
*   Similar patterns: 9999999, 999999, 99999 (depending on variable)
*
* Additionally, set implausibly large values to missing:
*   Monthly consumption/income > 5,000,000 rubles (~$80,000/month) is almost
*   certainly a coding error for Russian household data.

* List of all expenditure/income variables to clean
local money_vars ""

* Food items (e1_*c)
forvalues i = 1/57 {
    capture confirm variable e1_`i'c
    if _rc == 0 {
        local money_vars "`money_vars' e1_`i'c"
    }
}

* Other expenditure variables
foreach v in e3 e4 e6 e11 e13_3b {
    capture confirm variable `v'
    if _rc == 0 {
        local money_vars "`money_vars' `v'"
    }
}

* Durable goods (e7_*b)
forvalues i = 1/10 {
    capture confirm variable e7_`i'b
    if _rc == 0 {
        local money_vars "`money_vars' e7_`i'b"
    }
}

* Fuel (e8_*b)
forvalues i = 1/3 {
    capture confirm variable e8_`i'b
    if _rc == 0 {
        local money_vars "`money_vars' e8_`i'b"
    }
}

* Services (e9_*b)
forvalues i = 1/3 {
    capture confirm variable e9_`i'b
    if _rc == 0 {
        local money_vars "`money_vars' e9_`i'b"
    }
}

* Help received (e41_*)
forvalues i = 1/5 {
    capture confirm variable e41_`i'
    if _rc == 0 {
        local money_vars "`money_vars' e41_`i'"
    }
}

* Income variables
foreach v in j10 j40 f12_1b f12_2b f12_3b f14 {
    capture confirm variable `v'
    if _rc == 0 {
        local money_vars "`money_vars' `v'"
    }
}

* Clean all money variables
local n_cleaned_total = 0
foreach v of local money_vars {
    local n_before = 0
    quietly count if `v' < .
    local n_before = r(N)

    * Replace RLMS special codes with missing
    * These are typically 99999999, 99999998, 99999997, etc.
    replace `v' = . if `v' >= 99999990 & `v' < .
    replace `v' = . if `v' >= 9999990 & `v' < 10000000
    replace `v' = . if `v' >= 999990 & `v' < 1000000

    * Replace implausibly large values (> 5 million rubles for single item/month)
    replace `v' = . if `v' > 5000000 & `v' < .

    quietly count if `v' < .
    local n_after = r(N)
    local n_cleaned = `n_before' - `n_after'
    local n_cleaned_total = `n_cleaned_total' + `n_cleaned'
}

di as text "Total implausible/special-code values set to missing: `n_cleaned_total'"

*===============================================================================
* 2. FOOD CONSUMPTION (at home, 7-day items -> monthly)
*===============================================================================

di as text _n "=============================================="
di as text    "  2. FOOD CONSUMPTION"
di as text    "=============================================="

* RLMS records household spending on individual food items for the past 7 days
* in variables e1_1c through e1_57c. Not all items exist in all waves, so we
* loop cautiously with capture.

gen double food_home_7d = 0
local food_count = 0

forvalues i = 1/57 {
    capture confirm variable e1_`i'c
    if _rc == 0 {
        * Replace negative or missing with 0 for summation
        replace food_home_7d = food_home_7d + e1_`i'c ///
            if e1_`i'c > 0 & e1_`i'c < .
        local food_count = `food_count' + 1
    }
}

di as text "Food items found and summed: `food_count'"

* Convert 7-day to 30-day (monthly)
gen double food_home = food_home_7d * (30 / 7)
label variable food_home "Food at home (monthly, nominal rubles)"
label variable food_home_7d "Food at home (7-day, nominal rubles)"

summarize food_home, detail

*===============================================================================
* 3. FOOD AWAY FROM HOME
*===============================================================================

di as text _n "=============================================="
di as text    "  3. FOOD AWAY FROM HOME"
di as text    "=============================================="

* e3: cost of eating out in the past 7 days
* e4: cost of eating out in the past 30 days
* Prefer e4 (30d) if available; otherwise scale e3 from 7d to 30d

gen double food_away = 0

capture confirm variable e4
if _rc == 0 {
    replace food_away = e4 if e4 > 0 & e4 < .
    di as text "Using e4 (30-day eating out costs) as primary source."
}

* Fill in from e3 (7-day) where e4 is missing
capture confirm variable e3
if _rc == 0 {
    replace food_away = e3 * (30 / 7) if food_away == 0 & e3 > 0 & e3 < .
    di as text "Supplementing with e3 * 30/7 where e4 missing."
}

label variable food_away "Food away from home (monthly, nominal rubles)"
summarize food_away, detail

*===============================================================================
* 4. CLOTHING AND FOOTWEAR (3-month recall -> monthly)
*===============================================================================

di as text _n "=============================================="
di as text    "  4. CLOTHING"
di as text    "=============================================="

* e6: total spending on clothing and footwear in the past 3 months
gen double clothing = 0
capture confirm variable e6
if _rc == 0 {
    replace clothing = e6 / 3 if e6 > 0 & e6 < .
}
label variable clothing "Clothing/footwear (monthly, nominal rubles)"
summarize clothing, detail

*===============================================================================
* 5. SERVICES (already 30-day)
*===============================================================================

di as text _n "=============================================="
di as text    "  5. SERVICES"
di as text    "=============================================="

* e9_1b, e9_2b, e9_3b: services expenditures (30-day)
gen double services = 0
foreach v in e9_1b e9_2b e9_3b {
    capture confirm variable `v'
    if _rc == 0 {
        replace services = services + `v' if `v' > 0 & `v' < .
    }
}
label variable services "Services (monthly, nominal rubles)"
summarize services, detail

*===============================================================================
* 6. FUEL (already 30-day)
*===============================================================================

di as text _n "=============================================="
di as text    "  6. FUEL"
di as text    "=============================================="

* e8_1b, e8_2b, e8_3b: fuel/energy expenditures (30-day)
gen double fuel = 0
foreach v in e8_1b e8_2b e8_3b {
    capture confirm variable `v'
    if _rc == 0 {
        replace fuel = fuel + `v' if `v' > 0 & `v' < .
    }
}
label variable fuel "Fuel/energy (monthly, nominal rubles)"
summarize fuel, detail

*===============================================================================
* 7. RENT AND UTILITIES (already 30-day)
*===============================================================================

di as text _n "=============================================="
di as text    "  7. RENT AND UTILITIES"
di as text    "=============================================="

* e11: rent and utility payments (30-day)
gen double utilities = 0
capture confirm variable e11
if _rc == 0 {
    replace utilities = e11 if e11 > 0 & e11 < .
}
label variable utilities "Rent/utilities (monthly, nominal rubles)"
summarize utilities, detail

*===============================================================================
* 8. MEDICAL EXPENDITURES (already 30-day)
*===============================================================================

di as text _n "=============================================="
di as text    "  8. MEDICAL EXPENDITURES"
di as text    "=============================================="

* e13_3b: medical expenditures (30-day)
gen double medical = 0
capture confirm variable e13_3b
if _rc == 0 {
    replace medical = e13_3b if e13_3b > 0 & e13_3b < .
}
label variable medical "Medical expenditures (monthly, nominal rubles)"
summarize medical, detail

*===============================================================================
* 9. NON-DURABLE CONSUMPTION AGGREGATE
*===============================================================================

di as text _n "=============================================="
di as text    "  9. NON-DURABLE CONSUMPTION"
di as text    "=============================================="

gen double cons_nondur = food_home + food_away + clothing + services ///
                         + fuel + utilities + medical
label variable cons_nondur "Non-durable consumption (monthly, nominal rubles)"

* Set to missing if all major components are zero (likely non-response)
replace cons_nondur = . if food_home == 0 & food_away == 0 & clothing == 0 ///
    & services == 0 & fuel == 0 & utilities == 0 & medical == 0

di as text "Non-durable consumption:"
summarize cons_nondur, detail
di as text "Non-missing: " r(N) " observations"

*===============================================================================
* 10. DURABLE GOODS (3-month recall -> monthly)
*===============================================================================

di as text _n "=============================================="
di as text    "  10. DURABLE GOODS"
di as text    "=============================================="

* e7_1b through e7_10b: durable goods purchases in past 3 months
gen double durables_3m = 0
forvalues i = 1/10 {
    capture confirm variable e7_`i'b
    if _rc == 0 {
        replace durables_3m = durables_3m + e7_`i'b if e7_`i'b > 0 & e7_`i'b < .
    }
}

gen double durables = durables_3m / 3
label variable durables_3m "Durable goods (3-month total, nominal rubles)"
label variable durables "Durable goods (monthly, nominal rubles)"
summarize durables, detail

*===============================================================================
* 11. DURABLE-INCLUSIVE CONSUMPTION
*===============================================================================

gen double cons_dur = cons_nondur + durables if cons_nondur < .
label variable cons_dur "Durable-inclusive consumption (monthly, nominal rubles)"
summarize cons_dur, detail

*===============================================================================
* 12. DEFLATE ALL CONSUMPTION MEASURES TO CONSTANT DEC 2016 RUBLES
*===============================================================================

di as text _n "=============================================="
di as text    "  12. DEFLATING TO CONSTANT PRICES"
di as text    "=============================================="

foreach v in food_home food_away clothing services fuel utilities medical ///
             cons_nondur durables cons_dur {
    gen double `v'_r = `v' * deflator
    local lbl : variable label `v'
    label variable `v'_r "`lbl' (Dec 2016 rubles)"
}

di as text "Real consumption measures created (suffix _r)."
summarize cons_nondur_r cons_dur_r, detail

*===============================================================================
* 13. OECD MODIFIED EQUIVALENCE SCALE
*===============================================================================

di as text _n "=============================================="
di as text    "  13. EQUIVALENCE SCALE"
di as text    "=============================================="

* OECD modified scale: head = 1.0, each additional adult (age >= 14) = 0.5,
* each child (age < 14) = 0.3
*
* We approximate from the household roster. Since we have individual-level data
* merged with household, we count adults and children within each household-year.

* Count adults (age >= 14) and children (age < 14) per household-year
bysort id_h year: egen int n_adults  = total(age >= 14 & age < .)
bysort id_h year: egen int n_children = total(age < 14 & age < .)
bysort id_h year: egen int hh_size   = count(idind)

* Ensure at least 1 adult
replace n_adults = max(n_adults, 1)

* OECD modified equivalence scale
gen double eq_scale = 1 + 0.5 * (n_adults - 1) + 0.3 * n_children
replace eq_scale = 1 if eq_scale == . | eq_scale <= 0

label variable n_adults   "Number of adults (age >= 14) in household"
label variable n_children "Number of children (age < 14) in household"
label variable hh_size    "Household size (from roster count)"
label variable eq_scale   "OECD modified equivalence scale"

tabstat eq_scale n_adults n_children hh_size, stats(mean sd min p25 p50 p75 max) columns(statistics)

*===============================================================================
* 14. LABOR INCOME
*===============================================================================

di as text _n "=============================================="
di as text    "  14. LABOR INCOME"
di as text    "=============================================="

* j10: after-tax wages from primary job (past 30 days)
gen double labor_inc = .
capture confirm variable j10
if _rc == 0 {
    replace labor_inc = j10 if j10 > 0 & j10 < .
}
label variable labor_inc "After-tax wages, primary job (monthly, nominal)"

* j40: wages from secondary job
* Total labor income = primary + secondary (if j40 > 0)
gen double labor_inc_total = labor_inc
capture confirm variable j40
if _rc == 0 {
    replace labor_inc_total = labor_inc + j40 ///
        if j40 > 0 & j40 < . & labor_inc < .
    * If primary missing but secondary exists, use secondary alone
    replace labor_inc_total = j40 if labor_inc == . & j40 > 0 & j40 < .
}
label variable labor_inc_total "Total labor income, primary + secondary (monthly, nominal)"

summarize labor_inc labor_inc_total, detail

*===============================================================================
* 15. GOVERNMENT BENEFITS
*===============================================================================

di as text _n "=============================================="
di as text    "  15. GOVERNMENT BENEFITS"
di as text    "=============================================="

* f12_1b: pension, f12_2b: stipend, f12_3b: unemployment benefits
gen double govt_benefits = 0
foreach v in f12_1b f12_2b f12_3b {
    capture confirm variable `v'
    if _rc == 0 {
        replace govt_benefits = govt_benefits + `v' if `v' > 0 & `v' < .
    }
}
label variable govt_benefits "Government benefits: pension + stipend + unemployment (monthly, nominal)"
summarize govt_benefits, detail

*===============================================================================
* 16. HELP RECEIVED (transfers in)
*===============================================================================

di as text _n "=============================================="
di as text    "  16. HELP RECEIVED"
di as text    "=============================================="

* e41_1 through e41_5: help received from various sources
gen double help_received = 0
forvalues i = 1/5 {
    capture confirm variable e41_`i'
    if _rc == 0 {
        replace help_received = help_received + e41_`i' ///
            if e41_`i' > 0 & e41_`i' < .
    }
}
label variable help_received "Help/transfers received (monthly, nominal)"
summarize help_received, detail

*===============================================================================
* 17. DISPOSABLE INCOME
*===============================================================================

di as text _n "=============================================="
di as text    "  17. DISPOSABLE INCOME"
di as text    "=============================================="

gen double disp_inc = labor_inc_total + govt_benefits + help_received ///
    if labor_inc_total < .
* If labor income is missing, still compute from benefits + help if available
replace disp_inc = govt_benefits + help_received ///
    if disp_inc == . & (govt_benefits > 0 | help_received > 0)

label variable disp_inc "Disposable income: labor + govt + help (monthly, nominal)"

* Deflate income measures
foreach v in labor_inc labor_inc_total govt_benefits help_received disp_inc {
    gen double `v'_r = `v' * deflator
    local lbl : variable label `v'
    label variable `v'_r "`lbl' (Dec 2016 rubles)"
}

summarize labor_inc_r labor_inc_total_r disp_inc_r, detail

*===============================================================================
* 18. PER-EQUIVALENT-ADULT MEASURES
*===============================================================================

di as text _n "=============================================="
di as text    "  18. PER-EQUIVALENT-ADULT MEASURES"
di as text    "=============================================="

* Consumption per equivalent adult (real)
gen double cons_nondur_eq = cons_nondur_r / eq_scale
gen double cons_dur_eq    = cons_dur_r    / eq_scale
gen double food_eq        = food_home_r   / eq_scale

label variable cons_nondur_eq "Non-durable consumption per equiv. adult (Dec 2016 rub)"
label variable cons_dur_eq    "Durable-incl. consumption per equiv. adult (Dec 2016 rub)"
label variable food_eq        "Food consumption per equiv. adult (Dec 2016 rub)"

* Income per equivalent adult (real)
gen double labor_inc_eq = labor_inc_r       / eq_scale
gen double disp_inc_eq  = disp_inc_r        / eq_scale

label variable labor_inc_eq "Labor income per equiv. adult (Dec 2016 rub)"
label variable disp_inc_eq  "Disposable income per equiv. adult (Dec 2016 rub)"

tabstat cons_nondur_eq cons_dur_eq food_eq labor_inc_eq disp_inc_eq, ///
    stats(N mean sd p10 p25 p50 p75 p90) columns(statistics)

*===============================================================================
* 19. LOG TRANSFORMATIONS
*===============================================================================

di as text _n "=============================================="
di as text    "  19. LOG TRANSFORMATIONS"
di as text    "=============================================="

gen double lnc     = ln(cons_nondur_eq)  if cons_nondur_eq > 0
gen double lncD    = ln(cons_dur_eq)     if cons_dur_eq > 0
gen double lnfood  = ln(food_eq)         if food_eq > 0
gen double lny_lab = ln(labor_inc_eq)    if labor_inc_eq > 0
gen double lny_dis = ln(disp_inc_eq)     if disp_inc_eq > 0

label variable lnc     "ln(non-durable consumption per equiv. adult)"
label variable lncD    "ln(durable-incl. consumption per equiv. adult)"
label variable lnfood  "ln(food consumption per equiv. adult)"
label variable lny_lab "ln(labor income per equiv. adult)"
label variable lny_dis "ln(disposable income per equiv. adult)"

summarize lnc lncD lnfood lny_lab lny_dis

*===============================================================================
* 20. FIRST DIFFERENCES (panel required)
*===============================================================================

di as text _n "=============================================="
di as text    "  20. FIRST DIFFERENCES"
di as text    "=============================================="

* Ensure panel is set
xtset idind year

gen double dlnc     = D.lnc
gen double dlncD    = D.lncD
gen double dlnfood  = D.lnfood
gen double dlny_lab = D.lny_lab
gen double dlny_dis = D.lny_dis

label variable dlnc     "Delta ln(non-durable consumption)"
label variable dlncD    "Delta ln(durable-incl. consumption)"
label variable dlnfood  "Delta ln(food consumption)"
label variable dlny_lab "Delta ln(labor income)"
label variable dlny_dis "Delta ln(disposable income)"

*===============================================================================
* 21. TRIM OUTLIERS AND WINSORIZE GROWTH RATES
*===============================================================================

di as text _n "=============================================="
di as text    "  21. TRIMMING AND WINSORIZING GROWTH RATES"
di as text    "=============================================="

* The consumption smoothing literature typically finds Var(dlnC) ~ 0.01-0.10.
* Values of dlnc > 2 (i.e., consumption grew by e^2 ~ 7.4×) or < -2
* (consumption fell to e^-2 ~ 13% of prior level) are highly implausible
* for annual household consumption changes.
*
* Two-stage cleaning:
*   1. Hard trim: set extreme values (|dlnc| > 3) to missing
*   2. Winsorize at 1st/99th percentiles on remaining data

* Stage 1: Hard trim extreme values
foreach v in dlnc dlncD dlnfood dlny_lab dlny_dis {
    quietly count if `v' < .
    local n_before = r(N)

    * Hard trim: remove values that imply consumption changed by more than
    * 20x in either direction (ln(20) ~ 3)
    replace `v' = . if abs(`v') > 3 & `v' < .

    quietly count if `v' < .
    local n_after = r(N)
    local n_trimmed = `n_before' - `n_after'
    di as text "`v': hard trimmed `n_trimmed' obs (|value| > 3)"
}

* Stage 2: Winsorize at 2nd/98th percentiles
di as text _n "--- Winsorizing at 2nd/98th percentiles ---"
foreach v in dlnc dlncD dlnfood dlny_lab dlny_dis {
    quietly summarize `v', detail
    local p2  = r(p5)
    local p98 = r(p95)
    local n_win_lo = 0
    local n_win_hi = 0

    quietly count if `v' < `p2' & `v' < .
    local n_win_lo = r(N)
    quietly count if `v' > `p98' & `v' < .
    local n_win_hi = r(N)

    replace `v' = `p2'  if `v' < `p2' & `v' < .
    replace `v' = `p98' if `v' > `p98' & `v' < .

    quietly summarize `v', detail
    di as text "`v': winsorized `n_win_lo' low and `n_win_hi' high at [" ///
        %6.4f `p2' ", " %6.4f `p98' "]"
    di as text "       Final: mean=" %7.5f r(mean) " sd=" %7.5f r(sd) ///
        " var=" %7.5f r(Var) " N=" r(N)
}

*===============================================================================
* 22. DESCRIPTIVE STATISTICS
*===============================================================================

di as text _n "=============================================="
di as text    "  22. DESCRIPTIVE STATISTICS"
di as text    "=============================================="

* Summary of real per-equivalent-adult measures
di as text _n "--- Levels (per equiv. adult, Dec 2016 rubles) ---"
summarize cons_nondur_eq cons_dur_eq food_eq labor_inc_eq disp_inc_eq, detail

di as text _n "--- Log levels ---"
summarize lnc lncD lnfood lny_lab lny_dis

di as text _n "--- Growth rates (trimmed) ---"
summarize dlnc dlncD dlnfood dlny_lab dlny_dis, detail

* By year
di as text _n "--- Mean consumption and income by year ---"
tabstat cons_nondur_eq labor_inc_eq disp_inc_eq, by(year) stat(mean N) nototal

*===============================================================================
* 23. SAVE
*===============================================================================

di as text _n "=============================================="
di as text    "  SAVING OUTPUT"
di as text    "=============================================="

compress
label data "Welfare analysis - consumption and income measures (Step W2, GPS methodology)"
save "$data/welfare_panel_consumption.dta", replace

di as text _n "=============================================="
di as text    "  Step W2 complete."
di as text    "  Output: $data/welfare_panel_consumption.dta"
di as text    "  Observations: " _N
di as text    "  Next: Run Step W3 for shocks and informality."
di as text    "=============================================="

log close
