/*==============================================================================
  Step W9 - Merge CBR Regional Financial Infrastructure Data

  Project:  Welfare Cost of Labor Informality
  Purpose:  Merge regional-level banking data from Central Bank of Russia
            to construct Credit Market Accessibility (CMA) variables

  Input:    Data/CBR_data/bank_branches_annual.csv
            Data/welfare_panel_shocks.dta

  Output:   Data/welfare_panel_cbr.dta (panel with regional banking variables)

  Author:
  Created:  February 2026
==============================================================================*/

clear all
capture set maxvar 32767
do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close
log using "$logdir/Step_W9_cbr_merge.log", replace

*===============================================================================
* 1. LOAD AND PROCESS CBR BANK BRANCHES DATA
*===============================================================================

di as text _n "=============================================="
di as text    "  Loading CBR Bank Branches Data"
di as text    "=============================================="

import delimited "$data/CBR_data/bank_branches_annual.csv", clear

* Examine the data
describe
sum year bank_branches

* Count unique regions
quietly: egen tag = tag(region)
count if tag == 1
di "Number of unique CBR regions: `r(N)'"
drop tag

* Keep only actual regions (not federal districts or totals)
* Filter out aggregated rows
drop if strpos(region, "FEDERAL DISTRICT") > 0
drop if region == "Russian Federation"
drop if strpos(region, "including:") > 0
drop if real(region) != .  // Drop numeric-only rows

* Standardize region names for matching
gen region_std = lower(region)
replace region_std = subinstr(region_std, " region", "", .)
replace region_std = subinstr(region_std, " territory", "", .)
replace region_std = subinstr(region_std, " republic", "", .)
replace region_std = subinstr(region_std, "republic of ", "", .)
replace region_std = trim(region_std)

* Create regional ID based on common names
gen int region_id = .

* Moscow and St. Petersburg
replace region_id = 1 if region_std == "moscow"
replace region_id = 20 if region_std == "st. petersburg"

* Moscow and Leningrad Oblast
replace region_id = 2 if region_std == "moscow" & strpos(region, "Region") > 0
replace region_id = 21 if strpos(region_std, "leningrad") > 0

* Key regions (manually map to approximate RLMS region codes)
replace region_id = 30 if strpos(region_std, "krasnodar") > 0
replace region_id = 31 if strpos(region_std, "rostov") > 0
replace region_id = 50 if strpos(region_std, "tatarstan") > 0
replace region_id = 51 if strpos(region_std, "bashkortostan") > 0
replace region_id = 54 if strpos(region_std, "nizhni novgorod") > 0
replace region_id = 57 if strpos(region_std, "samara") > 0
replace region_id = 70 if strpos(region_std, "sverdlovsk") > 0
replace region_id = 71 if strpos(region_std, "chelyabinsk") > 0
replace region_id = 80 if strpos(region_std, "novosibirsk") > 0
replace region_id = 84 if strpos(region_std, "krasnoyarsk") > 0

* Additional regions
replace region_id = 3 if strpos(region_std, "belgorod") > 0
replace region_id = 4 if strpos(region_std, "voronezh") > 0
replace region_id = 10 if strpos(region_std, "smolensk") > 0
replace region_id = 11 if strpos(region_std, "tambov") > 0
replace region_id = 13 if strpos(region_std, "tula") > 0
replace region_id = 56 if strpos(region_std, "penza") > 0
replace region_id = 52 if strpos(region_std, "udmurt") > 0
replace region_id = 83 if strpos(region_std, "altai") > 0 & strpos(region_std, "republic") == 0
replace region_id = 85 if strpos(region_std, "irkutsk") > 0

* Keep only matched regions
keep if region_id != .

* Collapse to region-year level (in case of duplicates)
collapse (mean) bank_branches, by(region_id year)

rename region_id region

* Save CBR regional panel
tempfile cbr_panel
save `cbr_panel', replace

di "CBR panel saved with `=_N' region-year observations"

*===============================================================================
* 2. LOAD WELFARE PANEL
*===============================================================================

di as text _n "=============================================="
di as text    "  Loading Welfare Panel"
di as text    "=============================================="

use "$data/welfare_panel_shocks.dta", clear

* Check region variable
tab region, missing

* Verify we have analysis sample
count if analysis_sample == 1
di "Analysis sample size: `r(N)'"

*===============================================================================
* 3. MERGE CBR DATA
*===============================================================================

di as text _n "=============================================="
di as text    "  Merging CBR Data"
di as text    "=============================================="

