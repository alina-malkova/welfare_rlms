/*==============================================================================
  Step W1 - Build welfare analysis panel

  Project : Welfare Cost of Labor Informality
  Data    : RLMS-HSE 1994-2023 (combined long-format DTA files)
  Author  : A. Malkova

  Purpose : (1) Load individual-level combined DTA, keep relevant variables
            (2) Load household-level combined DTA, keep relevant variables
            (3) Merge IND and HH on id_h x year  (m:1)
            (4) Restrict to prime-age workers (20-59), years 2004-2023
            (5) xtset the panel and save welfare_panel_raw.dta

  Input   : ${ind_combined}  (RLMS_IND_1994_2023_eng_dta.dta, ~10 GB)
            ${hh_combined}   (RLMS_HH_1994_2023_eng_dta.dta, ~2.5 GB)

  Output  : ${data}/ind_variables.dta
            ${data}/hh_variables.dta
            ${data}/welfare_panel_raw.dta

  Notes   : Both source files are already in LONG format.
            id_w encodes the survey year; we rename it to "year".
            set maxvar 32767 is required throughout.
==============================================================================*/

* ============================================================================ *
*   0.  INITIALISE: GLOBALS, LOG, SETTINGS
* ============================================================================ *

do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close _all
local today : display %tdCYND date(c(current_date), "DMY")
local today = trim("`today'")
log using "${logdir}/W1_build_panel_`today'.log", replace text name(w1)

display as result _n "===== Step W1 - Build welfare analysis panel =====" _n
display as result "Run date : `c(current_date)'  `c(current_time)'"

timer clear
timer on 1


* ============================================================================ *
*                                                                              *
*   PART A :  INDIVIDUAL-LEVEL VARIABLES                                       *
*                                                                              *
* ============================================================================ *

display as result _n(2) "=============================================="
display as result "  PART A : Loading individual-level data"
display as result "=============================================="

* ---------------------------------------------------------------------------- *
*   A1.  Define the variables we want to keep
* ---------------------------------------------------------------------------- *

/*  We request a targeted load (use ... using) to avoid reading all ~10 GB
    into memory.  If any variable does not exist Stata will error on the
    targeted load, so we wrap in capture and fall back to load-all + keep.  */

#delimit ;
local ind_vars
    /* identifiers */
    idind id_h id_w

    /* demographics */
    age h5 educ marst status region psu site

    /* employment / informality */
    j1              /* work status (employed, etc.) */
    j10             /* after-tax wages last 30 days, primary job */
    j10_1           /* % of j10 officially registered */
    j10_3           /* all money transferred officially? */
    j11             /* enterprise type */
    j11_1           /* officially employed? -- KEY informality variable */
    j14             /* owed money / wage arrears */
    j6_2            /* usual hours per week */
    j8              /* hours worked last 30 days */
    j40             /* wages, secondary job */
    j60             /* total individual income last 30 days */
    j60_1           /* ever started own business */

    /* health */
    m3              /* self-assessed health evaluation */
    m20             /* needs help dressing/eating */
;
#delimit cr

* ---------------------------------------------------------------------------- *
*   A2.  Attempt targeted load
* ---------------------------------------------------------------------------- *

display as result _n "Attempting targeted load of individual variables ..."

