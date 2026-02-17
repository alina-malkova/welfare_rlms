/*==============================================================================
    Step W4e - Mechanism Tests for Referees

    1. Direct transfer mechanism test (receive/give transfers)
    2. Alternative informality definitions (contract, firm size, pension, self-emp)
    3. Wealth/asset interaction
    4. Hours response test

    Author: Claude
    Date: February 2025
==============================================================================*/

clear all
set more off
capture set maxvar 32767

* Set paths
global datadir "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Data"
global outdir "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Tables"

* Load the analysis dataset
use "$datadir/welfare_panel_shocks.dta", clear

* Basic setup
xtset idind year

* Create key variables
gen double dlny_pos = max(dlny_lab, 0) if dlny_lab < .
gen double dlny_neg = min(dlny_lab, 0) if dlny_lab < .
gen double dlny_pos_x_inf = dlny_pos * informal
gen double dlny_neg_x_inf = dlny_neg * informal

gen byte neg_shock = (dlny_lab < -0.10) if dlny_lab < .
gen byte pos_shock = (dlny_lab > 0.10) if dlny_lab < .
gen byte neg_shock_x_inf = neg_shock * informal
gen byte pos_shock_x_inf = pos_shock * informal

*==============================================================================
* 1. DIRECT TRANSFER MECHANISM TEST
*==============================================================================
di _n "==========================================================================="
di "1. TRANSFER MECHANISM TEST"
di "==========================================================================="

* Check what transfer variables exist
capture describe *transfer* *help* *money* *give* *receive*

* List variable names that might be transfers
di _n "Looking for transfer-related variables..."
quietly describe, varlist
local allvars `r(varlist)'

foreach v of local allvars {
    local vlow = lower("`v'")
    if strpos("`vlow'", "help") | strpos("`vlow'", "transfer") | strpos("`vlow'", "give") | strpos("`vlow'", "receiv") {
        di "`v'"
    }
}

* Try common RLMS variable names for transfers
* RLMS uses: fXXhelp (help received), fXXgive (help given)
capture confirm variable help_received
if _rc {
    * Try to find it
    capture describe f*help*
    capture describe *help*
}

* If help_received exists, test it
capture {
    * Test: Do informal workers RECEIVE more transfers after negative shocks?
    di _n "--- Transfers Received After Negative Shock ---"
    regress help_received neg_shock informal neg_shock_x_inf i.year, cluster(idind)
    local b_recv_neg = _b[neg_shock_x_inf]
    local se_recv_neg = _se[neg_shock_x_inf]
    di "NegShock x Informal: " %7.4f `b_recv_neg' " (SE: " %6.4f `se_recv_neg' ")"
    di "If positive: informal workers receive MORE transfers after negative shocks"
    estimates store recv_neg
}

capture {
    * Test: Do informal workers GIVE more transfers after positive shocks?
    di _n "--- Transfers Given After Positive Shock ---"
    capture confirm variable help_given
    if !_rc {
        regress help_given pos_shock informal pos_shock_x_inf i.year, cluster(idind)
        local b_give_pos = _b[pos_shock_x_inf]
        local se_give_pos = _se[pos_shock_x_inf]
        di "PosShock x Informal: " %7.4f `b_give_pos' " (SE: " %6.4f `se_give_pos' ")"
        di "If positive: informal workers GIVE more transfers after positive shocks"
        estimates store give_pos
    }
}

* Test with regional vs idiosyncratic shocks
capture confirm variable shock_regional
capture confirm variable shock_job
if !_rc {
    di _n "--- Transfer Response: Regional vs Job Shocks ---"

    capture {
        gen byte reg_shock_x_inf = shock_regional * informal
        gen byte job_shock_x_inf = shock_job * informal

        * Regional shock - should activate network
        regress help_received shock_regional informal reg_shock_x_inf i.year, cluster(idind)
        di "Regional Shock x Informal: " %7.4f _b[reg_shock_x_inf] " (SE: " %6.4f _se[reg_shock_x_inf] ")"

        * Job shock - may not activate network as effectively
        regress help_received shock_job informal job_shock_x_inf i.year, cluster(idind)
        di "Job Shock x Informal: " %7.4f _b[job_shock_x_inf] " (SE: " %6.4f _se[job_shock_x_inf] ")"
    }
}

