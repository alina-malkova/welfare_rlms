/*==============================================================================
    Step W4d - Final Robustness Analyses

    1. Formal test of asymmetry (H0: delta+ = delta-)
    2. Heterogeneity in asymmetric response (urban/rural, male/female, age, educ)
    3. Transfer/network mechanism test
    4. Alternative informality definitions
    5. Loss aversion welfare calculation
    6. Hours/secondary job response
    7. Wealth/savings heterogeneity
    8. Event study figure
    9. Extended event window
    10. Regional variation

    Author: Claude
    Date: February 2025
==============================================================================*/

clear all
set more off
capture set maxvar 32767

* Set paths
global datadir "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Data"
global outdir "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Tables"
global figdir "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Figures"

* Create figures directory if needed
capture mkdir "$figdir"

* Load the analysis dataset
use "$datadir/welfare_panel_shocks.dta", clear

* Basic setup
xtset idind year

*==============================================================================
* 1. FORMAL TEST OF ASYMMETRY
*==============================================================================
di _n "==========================================================================="
di "1. FORMAL TEST OF ASYMMETRY (H0: delta+ = delta-)"
di "==========================================================================="

* Create asymmetric variables
capture drop dlny_pos dlny_neg dlny_pos_x_inf dlny_neg_x_inf
gen double dlny_pos = max(dlny_lab, 0) if dlny_lab < .
gen double dlny_neg = min(dlny_lab, 0) if dlny_lab < .
gen double dlny_pos_x_inf = dlny_pos * informal
gen double dlny_neg_x_inf = dlny_neg * informal

* Run asymmetric regression
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year, cluster(idind)

* Store estimates
local delta_plus = _b[dlny_pos_x_inf]
local se_plus = _se[dlny_pos_x_inf]
local delta_minus = _b[dlny_neg_x_inf]
local se_minus = _se[dlny_neg_x_inf]

* Formal test: H0: delta+ = delta-
test dlny_pos_x_inf = dlny_neg_x_inf
local p_equality = r(p)
local F_equality = r(F)

