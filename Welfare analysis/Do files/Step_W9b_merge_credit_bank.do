/*==============================================================================
  Step W9b - Merge Bank Access from Credit Market Workfile

  Purpose:  Merge bank access variables from the credit market paper (2006-2016)
            to dramatically extend the bank access analysis coverage

  From CLAUDE.md, credit market accessibility includes:
    (1) bank presence in community
    (2) distance to nearest Sberbank branch
    (3) distance to nearest other bank
    (4) regional bank branches per capita

  Input:    Comparative Economics/rlms_credit_workfile.dta
            Welfare analysis/Data/welfare_panel_cbr.dta
  Output:   Welfare analysis/Data/welfare_panel_extended_bank.dta
==============================================================================*/

clear all
set more off

global project "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)"
global credit "$project/Comparative Economics"
global welfare "$project/Welfare analysis"

capture log close
log using "$welfare/Logs/Step_W9b_credit_bank_merge.log", replace

*===============================================================================
* 1. EXPLORE CREDIT MARKET WORKFILE
*===============================================================================

di as text _n "=============================================="
di as text    "  Step 1: Explore Credit Market Workfile"
di as text    "=============================================="

use "$credit/rlms_credit_workfile.dta", clear
describe, short

* List all variable names to find bank-related ones
di _n "=== All variable names ==="
describe, varlist

* Try to identify bank/credit access variables by label search
di _n "=== Variables with 'bank' in label ==="
foreach v of varlist * {
    local lab : variable label `v'
    if regexm(lower("`lab'"), "bank") {
        di "`v': `lab'"
    }
}

di _n "=== Variables with 'sber' in label ==="
foreach v of varlist * {
    local lab : variable label `v'
    if regexm(lower("`lab'"), "sber") {
        di "`v': `lab'"
    }
}

di _n "=== Variables with 'credit' in label ==="
foreach v of varlist * {
    local lab : variable label `v'
    if regexm(lower("`lab'"), "credit") {
        di "`v': `lab'"
    }
}

di _n "=== Variables with 'distance' in label ==="
foreach v of varlist * {
    local lab : variable label `v'
    if regexm(lower("`lab'"), "distance") {
        di "`v': `lab'"
    }
}

di _n "=== Variables with 'branch' in label ==="
foreach v of varlist * {
    local lab : variable label `v'
    if regexm(lower("`lab'"), "branch") {
        di "`v': `lab'"
    }
}

* Check year coverage
di _n "=== Year coverage ==="
tab year

* Check if there's a composite credit market access index
di _n "=== Looking for CMA (credit market access) index ==="
capture ds *cma* *CMA* *access* *index*
if _rc == 0 {
    ds *cma* *CMA* *access* *index*
}

* Summary of potential variables
di _n "=== Summary of likely bank access variables ==="
* Try common variable name patterns
foreach pattern in "bankcom" "distbank" "distsber" "branchpc" "cma" {
    capture confirm variable `pattern'
    if _rc == 0 {
        sum `pattern', detail
    }
}

log close