*==============================================================================
* 2. ALTERNATIVE INFORMALITY DEFINITIONS
*==============================================================================
di _n "==========================================================================="
di "2. ALTERNATIVE INFORMALITY DEFINITIONS"
di "==========================================================================="

* Check what variables we have for alternative definitions
di "Checking available variables for alternative definitions..."
capture describe *contract* *pension* *self* *firm* *size* *empsta* *empst* *regist*

* Initialize results
matrix alt_defs = J(5, 4, .)
matrix colnames alt_defs = delta_neg se_neg N significant
matrix rownames alt_defs = Main NoContract SmallFirm NoPension SelfEmp

* 1. Main definition (registration-based)
di _n "--- Definition 1: Main (Registration-based) ---"
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year, cluster(idind)
matrix alt_defs[1,1] = _b[dlny_neg_x_inf]
matrix alt_defs[1,2] = _se[dlny_neg_x_inf]
matrix alt_defs[1,3] = e(N)
matrix alt_defs[1,4] = (2*ttail(e(df_r), abs(_b[dlny_neg_x_inf]/_se[dlny_neg_x_inf])) < 0.05)
di "delta- = " %7.4f _b[dlny_neg_x_inf] " (SE: " %6.4f _se[dlny_neg_x_inf] ")"

* 2. No written contract
capture confirm variable j6
if !_rc {
    di _n "--- Definition 2: No Written Contract (j6) ---"
    * j6 in RLMS: 1=have contract, 2=no contract, 3=don't know
    capture drop inf_nocontract
    gen byte inf_nocontract = (j6 == 2) if j6 >= 1 & j6 <= 2

    capture drop pos_nc neg_nc
    gen double pos_nc = dlny_pos * inf_nocontract
    gen double neg_nc = dlny_neg * inf_nocontract

    regress dlnc dlny_pos dlny_neg inf_nocontract pos_nc neg_nc i.year, cluster(idind)
    matrix alt_defs[2,1] = _b[neg_nc]
    matrix alt_defs[2,2] = _se[neg_nc]
    matrix alt_defs[2,3] = e(N)
    matrix alt_defs[2,4] = (2*ttail(e(df_r), abs(_b[neg_nc]/_se[neg_nc])) < 0.05)
    di "delta- = " %7.4f _b[neg_nc] " (SE: " %6.4f _se[neg_nc] ")"
}

* Try alternative contract variable names
capture confirm variable contract
if !_rc {
    di _n "--- Definition 2: No Written Contract (contract) ---"
    capture drop inf_nocontract pos_nc neg_nc
    gen byte inf_nocontract = (contract == 0) if contract < .
    gen double pos_nc = dlny_pos * inf_nocontract
    gen double neg_nc = dlny_neg * inf_nocontract

    regress dlnc dlny_pos dlny_neg inf_nocontract pos_nc neg_nc i.year, cluster(idind)
    matrix alt_defs[2,1] = _b[neg_nc]
    matrix alt_defs[2,2] = _se[neg_nc]
    matrix alt_defs[2,3] = e(N)
    matrix alt_defs[2,4] = (2*ttail(e(df_r), abs(_b[neg_nc]/_se[neg_nc])) < 0.05)
    di "delta- = " %7.4f _b[neg_nc] " (SE: " %6.4f _se[neg_nc] ")"
}

* 3. Small firm (< 5 employees)
capture confirm variable j2
if !_rc {
    di _n "--- Definition 3: Small Firm (<5 employees, j2) ---"
    * j2 in RLMS is firm size categories
    capture drop inf_small pos_sf neg_sf
    gen byte inf_small = (j2 <= 2) if j2 >= 1 & j2 < .  // 1=1 person, 2=2-9 people

    gen double pos_sf = dlny_pos * inf_small
    gen double neg_sf = dlny_neg * inf_small

    regress dlnc dlny_pos dlny_neg inf_small pos_sf neg_sf i.year, cluster(idind)
    matrix alt_defs[3,1] = _b[neg_sf]
    matrix alt_defs[3,2] = _se[neg_sf]
    matrix alt_defs[3,3] = e(N)
    matrix alt_defs[3,4] = (2*ttail(e(df_r), abs(_b[neg_sf]/_se[neg_sf])) < 0.05)
    di "delta- = " %7.4f _b[neg_sf] " (SE: " %6.4f _se[neg_sf] ")"
}