capture noisily {
    use `ind_vars' using "${ind_combined}", clear
}
local rc_targeted = _rc

* ---------------------------------------------------------------------------- *
*   A3.  Fallback: load full file and keep
* ---------------------------------------------------------------------------- *

if `rc_targeted' != 0 {
    display as result _n "Targeted load returned rc = `rc_targeted'."
    display as result "Falling back: loading full file, then keeping relevant vars." _n

    use "${ind_combined}", clear

    * Build keep list -- only variables that actually exist
    local keepvars ""
    foreach v of local ind_vars {
        capture confirm variable `v'
        if _rc == 0 {
            local keepvars "`keepvars' `v'"
        }
        else {
            display as text "  note: variable `v' not found in IND file -- skipped"
        }
    }

    * Also grab any j69* variables (job separation reasons)
    capture noisily {
        ds j69*
        if "`r(varlist)'" != "" {
            local keepvars "`keepvars' `r(varlist)'"
            display as result "  Found j69* variables: `r(varlist)'"
        }
    }

    keep `keepvars'
}

* ---------------------------------------------------------------------------- *
*   A4.  Try to add j69* variables (job separation) if targeted load succeeded
* ---------------------------------------------------------------------------- *

if `rc_targeted' == 0 {
    display as result _n "Checking for j69* variables (job separation) ..."

    * Try a second targeted load of just j69* + keys, then merge
    preserve
    capture noisily {
        use idind id_w j69* using "${ind_combined}", clear
        tempfile j69data
        save `j69data', replace
    }
    local has_j69 = (_rc == 0)
    restore

    if `has_j69' {
        display as result "  Found j69* variables -- merging in."
        merge 1:1 idind id_w using `j69data', nogenerate
    }
    else {
        display as result "  No j69* variables found -- continuing without."
    }
}

* ---------------------------------------------------------------------------- *
*   A5.  Convert id_w (wave number) to calendar year
* ---------------------------------------------------------------------------- *

/*  IMPORTANT: id_w in the RLMS combined files contains WAVE NUMBERS (3-32),
    not calendar years.  The displayed values (1994, 1995, ...) are VALUE LABELS.
    Stata's compress converted id_w to byte because values fit in 0-255.
    We must convert wave numbers to calendar years for proper filtering.     */

display as result _n "Converting id_w (wave number) to calendar year ..."

capture confirm variable id_w
if _rc == 0 {
    * Check what id_w actually contains
    summarize id_w, meanonly
    local id_w_max = r(max)
    local id_w_min = r(min)
    display as result "  id_w range: `id_w_min' to `id_w_max'"

    if `id_w_max' < 100 {
        * Values are wave numbers -- convert to calendar years
        display as result "  Detected wave numbers -- converting to calendar years"

        rename id_w wave
        label variable wave "RLMS round/wave number"

        * Create calendar year using RLMS round-to-year mapping
        generate int year = .
        replace year = 1994 if wave == 3 | wave == 4
        replace year = 1995 if wave == 5
        replace year = 1996 if wave == 6
        replace year = 1998 if wave == 7 | wave == 8
        replace year = 2000 if wave == 9
        replace year = 2001 if wave == 10
        replace year = 2002 if wave == 11
        replace year = 2003 if wave == 12
        replace year = 2004 if wave == 13
        replace year = 2005 if wave == 14
        replace year = 2006 if wave == 15
        replace year = 2007 if wave == 16
        replace year = 2008 if wave == 17
        replace year = 2009 if wave == 18
        replace year = 2010 if wave == 19
        replace year = 2011 if wave == 20
        replace year = 2012 if wave == 21
        replace year = 2013 if wave == 22
        replace year = 2014 if wave == 23
        replace year = 2015 if wave == 24
        replace year = 2016 if wave == 25
        replace year = 2017 if wave == 26
        replace year = 2018 if wave == 27
        replace year = 2019 if wave == 28
        replace year = 2020 if wave == 29
        replace year = 2021 if wave == 30
        replace year = 2022 if wave == 31
        replace year = 2023 if wave == 32

        label variable year "Survey year (calendar)"

        * Verify conversion
        display as result _n "  Year distribution after conversion:"
        tabulate year, missing

        * Check for unmapped waves
        count if missing(year)
        if r(N) > 0 {
            display as result "  Note: `r(N)' obs with unmapped wave numbers"
            tabulate wave if missing(year)
        }
    }
    else {
        * Values appear to be calendar years already
        display as result "  id_w appears to contain calendar years already"
        rename id_w year
        label variable year "Survey year"
    }
}
else {
    display as error "ERROR: id_w not found in individual data."
    error 111
}

* ---------------------------------------------------------------------------- *
*   A6.  Create female indicator from h5 (gender)
* ---------------------------------------------------------------------------- *

display as result "Creating female indicator from h5 ..."

capture confirm variable h5
if _rc == 0 {
    /*  h5 is labeled:  1 = MALE,  2 = FEMALE  (standard RLMS coding)  */
    generate byte female = (h5 == 2) if !missing(h5)

    label variable female "Female (1 = female, 0 = male)"
    label define female_lbl 0 "Male" 1 "Female"
    label values female female_lbl

    * Verification
    tabulate h5 female, missing
}
else {
    display as text "  note: variable h5 (gender) not found -- female not created"
}

