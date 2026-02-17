/*==============================================================================
    Step W4c - Additional Analyses

    Additional robustness checks and extensions:
    1. IV/2SLS with health shock instruments
    2. Event study around formality transitions
    3. Variance decomposition (income vs smoothing)
    4. Placebo test with future income
    5. Alternative informality definitions
    6. Distributed lag / dynamic effects
    7. Labor supply adjustment mechanism
    8. Heterogeneity in asymmetric response
    9. Transitory vs permanent shock decomposition

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

*==============================================================================
* 1. IV/2SLS RESULTS WITH HEALTH SHOCK INSTRUMENTS
*==============================================================================
di _n "==========================================================================="
di "1. IV/2SLS ESTIMATION"
di "==========================================================================="

* Check what shock variables we have
capture confirm variable shock_health
if _rc {
    di "Creating shock variables..."
    * Create health shock from available variables
    capture gen byte shock_health = (health_shock == 1) if health_shock < .
    if _rc {
        * Try alternative - significant health deterioration
        capture gen byte shock_health = (L.health_good == 1 & health_good == 0) if health_good < .
    }
}

capture confirm variable shock_job
if _rc {
    capture gen byte shock_job = (job_shock == 1) if job_shock < .
}

* First, show OLS baseline for comparison
di _n "--- OLS Baseline ---"
regress dlnc dlny_lab informal c.dlny_lab#c.informal i.year, cluster(idind)
estimates store ols_base

* Create negative income change variable for IV
gen double dlny_neg_only = dlny_lab if dlny_lab < 0
replace dlny_neg_only = 0 if dlny_lab >= 0 & dlny_lab < .

gen double dlny_neg_x_inf = dlny_neg_only * informal

* IV: Instrument income changes with health shocks
* First stage diagnostics
di _n "--- First Stage: Health Shock -> Income Change ---"
capture {
    regress dlny_lab shock_health c.shock_health#c.informal informal i.year, cluster(idind)
    test shock_health c.shock_health#c.informal
    local fs_F = r(F)
    di "First-stage F-statistic: " %6.2f `fs_F'
}

* 2SLS estimation
di _n "--- IV/2SLS: Health Shock Instrument ---"
capture {
    ivregress 2sls dlnc informal i.year (dlny_lab c.dlny_lab#c.informal = shock_health c.shock_health#c.informal), cluster(idind) first
    estimates store iv_health

    * Weak instrument test
    estat firststage

    * Save first-stage F
    matrix fs = r(singleresults)
}

* Alternative: Use multiple instruments (health + regional shocks)
di _n "--- IV with Multiple Instruments ---"
capture confirm variable shock_regional
if !_rc {
    capture {
        ivregress 2sls dlnc informal i.year ///
            (dlny_lab c.dlny_lab#c.informal = shock_health shock_regional c.shock_health#c.informal c.shock_regional#c.informal), ///
            cluster(idind) first
        estimates store iv_multi

        * Overidentification test
        estat overid
    }
}

* IV for asymmetric specification (negative shocks only)
di _n "--- IV for Negative Shocks Only ---"
capture {
    * Restrict to negative income changes
    ivregress 2sls dlnc informal i.year (dlny_neg_only dlny_neg_x_inf = shock_health c.shock_health#c.informal) ///
        if dlny_lab < 0, cluster(idind) first
    estimates store iv_negative
}

* Export IV results
capture {
    esttab ols_base iv_health iv_multi iv_negative using "$outdir/W4c_1_iv_results.csv", replace ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title("Table W4c.1: IV/2SLS Results") ///
        mtitles("OLS" "IV-Health" "IV-Multi" "IV-Negative") ///
        note("Standard errors clustered at individual level")
}

*==============================================================================
* 2. EVENT STUDY AROUND FORMALITY TRANSITIONS
*==============================================================================
di _n "==========================================================================="
di "2. EVENT STUDY AROUND FORMALITY TRANSITIONS"
di "==========================================================================="

* Identify transitions
sort idind year
by idind: gen formal_to_inf = (L.informal == 0 & informal == 1) if L.informal < . & informal < .
by idind: gen inf_to_formal = (L.informal == 1 & informal == 0) if L.informal < . & informal < .

* Count transitions
count if formal_to_inf == 1
local n_f2i = r(N)
count if inf_to_formal == 1
local n_i2f = r(N)
di "Formal -> Informal transitions: `n_f2i'"
di "Informal -> Formal transitions: `n_i2f'"

* Create event time variable for formal->informal transitions
gen switch_year_f2i = year if formal_to_inf == 1
by idind: egen first_switch_f2i = min(switch_year_f2i)
gen event_time_f2i = year - first_switch_f2i

* Create event time variable for informal->formal transitions
gen switch_year_i2f = year if inf_to_formal == 1
by idind: egen first_switch_i2f = min(switch_year_i2f)
gen event_time_i2f = year - first_switch_i2f

* Event study: Formal -> Informal
di _n "--- Event Study: Formal to Informal Transition ---"
capture {
    * Create event time dummies (k = -2 to +3, with -1 as reference)
    forvalues k = -3/4 {
        if `k' < 0 {
            local klab = "m" + string(abs(`k'))
        }
        else {
            local klab = "p" + string(`k')
        }
        gen byte et_f2i_`klab' = (event_time_f2i == `k') if event_time_f2i < .
    }

    * Regression with individual and year FE
    reghdfe dlnc et_f2i_m3 et_f2i_m2 et_f2i_p0 et_f2i_p1 et_f2i_p2 et_f2i_p3 et_f2i_p4 ///
        if first_switch_f2i < ., absorb(idind year) cluster(idind)
    estimates store es_f2i

    * Store coefficients for plotting
    matrix es_f2i_coef = e(b)
    matrix es_f2i_V = e(V)
}

* Event study: Informal -> Formal
di _n "--- Event Study: Informal to Formal Transition ---"
capture {
    forvalues k = -3/4 {
        if `k' < 0 {
            local klab = "m" + string(abs(`k'))
        }
        else {
            local klab = "p" + string(`k')
        }
        gen byte et_i2f_`klab' = (event_time_i2f == `k') if event_time_i2f < .
    }

    reghdfe dlnc et_i2f_m3 et_i2f_m2 et_i2f_p0 et_i2f_p1 et_i2f_p2 et_i2f_p3 et_i2f_p4 ///
        if first_switch_i2f < ., absorb(idind year) cluster(idind)
    estimates store es_i2f
}

* Export event study results
capture {
    esttab es_f2i es_i2f using "$outdir/W4c_2_event_study.csv", replace ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title("Table W4c.2: Event Study Around Formality Transitions") ///
        mtitles("Formal->Informal" "Informal->Formal") ///
        note("Reference period: k=-1. Individual and year FE. SE clustered at individual.")
}

* Also look at variance of dlnc before/after transition
di _n "--- Consumption Variance Before/After Transition ---"
di "Formal -> Informal:"
tabstat dlnc if first_switch_f2i < . & event_time_f2i >= -2 & event_time_f2i <= 2, ///
    by(event_time_f2i) stat(mean sd var n)

di _n "Informal -> Formal:"
tabstat dlnc if first_switch_i2f < . & event_time_i2f >= -2 & event_time_i2f <= 2, ///
    by(event_time_i2f) stat(mean sd var n)

*==============================================================================
* 3. VARIANCE DECOMPOSITION
*==============================================================================
di _n "==========================================================================="
di "3. VARIANCE DECOMPOSITION"
di "==========================================================================="

* Var(dlnC) = beta^2 * Var(dlnY) + Var(epsilon)
* This tells us: is the gap due to higher income volatility or worse smoothing?

* Get variances by sector
tabstat dlnc dlny_lab, by(informal) stat(var n) save
matrix stats = r(StatTotal)

* Formal sector
qui sum dlnc if informal == 0
local var_c_formal = r(Var)
qui sum dlny_lab if informal == 0
local var_y_formal = r(Var)

* Informal sector
qui sum dlnc if informal == 1
local var_c_informal = r(Var)
qui sum dlny_lab if informal == 1
local var_y_informal = r(Var)

* Get beta by sector
qui regress dlnc dlny_lab i.year if informal == 0, cluster(idind)
local beta_formal = _b[dlny_lab]

qui regress dlnc dlny_lab i.year if informal == 1, cluster(idind)
local beta_informal = _b[dlny_lab]

* Decomposition
local explained_formal = `beta_formal'^2 * `var_y_formal'
local residual_formal = `var_c_formal' - `explained_formal'

local explained_informal = `beta_informal'^2 * `var_y_informal'
local residual_informal = `var_c_informal' - `explained_informal'

di _n "VARIANCE DECOMPOSITION"
di "==========================================================================="
di "                              FORMAL        INFORMAL      DIFFERENCE"
di "==========================================================================="
di "Var(dlnC)                  " %8.4f `var_c_formal' "      " %8.4f `var_c_informal' "      " %8.4f (`var_c_informal' - `var_c_formal')
di "Var(dlnY)                  " %8.4f `var_y_formal' "      " %8.4f `var_y_informal' "      " %8.4f (`var_y_informal' - `var_y_formal')
di "Beta                       " %8.4f `beta_formal' "      " %8.4f `beta_informal' "      " %8.4f (`beta_informal' - `beta_formal')
di "Beta^2 * Var(dlnY)         " %8.4f `explained_formal' "      " %8.4f `explained_informal' "      " %8.4f (`explained_informal' - `explained_formal')
di "Residual Var(epsilon)      " %8.4f `residual_formal' "      " %8.4f `residual_informal' "      " %8.4f (`residual_informal' - `residual_formal')
di "==========================================================================="
di "% of Var(dlnC) gap due to:"
local total_gap = `var_c_informal' - `var_c_formal'
local income_var_contribution = (`beta_informal'^2 * `var_y_informal') - (`beta_formal'^2 * `var_y_formal')
local residual_contribution = `residual_informal' - `residual_formal'
di "  Higher income variance:  " %6.1f (100 * `income_var_contribution' / `total_gap') "%"
di "  Worse smoothing:         " %6.1f (100 * `residual_contribution' / `total_gap') "%"

* Save decomposition to file
file open decomp using "$outdir/W4c_3_variance_decomp.csv", write replace
file write decomp "Variance Decomposition" _n
file write decomp ",Formal,Informal,Difference" _n
file write decomp "Var(dlnC)," %8.5f (`var_c_formal') "," %8.5f (`var_c_informal') "," %8.5f (`var_c_informal' - `var_c_formal') _n
file write decomp "Var(dlnY)," %8.5f (`var_y_formal') "," %8.5f (`var_y_informal') "," %8.5f (`var_y_informal' - `var_y_formal') _n
file write decomp "Beta," %8.5f (`beta_formal') "," %8.5f (`beta_informal') "," %8.5f (`beta_informal' - `beta_formal') _n
file write decomp "Beta^2*Var(dlnY)," %8.5f (`explained_formal') "," %8.5f (`explained_informal') "," %8.5f (`explained_informal' - `explained_formal') _n
file write decomp "Residual Var," %8.5f (`residual_formal') "," %8.5f (`residual_informal') "," %8.5f (`residual_informal' - `residual_formal') _n
file write decomp _n
file write decomp "% of gap due to income variance," %6.1f (100 * `income_var_contribution' / `total_gap') "%" _n
file write decomp "% of gap due to worse smoothing," %6.1f (100 * `residual_contribution' / `total_gap') "%" _n
file close decomp

*==============================================================================
* 4. PLACEBO TEST WITH FUTURE INCOME
*==============================================================================
di _n "==========================================================================="
di "4. PLACEBO TEST WITH FUTURE INCOME"
di "==========================================================================="

* If households smooth, future income shouldn't predict current consumption
* After controlling for current income
gen double F_dlny_lab = F.dlny_lab
gen double F_dlny_x_inf = F_dlny_lab * informal

di "--- Placebo: Future Income on Current Consumption ---"
* Pooled
regress dlnc dlny_lab F_dlny_lab informal c.dlny_lab#c.informal c.F_dlny_lab#c.informal i.year, cluster(idind)
estimates store placebo_pool

* By sector
di _n "Formal workers:"
regress dlnc dlny_lab F_dlny_lab i.year if informal == 0, cluster(idind)
local b_future_formal = _b[F_dlny_lab]
local se_future_formal = _se[F_dlny_lab]

di _n "Informal workers:"
regress dlnc dlny_lab F_dlny_lab i.year if informal == 1, cluster(idind)
local b_future_informal = _b[F_dlny_lab]
local se_future_informal = _se[F_dlny_lab]

di _n "PLACEBO TEST RESULTS"
di "==========================================================================="
di "Coefficient on FUTURE income change (should be zero under smoothing):"
di "  Formal:   " %7.4f `b_future_formal' " (SE: " %6.4f `se_future_formal' ")"
di "  Informal: " %7.4f `b_future_informal' " (SE: " %6.4f `se_future_informal' ")"
di "==========================================================================="

* Export
capture {
    esttab placebo_pool using "$outdir/W4c_4_placebo_future.csv", replace ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title("Table W4c.4: Placebo Test - Future Income") ///
        note("Future income should not predict current consumption under smoothing")
}

*==============================================================================
* 5. ALTERNATIVE INFORMALITY DEFINITIONS
*==============================================================================
di _n "==========================================================================="
di "5. ALTERNATIVE INFORMALITY DEFINITIONS"
di "==========================================================================="

* Check what variables we have for alternative definitions
capture confirm variable has_contract
capture confirm variable firm_size
capture confirm variable self_employed
capture confirm variable soc_contrib

* Try to create alternative definitions from available data
* Definition 2: No written contract
capture {
    gen byte informal_nocontract = (has_contract == 0) if has_contract < .
    label var informal_nocontract "No written contract"
}

* Definition 3: Small firm (<5 employees)
capture {
    gen byte informal_smallfirm = (firm_size < 5) if firm_size < .
    label var informal_smallfirm "Firm size < 5"
}

* Definition 4: Self-employed
capture {
    gen byte informal_selfemp = (self_employed == 1) if self_employed < .
    label var informal_selfemp "Self-employed"
}

* Run asymmetric specification with each definition
local defs "informal"
capture confirm variable informal_nocontract
if !_rc local defs "`defs' informal_nocontract"
capture confirm variable informal_smallfirm
if !_rc local defs "`defs' informal_smallfirm"
capture confirm variable informal_selfemp
if !_rc local defs "`defs' informal_selfemp"

local i = 1
foreach def of local defs {
    di _n "--- Definition: `def' ---"

    * Create interactions
    capture drop temp_pos temp_neg temp_pos_x_inf temp_neg_x_inf
    gen double temp_pos = max(dlny_lab, 0) if dlny_lab < .
    gen double temp_neg = min(dlny_lab, 0) if dlny_lab < .
    gen double temp_pos_x_inf = temp_pos * `def'
    gen double temp_neg_x_inf = temp_neg * `def'

    capture {
        regress dlnc temp_pos temp_neg `def' temp_pos_x_inf temp_neg_x_inf i.year, cluster(idind)
        estimates store altdef_`i'
    }
    local ++i
}

* Export
capture {
    esttab altdef_* using "$outdir/W4c_5_alt_definitions.csv", replace ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title("Table W4c.5: Alternative Informality Definitions") ///
        note("Asymmetric specification with different informality measures")
}

*==============================================================================
* 6. DISTRIBUTED LAG / DYNAMIC EFFECTS
*==============================================================================
di _n "==========================================================================="
di "6. DISTRIBUTED LAG MODEL"
di "==========================================================================="

* Does the consumption impact of shocks fade over time?
* Create lagged shock variables
capture confirm variable shock_health
if !_rc {
    gen byte L1_shock_health = L.shock_health
    gen byte L2_shock_health = L2.shock_health

    gen byte L1_shock_h_x_inf = L1_shock_health * informal
    gen byte L2_shock_h_x_inf = L2_shock_health * informal

    di "--- Distributed Lag: Health Shocks ---"
    regress dlnc shock_health L1_shock_health L2_shock_health ///
        informal c.shock_health#c.informal L1_shock_h_x_inf L2_shock_h_x_inf ///
        i.year, cluster(idind)
    estimates store distlag_health
}

* Also with negative income changes
gen double L1_dlny_neg = L.dlny_neg_only
gen double L2_dlny_neg = L2.dlny_neg_only
gen double L1_dlny_neg_x_inf = L1_dlny_neg * informal
gen double L2_dlny_neg_x_inf = L2_dlny_neg * informal

di _n "--- Distributed Lag: Negative Income Changes ---"
regress dlnc dlny_neg_only L1_dlny_neg L2_dlny_neg ///
    informal c.dlny_neg_only#c.informal L1_dlny_neg_x_inf L2_dlny_neg_x_inf ///
    i.year, cluster(idind)
estimates store distlag_income

* Export
capture {
    esttab distlag_* using "$outdir/W4c_6_distributed_lag.csv", replace ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title("Table W4c.6: Distributed Lag Model") ///
        note("Testing persistence of shock effects")
}

*==============================================================================
* 7. LABOR SUPPLY ADJUSTMENT MECHANISM
*==============================================================================
di _n "==========================================================================="
di "7. LABOR SUPPLY ADJUSTMENT"
di "==========================================================================="

* Do informal workers adjust hours more in response to shocks?
capture confirm variable hours_worked
if !_rc {
    * Create change in hours
    gen double dlnhours = ln(hours_worked) - ln(L.hours_worked) if hours_worked > 0 & L.hours_worked > 0

    di "--- Hours Response to Negative Income Shocks ---"
    regress dlnhours dlny_neg_only informal c.dlny_neg_only#c.informal i.year, cluster(idind)
    estimates store hours_adj
}

* Secondary job indicator
capture confirm variable has_secondary_job
if !_rc {
    di _n "--- Secondary Job Response ---"
    regress has_secondary_job dlny_neg_only informal c.dlny_neg_only#c.informal i.year, cluster(idind)
    estimates store secjob_adj
}

* Alternative: Use income change itself
* If informal workers increase labor supply more, their income should partially recover
gen double recovery = F.dlny_lab if dlny_lab < -0.1  // after a big negative shock
di _n "--- Income Recovery After Negative Shock ---"
regress recovery informal i.year if dlny_lab < -0.1, cluster(idind)
estimates store income_recovery

*==============================================================================
* 8. HETEROGENEITY IN ASYMMETRIC RESPONSE
*==============================================================================
di _n "==========================================================================="
di "8. HETEROGENEITY IN ASYMMETRIC RESPONSE"
di "==========================================================================="

* The asymmetry (delta- >> 0, delta+ < 0) - does it vary by subgroup?

* Create subgroup indicators
capture confirm variable urban
capture confirm variable female
capture confirm variable age

* By urban/rural
capture {
    di "--- Urban ---"
    regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if urban == 1, cluster(idind)
    estimates store asym_urban

    di _n "--- Rural ---"
    regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if urban == 0, cluster(idind)
    estimates store asym_rural
}

* By gender
capture {
    di _n "--- Male ---"
    regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if female == 0, cluster(idind)
    estimates store asym_male

    di _n "--- Female ---"
    regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if female == 1, cluster(idind)
    estimates store asym_female
}

* By age
capture {
    gen byte young = (age < 35) if age < .

    di _n "--- Young (< 35) ---"
    regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if young == 1, cluster(idind)
    estimates store asym_young

    di _n "--- Older (>= 35) ---"
    regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if young == 0, cluster(idind)
    estimates store asym_older
}

* By education
capture confirm variable high_educ
capture {
    di _n "--- High Education ---"
    regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if high_educ == 1, cluster(idind)
    estimates store asym_higheduc

    di _n "--- Lower Education ---"
    regress dlnc dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf i.year if high_educ == 0, cluster(idind)
    estimates store asym_loweduc
}

* Export heterogeneity results
capture {
    esttab asym_urban asym_rural asym_male asym_female asym_young asym_older using "$outdir/W4c_8_heterogeneity.csv", replace ///
        cells(b(star fmt(4)) se(par fmt(4))) ///
        star(* 0.10 ** 0.05 *** 0.01) ///
        title("Table W4c.8: Heterogeneity in Asymmetric Response") ///
        mtitles("Urban" "Rural" "Male" "Female" "Young" "Older") ///
        keep(dlny_pos dlny_neg informal dlny_pos_x_inf dlny_neg_x_inf) ///
        note("SE clustered at individual level")
}

*==============================================================================
* 9. TRANSITORY VS PERMANENT SHOCK DECOMPOSITION (SIMPLIFIED BPP)
*==============================================================================
di _n "==========================================================================="
di "9. TRANSITORY VS PERMANENT DECOMPOSITION"
di "==========================================================================="

* Simplified BPP approach using autocovariance structure
* Cov(dlnY_t, dlnY_{t-1}) relates to transitory variance
* Var(dlnY) - 2*|Cov(dlnY_t, dlnY_{t-1})| approximates permanent variance

* Calculate autocovariances by sector
gen double L1_dlny = L.dlny_lab
gen double L2_dlny = L2.dlny_lab

* Formal sector
qui corr dlny_lab L1_dlny if informal == 0, cov
local cov_y_formal = r(cov_12)
qui sum dlny_lab if informal == 0
local var_y_formal = r(Var)

* Informal sector
qui corr dlny_lab L1_dlny if informal == 1, cov
local cov_y_informal = r(cov_12)
qui sum dlny_lab if informal == 1
local var_y_informal = r(Var)

* Under permanent-transitory model:
* Var(dlnY) = var(eta) + 2*var(epsilon)  [permanent + 2*transitory]
* Cov(dlnY_t, dlnY_{t-1}) = -var(epsilon) [negative of transitory]
* So: var(epsilon) = -Cov; var(eta) = Var(dlnY) - 2*var(epsilon)

local var_trans_formal = -`cov_y_formal'
local var_perm_formal = `var_y_formal' - 2*`var_trans_formal'

local var_trans_informal = -`cov_y_informal'
local var_perm_informal = `var_y_informal' - 2*`var_trans_informal'

di _n "INCOME SHOCK DECOMPOSITION (BPP-style)"
di "==========================================================================="
di "                              FORMAL        INFORMAL"
di "==========================================================================="
di "Var(dlnY)                  " %8.4f `var_y_formal' "      " %8.4f `var_y_informal'
di "Cov(dlnY_t, dlnY_{t-1})    " %8.4f `cov_y_formal' "      " %8.4f `cov_y_informal'
di "Var(transitory) = -Cov     " %8.4f `var_trans_formal' "      " %8.4f `var_trans_informal'
di "Var(permanent)             " %8.4f `var_perm_formal' "      " %8.4f `var_perm_informal'
di "==========================================================================="

* Now estimate consumption response to each component
* Use lagged income changes to identify transitory shocks
* dlnY_{t-1} as instrument for transitory component

di _n "--- Response to Transitory Shocks (using dlnY_{t-1} as proxy) ---"
* If dlnY_{t-1} is negative but dlnY_t is positive, likely transitory reversal
gen byte trans_reversal = (L1_dlny < -0.05 & dlny_lab > 0.05) if L1_dlny < . & dlny_lab < .

regress dlnc trans_reversal informal c.trans_reversal#c.informal i.year, cluster(idind)
estimates store trans_response

* Save decomposition
file open bpp using "$outdir/W4c_9_bpp_decomp.csv", write replace
file write bpp "BPP-Style Income Decomposition" _n
file write bpp ",Formal,Informal" _n
file write bpp "Var(dlnY)," %8.5f (`var_y_formal') "," %8.5f (`var_y_informal') _n
file write bpp "Cov(dlnY_t dlnY_{t-1})," %8.5f (`cov_y_formal') "," %8.5f (`cov_y_informal') _n
file write bpp "Var(transitory)," %8.5f (`var_trans_formal') "," %8.5f (`var_trans_informal') _n
file write bpp "Var(permanent)," %8.5f (`var_perm_formal') "," %8.5f (`var_perm_informal') _n
file close bpp

*==============================================================================
* SUMMARY OUTPUT
*==============================================================================
di _n _n "==========================================================================="
di "ANALYSIS COMPLETE"
di "==========================================================================="
di _n "Output files created in $outdir:"
di "  W4c_1_iv_results.csv       - IV/2SLS estimation"
di "  W4c_2_event_study.csv      - Event study around transitions"
di "  W4c_3_variance_decomp.csv  - Variance decomposition"
di "  W4c_4_placebo_future.csv   - Placebo test with future income"
di "  W4c_5_alt_definitions.csv  - Alternative informality definitions"
di "  W4c_6_distributed_lag.csv  - Dynamic/distributed lag model"
di "  W4c_8_heterogeneity.csv    - Heterogeneity in asymmetric response"
di "  W4c_9_bpp_decomp.csv       - Transitory vs permanent decomposition"

log close _all