capture confirm variable firmsize
if !_rc {
    di _n "--- Definition 3: Small Firm (<5 employees) ---"
    capture drop inf_small pos_sf neg_sf
    gen byte inf_small = (firmsize < 5) if firmsize < .
    gen double pos_sf = dlny_pos * inf_small
    gen double neg_sf = dlny_neg * inf_small

    regress dlnc dlny_pos dlny_neg inf_small pos_sf neg_sf i.year, cluster(idind)
    matrix alt_defs[3,1] = _b[neg_sf]
    matrix alt_defs[3,2] = _se[neg_sf]
    matrix alt_defs[3,3] = e(N)
    matrix alt_defs[3,4] = (2*ttail(e(df_r), abs(_b[neg_sf]/_se[neg_sf])) < 0.05)
    di "delta- = " %7.4f _b[neg_sf] " (SE: " %6.4f _se[neg_sf] ")"
}

* 4. Not contributing to pension
capture confirm variable j60
if !_rc {
    di _n "--- Definition 4: No Pension Contribution (j60) ---"
    * j60 in RLMS: employer pension contributions
    capture drop inf_nopens pos_np neg_np
    gen byte inf_nopens = (j60 == 2 | j60 == 5) if j60 >= 1 & j60 <= 5  // 2=no, 5=don't know

    gen double pos_np = dlny_pos * inf_nopens
    gen double neg_np = dlny_neg * inf_nopens

    regress dlnc dlny_pos dlny_neg inf_nopens pos_np neg_np i.year, cluster(idind)
    matrix alt_defs[4,1] = _b[neg_np]
    matrix alt_defs[4,2] = _se[neg_np]
    matrix alt_defs[4,3] = e(N)
    matrix alt_defs[4,4] = (2*ttail(e(df_r), abs(_b[neg_np]/_se[neg_np])) < 0.05)
    di "delta- = " %7.4f _b[neg_np] " (SE: " %6.4f _se[neg_np] ")"
}

* 5. Self-employed
capture confirm variable j1
if !_rc {
    di _n "--- Definition 5: Self-Employed (j1) ---"
    * j1 in RLMS: employment status, self-employed categories
    capture drop inf_selfemp pos_se neg_se
    gen byte inf_selfemp = (j1 >= 4 & j1 <= 6) if j1 >= 1 & j1 < .  // self-employed categories

    gen double pos_se = dlny_pos * inf_selfemp
    gen double neg_se = dlny_neg * inf_selfemp

    count if inf_selfemp == 1
    if r(N) > 100 {
        regress dlnc dlny_pos dlny_neg inf_selfemp pos_se neg_se i.year, cluster(idind)
        matrix alt_defs[5,1] = _b[neg_se]
        matrix alt_defs[5,2] = _se[neg_se]
        matrix alt_defs[5,3] = e(N)
        matrix alt_defs[5,4] = (2*ttail(e(df_r), abs(_b[neg_se]/_se[neg_se])) < 0.05)
        di "delta- = " %7.4f _b[neg_se] " (SE: " %6.4f _se[neg_se] ")"
    }
}

* Display results matrix
di _n "ALTERNATIVE DEFINITIONS SUMMARY"
di "==========================================================================="
matrix list alt_defs, format(%8.4f)

* Export
esttab matrix(alt_defs) using "$outdir/W4e_2_alt_definitions.csv", replace ///
    title("Alternative Informality Definitions - Asymmetric Response (delta-)")

*==============================================================================
* 3. WEALTH/ASSET INTERACTION
*==============================================================================
di _n "==========================================================================="
di "3. WEALTH/ASSET INTERACTION"
di "==========================================================================="

* Check for wealth/asset variables in RLMS
* Common RLMS variables: f14 (savings), h5 (housing ownership), durables
capture describe *sav* *asset* *wealth* *own* *property*