* ---------------------------------------------------------------------------- *
*   A7.  Report variable availability
* ---------------------------------------------------------------------------- *

display as result _n "--- Individual variables kept ---"
describe, short
display as result ""
describe, simple

* ---------------------------------------------------------------------------- *
*   A7b. Deduplicate individuals surveyed multiple times in same year
* ---------------------------------------------------------------------------- *

/*  RLMS has two rounds in some years (1994: waves 3,4 and 1998: waves 7,8).
    When we map wave to year, individuals surveyed in both rounds get duplicate
    idind + year combinations.  For xtset to work, we need unique idind + year.
    We keep only the later wave (more recent survey).                         */

display as result _n "Checking for duplicate individual-years ..."

duplicates report idind year
local n_dup = r(N) - r(unique_value)

if `n_dup' > 0 {
    display as result "  Found `n_dup' duplicate individual-year observations"
    display as result "  Keeping only the later wave (more recent survey) per individual-year"

    bysort idind year (wave): keep if _n == _N

    display as result "  After deduplication: `= _N' observations"
}
else {
    display as result "  No duplicate individual-years found"
}

* ---------------------------------------------------------------------------- *
*   A8.  Compress and save individual extract
* ---------------------------------------------------------------------------- *

display as result _n "Compressing and saving ind_variables.dta ..."
compress
save "${data}/ind_variables.dta", replace

display as result "  Saved : ${data}/ind_variables.dta"
display as result "  Obs   : `= _N'"
display as result "  Vars  : `= c(k)'"


* ============================================================================ *
*                                                                              *
*   PART B :  HOUSEHOLD-LEVEL VARIABLES                                        *
*                                                                              *
* ============================================================================ *

display as result _n(2) "=============================================="
display as result "  PART B : Loading household-level data"
display as result "=============================================="

* ---------------------------------------------------------------------------- *
*   B1.  Load the combined household file (full load, then keep)
* ---------------------------------------------------------------------------- *

/*  The HH file has 2,011 variables including 57+ food items (e1_Nc) and
    many expenditure sub-items.  Because the variable names contain wildcards
    (e1_*c, e7_*, etc.) a targeted "use ... using" cannot capture them
    reliably.  We load the full file (~2.5 GB) and then keep.             */

display as result _n "Loading full household file ..."

use "${hh_combined}", clear

display as result "  Loaded: `= _N' observations, `= c(k)' variables"

* ---------------------------------------------------------------------------- *
*   B2.  Convert id_w (wave number) to calendar year
* ---------------------------------------------------------------------------- *

/*  Same conversion as Part A: id_w contains wave numbers, not calendar years.  */

display as result _n "Converting id_w (wave number) to calendar year ..."

capture confirm variable id_w
if _rc == 0 {
    * Check what id_w actually contains
    summarize id_w, meanonly
    local id_w_max = r(max)
    local id_w_min = r(min)
    display as result "  id_w range: `id_w_min' to `id_w_max'"

    if `id_w_max' < 100 {
        * Values are wave numbers -- convert to calendar years
        display as result "  Detected wave numbers -- converting to calendar years"

        rename id_w wave
        label variable wave "RLMS round/wave number"

        * Create calendar year using RLMS round-to-year mapping
        generate int year = .
        replace year = 1994 if wave == 3 | wave == 4
        replace year = 1995 if wave == 5
        replace year = 1996 if wave == 6
        replace year = 1998 if wave == 7 | wave == 8
        replace year = 2000 if wave == 9
        replace year = 2001 if wave == 10
        replace year = 2002 if wave == 11
        replace year = 2003 if wave == 12
        replace year = 2004 if wave == 13
        replace year = 2005 if wave == 14
        replace year = 2006 if wave == 15
        replace year = 2007 if wave == 16
        replace year = 2008 if wave == 17
        replace year = 2009 if wave == 18
        replace year = 2010 if wave == 19
        replace year = 2011 if wave == 20
        replace year = 2012 if wave == 21
        replace year = 2013 if wave == 22
        replace year = 2014 if wave == 23
        replace year = 2015 if wave == 24
        replace year = 2016 if wave == 25
        replace year = 2017 if wave == 26
        replace year = 2018 if wave == 27
        replace year = 2019 if wave == 28
        replace year = 2020 if wave == 29
        replace year = 2021 if wave == 30
        replace year = 2022 if wave == 31
        replace year = 2023 if wave == 32

        label variable year "Survey year (calendar)"

        * Brief verification
        display as result _n "  HH year distribution:"
        tabulate year, missing
    }
    else {
        * Values appear to be calendar years already
        display as result "  id_w appears to contain calendar years already"
        rename id_w year
        label variable year "Survey year"
    }
}
else {
    display as error "ERROR: id_w not found in household data."
    error 111
}

* ---------------------------------------------------------------------------- *
*   B3.  Build keep list from available variables
* ---------------------------------------------------------------------------- *

display as result _n "Identifying variables to keep ..."

local hh_keep "id_h year"

* --- Food costs (weekly, 57+ items): e1_1c through e1_57c ------------------ *
capture noisily {
    ds e1_*c
    if "`r(varlist)'" != "" {
        local hh_keep "`hh_keep' `r(varlist)'"
        local n_food : word count `r(varlist)'
        display as result "  Food cost items (e1_*c)      : `n_food' variables"
    }
}