di _n "ASYMMETRY TEST RESULTS"
di "==========================================================================="
di "delta+ (positive shocks x informal): " %7.4f `delta_plus' " (SE: " %6.4f `se_plus' ")"
di "delta- (negative shocks x informal): " %7.4f `delta_minus' " (SE: " %6.4f `se_minus' ")"
di "Difference (delta- - delta+):        " %7.4f (`delta_minus' - `delta_plus')
di "==========================================================================="
di "F-test for H0: delta+ = delta-:      F = " %6.2f `F_equality'
di "p-value:                             " %6.4f `p_equality'
di "==========================================================================="
if `p_equality' < 0.01 {
    di "CONCLUSION: Reject H0 at 1% level - asymmetry is statistically significant"
}
else if `p_equality' < 0.05 {
    di "CONCLUSION: Reject H0 at 5% level - asymmetry is statistically significant"
}
else if `p_equality' < 0.10 {
    di "CONCLUSION: Reject H0 at 10% level - asymmetry is marginally significant"
}
else {
    di "CONCLUSION: Cannot reject H0 - no significant asymmetry"
}

* Save test results
file open asymtest using "$outdir/W4d_1_asymmetry_test.csv", write replace
file write asymtest "Formal Test of Asymmetry" _n
file write asymtest "Coefficient,Estimate,SE" _n
file write asymtest "delta+ (positive x informal)," %8.5f (`delta_plus') "," %8.5f (`se_plus') _n
file write asymtest "delta- (negative x informal)," %8.5f (`delta_minus') "," %8.5f (`se_minus') _n
file write asymtest "Difference (delta- - delta+)," %8.5f (`delta_minus' - `delta_plus') "," _n
file write asymtest _n
file write asymtest "Test: H0: delta+ = delta-" _n
file write asymtest "F-statistic," %8.3f (`F_equality') _n
file write asymtest "p-value," %8.4f (`p_equality') _n
file close asymtest

*==============================================================================
* 2. HETEROGENEITY IN ASYMMETRIC RESPONSE
*==============================================================================
di _n "==========================================================================="
di "2. HETEROGENEITY IN ASYMMETRIC RESPONSE"
di "==========================================================================="

* Check available demographic variables
capture confirm variable urban
capture confirm variable female
capture confirm variable age
capture confirm variable educ

* Create age and education groups
capture drop young high_educ
gen byte young = (age < 40) if age < .
gen byte high_educ = (educ >= 4) if educ < .  // Higher education

* Initialize results matrix
matrix het_results = J(8, 4, .)
matrix colnames het_results = delta_neg se_neg delta_pos se_pos
matrix rownames het_results = Urban Rural Male Female Young Older HighEduc LowEduc

local row = 1

* By urban/rural
foreach urb in 1 0 {
    if `urb' == 1 local label "Urban"
    else local label "Rural"

    di _n "--- `label' ---"
    capture {
        regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if urban == `urb', cluster(idind)
        matrix het_results[`row', 1] = _b[dlny_neg_x_inf]
        matrix het_results[`row', 2] = _se[dlny_neg_x_inf]
        matrix het_results[`row', 3] = _b[dlny_pos_x_inf]
        matrix het_results[`row', 4] = _se[dlny_pos_x_inf]
        di "delta- = " %7.4f _b[dlny_neg_x_inf] " (SE: " %6.4f _se[dlny_neg_x_inf] ")"
        di "delta+ = " %7.4f _b[dlny_pos_x_inf] " (SE: " %6.4f _se[dlny_pos_x_inf] ")"
    }
    local ++row
}

* By gender
foreach fem in 0 1 {
    if `fem' == 0 local label "Male"
    else local label "Female"

    di _n "--- `label' ---"
    capture {
        regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if female == `fem', cluster(idind)
        matrix het_results[`row', 1] = _b[dlny_neg_x_inf]
        matrix het_results[`row', 2] = _se[dlny_neg_x_inf]
        matrix het_results[`row', 3] = _b[dlny_pos_x_inf]
        matrix het_results[`row', 4] = _se[dlny_pos_x_inf]
        di "delta- = " %7.4f _b[dlny_neg_x_inf] " (SE: " %6.4f _se[dlny_neg_x_inf] ")"
        di "delta+ = " %7.4f _b[dlny_pos_x_inf] " (SE: " %6.4f _se[dlny_pos_x_inf] ")"
    }
    local ++row
}

* By age
foreach yng in 1 0 {
    if `yng' == 1 local label "Young (<40)"
    else local label "Older (40+)"

    di _n "--- `label' ---"
    capture {
        regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if young == `yng', cluster(idind)
        matrix het_results[`row', 1] = _b[dlny_neg_x_inf]
        matrix het_results[`row', 2] = _se[dlny_neg_x_inf]
        matrix het_results[`row', 3] = _b[dlny_pos_x_inf]
        matrix het_results[`row', 4] = _se[dlny_pos_x_inf]
        di "delta- = " %7.4f _b[dlny_neg_x_inf] " (SE: " %6.4f _se[dlny_neg_x_inf] ")"
        di "delta+ = " %7.4f _b[dlny_pos_x_inf] " (SE: " %6.4f _se[dlny_pos_x_inf] ")"
    }
    local ++row
}

* By education
foreach edu in 1 0 {
    if `edu' == 1 local label "High Education"
    else local label "Low Education"

    di _n "--- `label' ---"
    capture {
        regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if high_educ == `edu', cluster(idind)
        matrix het_results[`row', 1] = _b[dlny_neg_x_inf]
        matrix het_results[`row', 2] = _se[dlny_neg_x_inf]
        matrix het_results[`row', 3] = _b[dlny_pos_x_inf]
        matrix het_results[`row', 4] = _se[dlny_pos_x_inf]
        di "delta- = " %7.4f _b[dlny_neg_x_inf] " (SE: " %6.4f _se[dlny_neg_x_inf] ")"
        di "delta+ = " %7.4f _b[dlny_pos_x_inf] " (SE: " %6.4f _se[dlny_pos_x_inf] ")"
    }
    local ++row
}

* Export heterogeneity results
matrix list het_results
esttab matrix(het_results) using "$outdir/W4d_2_heterogeneity.csv", replace ///
    title("Heterogeneity in Asymmetric Response")

*==============================================================================
* 3. TRANSFER/NETWORK MECHANISM TEST
*==============================================================================
di _n "==========================================================================="
di "3. TRANSFER/NETWORK MECHANISM TEST"
di "==========================================================================="

* Check for transfer variables in the dataset
capture confirm variable transfer_received
capture confirm variable help_received
capture confirm variable money_help_received

* Look for transfer variables
capture ds *transfer* *help* *assist*
if !_rc {
    local transfer_vars = r(varlist)
    di "Available transfer-related variables: `transfer_vars'"
}
else {
    di "No transfer variables found in dataset"
}

* Create negative shock indicator
gen byte neg_shock = (dlny_lab < -0.10) if dlny_lab < .
gen byte neg_shock_x_inf = neg_shock * informal

* If we have transfer variables, run the test
capture confirm variable help_received
if !_rc {
    di _n "--- Transfer Response to Negative Shocks ---"
    regress help_received neg_shock informal neg_shock_x_inf i.year, cluster(idind)
    estimates store transfer_test

    di _n "If delta > 0: informal workers receive MORE transfers when hit by negative shocks"
    di "Coefficient on NegShock x Informal: " %7.4f _b[neg_shock_x_inf] " (SE: " %6.4f _se[neg_shock_x_inf] ")"
}

* Also try with regional vs idiosyncratic shocks
capture confirm variable shock_regional
capture confirm variable shock_job
if !_rc {
    di _n "--- Transfer Response by Shock Type ---"

    * Regional shock
    capture {
        gen byte reg_shock_x_inf = shock_regional * informal
        regress help_received shock_regional informal reg_shock_x_inf i.year, cluster(idind)
        di "Regional shock x Informal: " %7.4f _b[reg_shock_x_inf] " (SE: " %6.4f _se[reg_shock_x_inf] ")"
    }

    * Job shock
    capture {
        gen byte job_shock_x_inf = shock_job * informal
        regress help_received shock_job informal job_shock_x_inf i.year, cluster(idind)
        di "Job shock x Informal: " %7.4f _b[job_shock_x_inf] " (SE: " %6.4f _se[job_shock_x_inf] ")"
    }
}

*==============================================================================
* 4. ALTERNATIVE INFORMALITY DEFINITIONS
*==============================================================================
di _n "==========================================================================="
di "4. ALTERNATIVE INFORMALITY DEFINITIONS"
di "==========================================================================="

* Check what informality-related variables we have
capture ds *informal* *contract* *pension* *self* *firm*
if !_rc {
    local inf_vars = r(varlist)
    di "Available informality-related variables: `inf_vars'"
}
else {
    di "No additional informality variables found"
}

* Try to create alternative definitions
* Definition 1: Main definition (already have)
* Definition 2: No written contract
capture confirm variable has_contract
capture confirm variable contract

* Definition 3: Not contributing to pension
capture confirm variable pension_contrib
capture confirm variable soc_contrib

* Definition 4: Self-employed
capture confirm variable self_employed
capture confirm variable empsta

* Store results for each definition
matrix alt_def = J(4, 3, .)
matrix colnames alt_def = delta_neg se_neg N
matrix rownames alt_def = Main NoContract NoPension SelfEmp

local row = 1

* Main definition
di _n "--- Main Definition (Registration-based) ---"
regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year, cluster(idind)
matrix alt_def[1, 1] = _b[dlny_neg_x_inf]
matrix alt_def[1, 2] = _se[dlny_neg_x_inf]
matrix alt_def[1, 3] = e(N)

* Try alternative definitions if variables exist
capture confirm variable contract
if !_rc {
    di _n "--- No Written Contract ---"
    capture drop inf_nocontract pos_x_nc neg_x_nc
    gen byte inf_nocontract = (contract == 0 | contract == .) if contract < .
    gen double pos_x_nc = dlny_pos * inf_nocontract
    gen double neg_x_nc = dlny_neg * inf_nocontract

    capture {
        regress dlnc dlny_pos dlny_neg inf_nocontract pos_x_nc neg_x_nc i.year, cluster(idind)
        matrix alt_def[2, 1] = _b[neg_x_nc]
        matrix alt_def[2, 2] = _se[neg_x_nc]
        matrix alt_def[2, 3] = e(N)
        di "delta- = " %7.4f _b[neg_x_nc] " (SE: " %6.4f _se[neg_x_nc] ")"
    }
}

capture confirm variable pension_contrib
if !_rc {
    di _n "--- Not Contributing to Pension ---"
    capture drop inf_nopension pos_x_np neg_x_np
    gen byte inf_nopension = (pension_contrib == 0) if pension_contrib < .
    gen double pos_x_np = dlny_pos * inf_nopension
    gen double neg_x_np = dlny_neg * inf_nopension

    capture {
        regress dlnc dlny_pos dlny_neg inf_nopension pos_x_np neg_x_np i.year, cluster(idind)
        matrix alt_def[3, 1] = _b[neg_x_np]
        matrix alt_def[3, 2] = _se[neg_x_np]
        matrix alt_def[3, 3] = e(N)
        di "delta- = " %7.4f _b[neg_x_np] " (SE: " %6.4f _se[neg_x_np] ")"
    }
}

capture confirm variable self_employed
if !_rc {
    di _n "--- Self-Employed ---"
    capture drop pos_x_se neg_x_se
    gen double pos_x_se = dlny_pos * self_employed
    gen double neg_x_se = dlny_neg * self_employed

    capture {
        regress dlnc dlny_pos dlny_neg self_employed pos_x_se neg_x_se i.year, cluster(idind)
        matrix alt_def[4, 1] = _b[neg_x_se]
        matrix alt_def[4, 2] = _se[neg_x_se]
        matrix alt_def[4, 3] = e(N)
        di "delta- = " %7.4f _b[neg_x_se] " (SE: " %6.4f _se[neg_x_se] ")"
    }
}

matrix list alt_def

*==============================================================================
* 5. LOSS AVERSION WELFARE CALCULATION
*==============================================================================
di _n "==========================================================================="
di "5. LOSS AVERSION WELFARE CALCULATION"
di "==========================================================================="

* Under Kahneman-Tversky preferences with lambda = 2.25:
* W = E[gains] - lambda * E[|losses|]

local lambda = 2.25

* Calculate gains and losses for each sector
* Gains = positive consumption changes
* Losses = absolute value of negative consumption changes

* Formal sector
qui sum dlnc if informal == 0 & dlnc > 0
local E_gains_formal = r(mean) * r(N)
local N_gains_formal = r(N)

qui sum dlnc if informal == 0 & dlnc < 0
local E_losses_formal = -r(mean) * r(N)  // make positive
local N_losses_formal = r(N)

qui sum dlnc if informal == 0
local N_total_formal = r(N)

local avg_gain_formal = `E_gains_formal' / `N_total_formal'
local avg_loss_formal = `E_losses_formal' / `N_total_formal'

* Informal sector
qui sum dlnc if informal == 1 & dlnc > 0
local E_gains_informal = r(mean) * r(N)
local N_gains_informal = r(N)

qui sum dlnc if informal == 1 & dlnc < 0
local E_losses_informal = -r(mean) * r(N)  // make positive
local N_losses_informal = r(N)

qui sum dlnc if informal == 1
local N_total_informal = r(N)

local avg_gain_informal = `E_gains_informal' / `N_total_informal'
local avg_loss_informal = `E_losses_informal' / `N_total_informal'

* Loss-averse welfare
local W_formal = `avg_gain_formal' - `lambda' * `avg_loss_formal'
local W_informal = `avg_gain_informal' - `lambda' * `avg_loss_informal'
local W_gap_LA = `W_informal' - `W_formal'

* Compare to CRRA welfare (from variance)
qui sum dlnc if informal == 0
local var_formal = r(Var)
qui sum dlnc if informal == 1
local var_informal = r(Var)

* CRRA welfare cost = (1/2) * gamma * Var(dlnC)
local gamma = 2
local W_CRRA_formal = 0.5 * `gamma' * `var_formal'
local W_CRRA_informal = 0.5 * `gamma' * `var_informal'
local W_gap_CRRA = `W_CRRA_informal' - `W_CRRA_formal'

di _n "LOSS AVERSION WELFARE CALCULATION (lambda = `lambda')"
di "==========================================================================="
di "                              FORMAL        INFORMAL"
di "==========================================================================="
di "E[gains]                   " %8.4f `avg_gain_formal' "      " %8.4f `avg_gain_informal'
di "E[|losses|]                " %8.4f `avg_loss_formal' "      " %8.4f `avg_loss_informal'
di "W = E[gains] - λ*E[loss]   " %8.4f `W_formal' "      " %8.4f `W_informal'
di "==========================================================================="
di "WELFARE GAP (Informal - Formal):"
di "  Loss-averse (λ=2.25):    " %8.4f `W_gap_LA'
di "  CRRA (γ=2):              " %8.4f `W_gap_CRRA'
di "  Ratio (LA / CRRA):       " %8.2f (`W_gap_LA' / `W_gap_CRRA')
di "==========================================================================="

* As percentage of mean consumption
qui sum lnc if informal == 0
local mean_lnc_formal = r(mean)
qui sum lnc if informal == 1
local mean_lnc_informal = r(mean)

di _n "AS PERCENTAGE OF CONSUMPTION:"
di "  Loss-averse welfare gap: " %6.2f (100 * abs(`W_gap_LA')) "%"
di "  CRRA welfare gap:        " %6.2f (100 * `W_gap_CRRA') "%"

* Save results
file open lawelf using "$outdir/W4d_5_loss_aversion.csv", write replace
file write lawelf "Loss Aversion Welfare Calculation (lambda = 2.25)" _n
file write lawelf ",Formal,Informal" _n
file write lawelf "E[gains]," %8.5f (`avg_gain_formal') "," %8.5f (`avg_gain_informal') _n
file write lawelf "E[|losses|]," %8.5f (`avg_loss_formal') "," %8.5f (`avg_loss_informal') _n
file write lawelf "W = E[gains] - lambda*E[loss]," %8.5f (`W_formal') "," %8.5f (`W_informal') _n
file write lawelf _n
file write lawelf "Welfare Gap (Informal - Formal)" _n
file write lawelf "Loss-averse," %8.5f (`W_gap_LA') _n
file write lawelf "CRRA (gamma=2)," %8.5f (`W_gap_CRRA') _n
file write lawelf "Ratio (LA/CRRA)," %8.2f (`W_gap_LA' / `W_gap_CRRA') _n
file close lawelf

*==============================================================================
* 6. HOURS/SECONDARY JOB RESPONSE
*==============================================================================
di _n "==========================================================================="
di "6. HOURS AND SECONDARY JOB RESPONSE"
di "==========================================================================="

* Check for hours and secondary job variables
capture ds *hour* *hours* *second* *job*
if !_rc {
    local hour_vars = r(varlist)
    di "Available hours/job variables: `hour_vars'"
}
else {
    di "No hours/job variables found"
}

* If hours variable exists
capture confirm variable hours
if !_rc {
    di _n "--- Hours Response to Negative Income Shock ---"

    * Create change in hours
    capture drop dlnhours
    gen double dlnhours = ln(hours) - ln(L.hours) if hours > 0 & L.hours > 0

    regress dlnhours neg_shock informal neg_shock_x_inf i.year, cluster(idind)

    di "If delta > 0: informal workers INCREASE hours more after negative shocks"
    di "Coefficient on NegShock x Informal: " %7.4f _b[neg_shock_x_inf] " (SE: " %6.4f _se[neg_shock_x_inf] ")"
}

* Secondary job
capture confirm variable second_job
if !_rc {
    di _n "--- Secondary Job Take-up After Negative Shock ---"

    regress second_job neg_shock informal neg_shock_x_inf i.year, cluster(idind)

    di "If delta > 0: informal workers more likely to take secondary job after negative shock"
    di "Coefficient on NegShock x Informal: " %7.4f _b[neg_shock_x_inf] " (SE: " %6.4f _se[neg_shock_x_inf] ")"
}

*==============================================================================
* 7. WEALTH/SAVINGS HETEROGENEITY
*==============================================================================
di _n "==========================================================================="
di "7. WEALTH/SAVINGS HETEROGENEITY"
di "==========================================================================="

* Check for asset/wealth variables
capture ds *asset* *wealth* *saving* *buffer*
if !_rc {
    local asset_vars = r(varlist)
    di "Available asset/wealth variables: `asset_vars'"
}
else {
    di "No asset/wealth variables found"
}

* Try buffer stock variable (from credit constraint questions)
capture confirm variable buffer_stock
capture confirm variable has_savings

capture {
    if !_rc {
        di _n "--- Asymmetry by Asset Status ---"

        * Triple interaction
        gen byte neg_inf_asset = dlny_neg_x_inf * has_savings

        regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
            has_savings neg_inf_asset i.year, cluster(idind)

        di "If phi < 0: informal penalty is SMALLER for those with assets"
        di "Coefficient on ΔY- x Informal x HasAssets: " %7.4f _b[neg_inf_asset] " (SE: " %6.4f _se[neg_inf_asset] ")"
    }
}

* Try with credit constrained variable
capture confirm variable credit_constrained
if !_rc {
    di _n "--- Asymmetry by Credit Constraint Status ---"

    gen byte neg_inf_cc = dlny_neg_x_inf * credit_constrained

    regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
        credit_constrained neg_inf_cc i.year, cluster(idind)

    di "Coefficient on ΔY- x Informal x CreditConstrained: " %7.4f _b[neg_inf_cc] " (SE: " %6.4f _se[neg_inf_cc] ")"
}

*==============================================================================
* 8. EVENT STUDY FIGURE
*==============================================================================
di _n "==========================================================================="
di "8. EVENT STUDY FIGURE"
di "==========================================================================="

* Recreate event study variables
sort idind year
capture drop formal_to_inf inf_to_formal switch_year_* first_switch_* event_time_*

by idind: gen formal_to_inf = (L.informal == 0 & informal == 1) if L.informal < . & informal < .
by idind: gen inf_to_formal = (L.informal == 1 & informal == 0) if L.informal < . & informal < .

gen switch_year_f2i = year if formal_to_inf == 1
by idind: egen first_switch_f2i = min(switch_year_f2i)
gen event_time_f2i = year - first_switch_f2i

gen switch_year_i2f = year if inf_to_formal == 1
by idind: egen first_switch_i2f = min(switch_year_i2f)
gen event_time_i2f = year - first_switch_i2f

* Event study dummies for formal->informal
capture drop et_f2i_*
forvalues k = -4/5 {
    if `k' < 0 {
        local klab = "m" + string(abs(`k'))
    }
    else {
        local klab = "p" + string(`k')
    }
    gen byte et_f2i_`klab' = (event_time_f2i == `k') if event_time_f2i < .
}

* Run event study regression (k=-1 as reference)
reghdfe dlnc et_f2i_m4 et_f2i_m3 et_f2i_m2 et_f2i_p0 et_f2i_p1 et_f2i_p2 et_f2i_p3 et_f2i_p4 et_f2i_p5 ///
    if first_switch_f2i < ., absorb(idind year) cluster(idind)

* Store coefficients for plotting
matrix coef_f2i = J(10, 3, .)
matrix colnames coef_f2i = k coef se

local row = 1
foreach k in -4 -3 -2 -1 0 1 2 3 4 5 {
    matrix coef_f2i[`row', 1] = `k'
    if `k' == -1 {
        matrix coef_f2i[`row', 2] = 0
        matrix coef_f2i[`row', 3] = 0
    }
    else {
        if `k' < 0 {
            local klab = "m" + string(abs(`k'))
        }
        else {
            local klab = "p" + string(`k')
        }
        matrix coef_f2i[`row', 2] = _b[et_f2i_`klab']
        matrix coef_f2i[`row', 3] = _se[et_f2i_`klab']
    }
    local ++row
}

* Same for informal->formal
capture drop et_i2f_*
forvalues k = -4/5 {
    if `k' < 0 {
        local klab = "m" + string(abs(`k'))
    }
    else {
        local klab = "p" + string(`k')
    }
    gen byte et_i2f_`klab' = (event_time_i2f == `k') if event_time_i2f < .
}

reghdfe dlnc et_i2f_m4 et_i2f_m3 et_i2f_m2 et_i2f_p0 et_i2f_p1 et_i2f_p2 et_i2f_p3 et_i2f_p4 et_i2f_p5 ///
    if first_switch_i2f < ., absorb(idind year) cluster(idind)

matrix coef_i2f = J(10, 3, .)
matrix colnames coef_i2f = k coef se

local row = 1
foreach k in -4 -3 -2 -1 0 1 2 3 4 5 {
    matrix coef_i2f[`row', 1] = `k'
    if `k' == -1 {
        matrix coef_i2f[`row', 2] = 0
        matrix coef_i2f[`row', 3] = 0
    }
    else {
        if `k' < 0 {
            local klab = "m" + string(abs(`k'))
        }
        else {
            local klab = "p" + string(`k')
        }
        matrix coef_i2f[`row', 2] = _b[et_i2f_`klab']
        matrix coef_i2f[`row', 3] = _se[et_i2f_`klab']
    }
    local ++row
}

* Create data for plotting
preserve
clear
svmat coef_f2i
rename coef_f2i1 k
rename coef_f2i2 coef
rename coef_f2i3 se
gen ci_lo = coef - 1.96 * se
gen ci_hi = coef + 1.96 * se
gen transition = "Formal to Informal"
tempfile f2i
save `f2i'

clear
svmat coef_i2f
rename coef_i2f1 k
rename coef_i2f2 coef
rename coef_i2f3 se
gen ci_lo = coef - 1.96 * se
gen ci_hi = coef + 1.96 * se
gen transition = "Informal to Formal"

append using `f2i'

* Create the figure
twoway (rcap ci_lo ci_hi k if transition == "Formal to Informal", lcolor(navy)) ///
       (scatter coef k if transition == "Formal to Informal", mcolor(navy) msymbol(O)) ///
       (rcap ci_lo ci_hi k if transition == "Informal to Formal", lcolor(maroon)) ///
       (scatter coef k if transition == "Informal to Formal", mcolor(maroon) msymbol(D)), ///
       xline(-0.5, lcolor(gs10) lpattern(dash)) ///
       yline(0, lcolor(gs10)) ///
       xlabel(-4(1)5) ///
       xtitle("Years Since Formality Transition") ///
       ytitle("Consumption Growth (relative to k=-1)") ///
       legend(order(2 "Formal → Informal" 4 "Informal → Formal") rows(1) position(6)) ///
       title("Event Study: Consumption Response to Formality Transitions") ///
       note("Notes: 95% confidence intervals shown. Reference period k=-1." ///
            "Individual and year fixed effects. SE clustered at individual level.")

graph export "$figdir/event_study.pdf", replace
graph export "$figdir/event_study.png", replace width(1200)

restore

*==============================================================================
* 9. EXTENDED EVENT WINDOW
*==============================================================================
di _n "==========================================================================="
di "9. EXTENDED EVENT WINDOW (k = -4 to +6)"
di "==========================================================================="

* Check if we have enough observations at k=+5, +6
tab event_time_i2f if event_time_i2f >= -4 & event_time_i2f <= 6

* Create additional event time dummies
capture drop et_i2f_p5 et_i2f_p6
gen byte et_i2f_p6 = (event_time_i2f == 6) if event_time_i2f < .

* Extended event study
di _n "--- Extended Event Study: Informal -> Formal ---"
reghdfe dlnc et_i2f_m4 et_i2f_m3 et_i2f_m2 et_i2f_p0 et_i2f_p1 et_i2f_p2 et_i2f_p3 et_i2f_p4 et_i2f_p5 et_i2f_p6 ///
    if first_switch_i2f < ., absorb(idind year) cluster(idind)

di _n "Coefficients at longer horizons:"
di "k=+4: " %7.4f _b[et_i2f_p4] " (SE: " %6.4f _se[et_i2f_p4] ")"
di "k=+5: " %7.4f _b[et_i2f_p5] " (SE: " %6.4f _se[et_i2f_p5] ")"
capture di "k=+6: " %7.4f _b[et_i2f_p6] " (SE: " %6.4f _se[et_i2f_p6] ")"

*==============================================================================
* 10. REGIONAL VARIATION IN INFORMALITY PENALTY
*==============================================================================
di _n "==========================================================================="
di "10. REGIONAL VARIATION IN INFORMALITY PENALTY"
di "==========================================================================="

* Check for region variables
capture confirm variable region
capture confirm variable okrug

* If we have federal district (okrug)
capture {
    di _n "--- Asymmetry by Federal District ---"

    levelsof okrug, local(districts)

    foreach d of local districts {
        di _n "Federal District `d':"
        capture {
            regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if okrug == `d', cluster(idind)
            di "  delta- = " %7.4f _b[dlny_neg_x_inf] " (SE: " %6.4f _se[dlny_neg_x_inf] "), N = " e(N)
        }
    }
}

* Urban vs rural interaction with asymmetry
di _n "--- Triple Interaction: Asymmetry x Urban ---"
capture {
    gen byte neg_inf_urban = dlny_neg_x_inf * urban

    regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf ///
        urban neg_inf_urban i.year, cluster(idind)

    di "If negative: rural informal workers have LARGER penalty"
    di "Coefficient on ΔY- x Informal x Urban: " %7.4f _b[neg_inf_urban] " (SE: " %6.4f _se[neg_inf_urban] ")"
}

*==============================================================================
* SUMMARY OUTPUT
*==============================================================================
di _n _n "==========================================================================="
di "ANALYSIS COMPLETE"
di "==========================================================================="
di _n "Output files created:"
di "  $outdir/W4d_1_asymmetry_test.csv"
di "  $outdir/W4d_2_heterogeneity.csv"
di "  $outdir/W4d_5_loss_aversion.csv"
di "  $figdir/event_study.pdf"
di "  $figdir/event_study.png"

log close _all