* Try to identify households with assets
capture confirm variable has_savings
if _rc {
    * Try to create from available variables
    * Look for savings question
    capture confirm variable f14
    if !_rc {
        di "Using f14 (savings indicator)"
        gen byte has_assets = (f14 == 1) if f14 >= 1 & f14 <= 2
    }
}
else {
    gen byte has_assets = has_savings
}

* If we have assets variable, run the interaction
capture confirm variable has_assets
if !_rc {
    di _n "--- Asymmetry by Asset Status ---"

    gen byte neg_inf_asset = dlny_neg_x_inf * has_assets

    regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
        has_assets c.dlny_neg#c.has_assets neg_inf_asset i.year, cluster(idind)

    di _n "Key coefficient: ΔY⁻ × Informal × HasAssets"
    di "If phi < 0: informal penalty is SMALLER for those with assets"
    di "Coefficient: " %7.4f _b[neg_inf_asset] " (SE: " %6.4f _se[neg_inf_asset] ")"

    estimates store wealth_int
}

* Also try with credit constrained as proxy for no buffer
capture confirm variable credit_constrained
if !_rc {
    di _n "--- Asymmetry by Credit Constraint Status ---"

    capture drop neg_inf_cc
    gen byte neg_inf_cc = dlny_neg_x_inf * credit_constrained

    * Need to handle collinearity - create full set of interactions
    gen byte pos_inf_cc = dlny_pos_x_inf * credit_constrained
    gen double neg_cc = dlny_neg * credit_constrained
    gen double pos_cc = dlny_pos * credit_constrained

    regress dlnc dlny_pos dlny_neg informal credit_constrained ///
        dlny_pos_x_inf dlny_neg_x_inf ///
        pos_cc neg_cc ///
        pos_inf_cc neg_inf_cc ///
        i.year, cluster(idind)

    di "ΔY⁻ × Informal × CreditConstrained: " %7.4f _b[neg_inf_cc] " (SE: " %6.4f _se[neg_inf_cc] ")"
}

*==============================================================================
* 4. HOURS RESPONSE TEST
*==============================================================================
di _n "==========================================================================="
di "4. HOURS RESPONSE TEST"
di "==========================================================================="

* Check for hours variables
capture describe *hour* *hrs* *time* *work*

* RLMS typically has j8 (usual hours) or similar
capture confirm variable j8
if !_rc {
    di _n "--- Hours Response to Negative Shock (j8) ---"

    * Create change in hours
    capture drop dlnhours
    gen double dlnhours = ln(j8) - ln(L.j8) if j8 > 0 & L.j8 > 0

    regress dlnhours neg_shock informal neg_shock_x_inf i.year, cluster(idind)

    di "NegShock x Informal: " %7.4f _b[neg_shock_x_inf] " (SE: " %6.4f _se[neg_shock_x_inf] ")"
    di "If delta ≈ 0: informal workers don't compensate through hours"

    estimates store hours_resp
}

capture confirm variable hours
if !_rc {
    di _n "--- Hours Response to Negative Shock (hours) ---"

    capture drop dlnhours
    gen double dlnhours = ln(hours) - ln(L.hours) if hours > 0 & L.hours > 0

    regress dlnhours neg_shock informal neg_shock_x_inf i.year, cluster(idind)

    di "NegShock x Informal: " %7.4f _b[neg_shock_x_inf] " (SE: " %6.4f _se[neg_shock_x_inf] ")"

    estimates store hours_resp
}

* Also check for second job variable
capture confirm variable j22
if !_rc {
    di _n "--- Secondary Job Response (j22) ---"
    * j22: do you have a second job?

    gen byte has_secjob = (j22 == 1) if j22 >= 1 & j22 <= 2

    regress has_secjob neg_shock informal neg_shock_x_inf i.year, cluster(idind)

    di "NegShock x Informal: " %7.4f _b[neg_shock_x_inf] " (SE: " %6.4f _se[neg_shock_x_inf] ")"
    di "If positive: informal workers more likely to take second job after negative shock"
}

*==============================================================================
* SUMMARY
*==============================================================================
di _n _n "==========================================================================="
di "MECHANISM TESTS COMPLETE"
di "==========================================================================="
di _n "Output files:"
di "  $outdir/W4e_2_alt_definitions.csv"

log close _all