* --- Eating out: e2 (ate out?), e3 (cost 7d), e4 (cost 30d) ---------------- *
foreach v in e2 e3 e4 {
    capture confirm variable `v'
    if _rc == 0  local hh_keep "`hh_keep' `v'"
}

* --- Clothing: e5 (bought? 3m), e6 (cost 3m) ------------------------------- *
foreach v in e5 e6 {
    capture confirm variable `v'
    if _rc == 0  local hh_keep "`hh_keep' `v'"
}

* --- Durables: e7_* (amounts are in _b suffix, purchase flags in _a) -------- *
capture noisily {
    ds e7_*
    if "`r(varlist)'" != "" {
        local hh_keep "`hh_keep' `r(varlist)'"
        local n_dur : word count `r(varlist)'
        display as result "  Durable items (e7_*)         : `n_dur' variables"
    }
}

* --- Fuel: e8_*a (bought?), e8_*b (amount) --------------------------------- *
capture noisily {
    ds e8_*
    if "`r(varlist)'" != "" {
        local hh_keep "`hh_keep' `r(varlist)'"
        local n_fuel : word count `r(varlist)'
        display as result "  Fuel items (e8_*)            : `n_fuel' variables"
    }
}

* --- Services: e9_*a (used?), e9_*b (amount) ------------------------------- *
capture noisily {
    ds e9_*
    if "`r(varlist)'" != "" {
        local hh_keep "`hh_keep' `r(varlist)'"
        local n_svc : word count `r(varlist)'
        display as result "  Service items (e9_*)         : `n_svc' variables"
    }
}

* --- Rent / utilities: e10 (paid?), e11 (cost 30d), e12 (unpaid bills) ----- *
foreach v in e10 e11 e12 {
    capture confirm variable `v'
    if _rc == 0  local hh_keep "`hh_keep' `v'"
}

* --- Medical / other expenditures: e13_* ----------------------------------- *
capture noisily {
    ds e13_*
    if "`r(varlist)'" != "" {
        local hh_keep "`hh_keep' `r(varlist)'"
        local n_e13 : word count `r(varlist)'
        display as result "  Other expenditure (e13_*)    : `n_e13' variables"
    }
}

* --- Savings: e16 (saved? 30d), e17 (savings amount 30d) ------------------- *
foreach v in e16 e17 {
    capture confirm variable `v'
    if _rc == 0  local hh_keep "`hh_keep' `v'"
}

* --- Transfers given: e18 (gave?), e19_* (amounts by recipient) ------------- *
capture confirm variable e18
if _rc == 0  local hh_keep "`hh_keep' e18"

capture noisily {
    ds e19_*
    if "`r(varlist)'" != "" {
        local hh_keep "`hh_keep' `r(varlist)'"
    }
}

* --- Help received from family: e41_* -------------------------------------- *
capture noisily {
    ds e41_*
    if "`r(varlist)'" != "" {
        local hh_keep "`hh_keep' `r(varlist)'"
    }
}

* --- Income sources: f12_*a (received?), f12_*b (amount) ------------------- *
capture noisily {
    ds f12_*
    if "`r(varlist)'" != "" {
        local hh_keep "`hh_keep' `r(varlist)'"
        local n_f12 : word count `r(varlist)'
        display as result "  Income sources (f12_*)       : `n_f12' variables"
    }
}