merge m:1 region year using `cbr_panel', gen(_merge_cbr)

tab _merge_cbr
* Keep master (RLMS) observations even if no CBR match
drop if _merge_cbr == 2

di "Observations with CBR match: " _N - _N*(1-(_merge_cbr==3))

*===============================================================================
* 4. CONSTRUCT CREDIT MARKET ACCESSIBILITY VARIABLES
*===============================================================================

di as text _n "=============================================="
di as text    "  Constructing CMA Variables"
di as text    "=============================================="

* For regions without CBR data, impute regional mean
bysort region: egen bank_branches_mean = mean(bank_branches)
replace bank_branches = bank_branches_mean if bank_branches == .
drop bank_branches_mean

* Credit Market Accessibility index (standardized)
sum bank_branches if analysis_sample == 1
local m = r(mean)
local s = r(sd)
capture drop cma_index
gen double cma_index = (bank_branches - `m') / `s' if bank_branches != .
label variable cma_index "CMA index (standardized bank branches)"

* Binary high/low CMA (above/below median)
sum bank_branches if analysis_sample == 1, detail
local med = r(p50)
capture drop cma_high
gen byte cma_high = (bank_branches >= `med') if bank_branches != .
capture drop low_bank_access
gen byte low_bank_access = (cma_high == 0) if cma_high != .

label variable cma_high "High credit market accessibility (above median)"
label variable low_bank_access "Low bank access region (below median)"

*===============================================================================
* 5. CREATE INTERACTION TERMS FOR TRIPLE-DIFF
*===============================================================================

di as text _n "=============================================="
di as text    "  Creating Interaction Terms"
di as text    "=============================================="

* Ensure base variables exist
capture confirm variable dlny_lab
capture confirm variable informal
capture confirm variable dlny_neg

* Income change interactions with regional bank access
capture drop dlny_x_low_bank
gen double dlny_x_low_bank = dlny_lab * low_bank_access if dlny_lab != . & low_bank_access != .
label variable dlny_x_low_bank "Δln(Y) × Low bank access"

capture drop dlny_x_inf_x_low_bank
gen double dlny_x_inf_x_low_bank = dlny_lab * informal * low_bank_access
label variable dlny_x_inf_x_low_bank "Δln(Y) × Informal × Low bank access"

capture drop inf_x_low_bank
gen double inf_x_low_bank = informal * low_bank_access
label variable inf_x_low_bank "Informal × Low bank access"

* Negative income changes for asymmetric test
capture confirm variable dlny_neg
if _rc == 0 {
    capture drop dlny_neg_x_low_bank
    gen double dlny_neg_x_low_bank = dlny_neg * low_bank_access
    label variable dlny_neg_x_low_bank "Δln(Y)⁻ × Low bank access"

    capture drop dlny_neg_x_inf_x_low_bank
    gen double dlny_neg_x_inf_x_low_bank = dlny_neg * informal * low_bank_access
    label variable dlny_neg_x_inf_x_low_bank "Δln(Y)⁻ × Informal × Low bank access"
}

*===============================================================================
* 6. SUMMARY STATISTICS
*===============================================================================

di as text _n "=============================================="
di as text    "  Summary Statistics"
di as text    "=============================================="

* Regional banking variables
sum bank_branches cma_index cma_high low_bank_access if analysis_sample == 1

* By informality status
di _n "Bank access by informality status:"
bysort informal: sum bank_branches cma_high if analysis_sample == 1

* Cross-tabulation
di _n "Informal × Low Bank Access:"
tab informal low_bank_access if analysis_sample == 1, missing

*===============================================================================
* 7. SAVE MERGED DATASET
*===============================================================================

di as text _n "=============================================="
di as text    "  Saving Merged Dataset"
di as text    "=============================================="

compress

save "$data/welfare_panel_cbr.dta", replace

di as text "Dataset saved: $data/welfare_panel_cbr.dta"
di as text "Observations: `=_N'"

*===============================================================================
* 8. QUICK VALIDATION REGRESSION
*===============================================================================

di as text _n "=============================================="
di as text    "  Quick Validation: Triple-Diff Preview"
di as text    "=============================================="

* Check sample for triple-diff
count if analysis_sample == 1 & informal != . & low_bank_access != .
di "Complete observations for triple-diff: `r(N)'"

* Preview regression (if enough variation)
capture noisily {
    regress dlnc dlny_lab informal low_bank_access ///
        dlny_x_inf dlny_x_low_bank inf_x_low_bank dlny_x_inf_x_low_bank ///
        age age2 i.year if analysis_sample == 1, vce(cluster idind)
}

*===============================================================================
* DONE
*===============================================================================

di as text _n "=============================================="
di as text    "  Step W9 Complete"
di as text    "=============================================="
di as text "Output: $data/welfare_panel_cbr.dta"
di as text ""
di as text "New variables created:"
di as text "  - bank_branches"
di as text "  - cma_index, cma_high, low_bank_access"
di as text "  - dlny_x_low_bank, dlny_x_inf_x_low_bank"
di as text "  - dlny_neg_x_low_bank, dlny_neg_x_inf_x_low_bank"

log close