* --- Credit new / loan received: f13_* ------------------------------------- *
capture noisily {
    ds f13_*
    if "`r(varlist)'" != "" {
        local hh_keep "`hh_keep' `r(varlist)'"
        local n_f13 : word count `r(varlist)'
        display as result "  Credit / loan vars (f13_*)   : `n_f13' variables"
    }
}

* --- Household income & credit/debt: f14 and f14_* ------------------------- *
foreach v in f14 f14_1 f14_2 f14_3 f14_6 f14_8 f14_9 f14_10 f14_11 {
    capture confirm variable `v'
    if _rc == 0 {
        local hh_keep "`hh_keep' `v'"
    }
    else {
        display as text "  note: variable `v' not found in HH file -- skipped"
    }
}

* ---------------------------------------------------------------------------- *
*   B3b. Deduplicate households surveyed multiple times in same year
* ---------------------------------------------------------------------------- *

/*  RLMS has two rounds in some years (1994: waves 3,4 and 1998: waves 7,8).
    When we map wave to year, households surveyed in both rounds get duplicate
    id_h + year combinations.  For the m:1 merge to work, HH must be unique
    by id_h + year.  We keep only the later wave (more recent survey).       */

display as result _n "Checking for duplicate household-years ..."

* First count duplicates
duplicates report id_h year
local n_dup = r(N) - r(unique_value)

if `n_dup' > 0 {
    display as result "  Found `n_dup' duplicate household-year observations"
    display as result "  Keeping only the later wave (more recent survey) per household-year"

    * Sort by id_h year wave and keep only the last observation per id_h year
    bysort id_h year (wave): keep if _n == _N

    display as result "  After deduplication: `= _N' observations"
}
else {
    display as result "  No duplicate household-years found"
}

* ---------------------------------------------------------------------------- *
*   B4.  Keep selected variables
* ---------------------------------------------------------------------------- *

display as result _n "Keeping selected household variables ..."

keep `hh_keep'

display as result "  Variables retained : `= c(k)'"
display as result "  Observations       : `= _N'"

* ---------------------------------------------------------------------------- *
*   B5.  Report variable availability
* ---------------------------------------------------------------------------- *

display as result _n "--- Household variables kept ---"
describe, short
display as result ""
describe, simple

* ---------------------------------------------------------------------------- *
*   B6.  Compress and save household extract
* ---------------------------------------------------------------------------- *

display as result _n "Compressing and saving hh_variables.dta ..."
compress
save "${data}/hh_variables.dta", replace

display as result "  Saved : ${data}/hh_variables.dta"
display as result "  Obs   : `= _N'"
display as result "  Vars  : `= c(k)'"


* ============================================================================ *
*                                                                              *
*   PART C :  MERGE INDIVIDUAL AND HOUSEHOLD DATA                              *
*                                                                              *
* ============================================================================ *

display as result _n(2) "=============================================="
display as result "  PART C : Merging IND and HH data"
display as result "=============================================="

* ---------------------------------------------------------------------------- *
*   C1.  Start from individual data (many-to-one merge)
* ---------------------------------------------------------------------------- *

use "${data}/ind_variables.dta", clear

display as result _n "Individual data loaded: `= _N' obs, `= c(k)' vars"

* ---------------------------------------------------------------------------- *
*   C2.  Merge with household data on id_h year (m:1)
* ---------------------------------------------------------------------------- *

/*  Multiple individuals can belong to the same household-year,
    so the merge is m:1 from the individual side.  We keep
    master-only and matched obs (drop HH-only).                  */

display as result _n "Merging with household data (m:1 on id_h year) ..."

merge m:1 id_h year using "${data}/hh_variables.dta", ///
    keep(master match) generate(_merge_hh)

display as result _n "--- Merge results ---"
tabulate _merge_hh

* Summarise merge quality
count if _merge_hh == 3
local n_matched = r(N)
count
local n_total = r(N)
display as result _n ///
    "  Matched : `n_matched' of `n_total' individual-year obs " ///
    "(" %5.1f 100 * `n_matched' / `n_total' "%)"

drop _merge_hh


* ============================================================================ *
*                                                                              *
*   PART D :  SAMPLE RESTRICTIONS                                              *
*                                                                              *
* ============================================================================ *

display as result _n(2) "=============================================="
display as result "  PART D : Sample restrictions"
display as result "=============================================="

local n_start = _N

* ---------------------------------------------------------------------------- *
*   D1.  Restrict to years 2004-2023 (rounds 13-32)
* ---------------------------------------------------------------------------- *

display as result _n "Restricting to years 2004-2023 ..."

keep if year >= 2004 & year <= 2023

local n_year = _N
display as result "  Dropped `= `n_start' - `n_year'' obs outside 2004-2023"
display as result "  Remaining: `n_year' obs"

* ---------------------------------------------------------------------------- *
*   D2.  Restrict to prime working age 20-59
* ---------------------------------------------------------------------------- *

display as result _n "Restricting to prime age 20-59 ..."

capture confirm variable age
if _rc == 0 {
    keep if age >= 20 & age <= 59 & !missing(age)
    local n_age = _N
    display as result "  Dropped `= `n_year' - `n_age'' obs outside age 20-59"
    display as result "  Remaining: `n_age' obs"
}
else {
    display as error "  WARNING: age variable not found -- no age restriction applied"
}

* ---------------------------------------------------------------------------- *
*   D3.  Report year distribution in analysis sample
* ---------------------------------------------------------------------------- *

display as result _n "--- Year distribution in analysis sample ---"
tabulate year

* ---------------------------------------------------------------------------- *
*   D4.  Report gender distribution
* ---------------------------------------------------------------------------- *

capture confirm variable female
if _rc == 0 {
    display as result _n "--- Gender distribution ---"
    tabulate female, missing
}

* ---------------------------------------------------------------------------- *
*   D5.  Report key informality variable availability
* ---------------------------------------------------------------------------- *

display as result _n "--- Key informality variable: j11_1 (officially employed?) ---"

capture confirm variable j11_1
if _rc == 0 {
    tabulate j11_1, missing
    display as result _n "j11_1 availability by year:"
    tabulate year if !missing(j11_1)
}
else {
    display as text "  j11_1 not found in data."
}


* ============================================================================ *
*                                                                              *
*   PART E :  PANEL SETUP AND SAVE                                             *
*                                                                              *
* ============================================================================ *

display as result _n(2) "=============================================="
display as result "  PART E : Panel setup and save"
display as result "=============================================="

* ---------------------------------------------------------------------------- *
*   E1.  Set panel structure:  xtset idind year
* ---------------------------------------------------------------------------- *

display as result _n "Setting panel: xtset idind year ..."

capture confirm variable idind
if _rc == 0 {
    /*  Within 2004-2023 rounds are annual, so delta = 1.
        Earlier rounds had gaps (e.g. 1996, 1998) but those
        have been dropped in section D1.                      */
    xtset idind year, yearly

    display as result _n "--- Panel summary (xtdescribe) ---"
    xtdescribe
}
else {
    display as error "ERROR: idind not found -- cannot xtset."
    error 111
}

* ---------------------------------------------------------------------------- *
*   E2.  Final variable summary
* ---------------------------------------------------------------------------- *

display as result _n "--- Final dataset summary ---"
describe, short

display as result _n "--- Variable list ---"
describe, simple

* ---------------------------------------------------------------------------- *
*   E3.  Compress and save
* ---------------------------------------------------------------------------- *

display as result _n "Compressing and saving welfare_panel_raw.dta ..."

compress
label data "Welfare analysis panel -- raw (Step W1)"
save "${data}/welfare_panel_raw.dta", replace

display as result _n "  Saved : ${data}/welfare_panel_raw.dta"
display as result "  Obs   : `= _N'"
display as result "  Vars  : `= c(k)'"

* ---------------------------------------------------------------------------- *
*   E4.  Timer and wrap up
* ---------------------------------------------------------------------------- *

timer off 1
timer list

display as result _n(2) "=============================================="
display as result "  Step W1 complete."
display as result "  Output files:"
display as result "    ${data}/ind_variables.dta"
display as result "    ${data}/hh_variables.dta"
display as result "    ${data}/welfare_panel_raw.dta"
display as result "  Next: run Step W2 - Consumption and income measures.do"
display as result "=============================================="

log close w1

* end of Step W1
