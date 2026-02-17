/*==============================================================================
  Step W6 - Welfare cost quantification

  Project:  Welfare Cost of Labor Informality
  Purpose:  Compute CRRA welfare costs of consumption volatility for
            formal vs informal workers; quantify the welfare gap
  Input:    Welfare analysis/Data/welfare_panel_shocks.dta
  Output:   Welfare analysis/Results/Tables/W6_*.csv
            Welfare analysis/Data/welfare_costs_by_year.dta

  Methodology:
    1. Var(dlnC) by sector — raw and residual
    2. Permanent/transitory decomposition (GPS approach)
    3. CRRA welfare cost: W_j = (1/2) * gamma * Var(dlnC_j)
    4. Decomposed welfare cost with discount rate rho = 0.05
    5. Counterfactual: compensating variation
    6. Ruble amounts using mean consumption levels
    7. Fraction of wage gap explained
    8. Time-varying welfare costs (by year)
    9. Subgroup analysis (education, urban/rural, gender)

  Author:
  Created:  February 2026
==============================================================================*/

clear all
capture set maxvar 32767
do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close
log using "$logdir/Step_W6_welfare.log", replace

use "$data/welfare_panel_shocks.dta", clear
keep if analysis_sample == 1
xtset idind year

*===============================================================================
* 0. SETUP
*===============================================================================

* Risk aversion parameters to evaluate
local gamma_list 1 2 3 5

* Discount rate for present-value calculations
local rho = 0.05

*===============================================================================
* 1. RAW CONSUMPTION VARIANCE BY SECTOR
*===============================================================================

di as text _n "=============================================="
di as text    "  1. RAW CONSUMPTION VARIANCE BY SECTOR"
di as text    "=============================================="

* --- Var(dlnC) for formal vs informal: non-durable consumption ---
forvalues s = 0/1 {
    quietly summarize dlnc if informal == `s', detail
    local var_c_`s'  = r(Var)
    local sd_c_`s'   = r(sd)
    local mean_c_`s' = r(mean)
    local n_c_`s'    = r(N)
    local p10_c_`s'  = r(p10)
    local p90_c_`s'  = r(p90)
    local sec = cond(`s' == 0, "Formal", "Informal")
    di as text "`sec': Var(dlnC) = " %7.5f `var_c_`s'' ///
        "  SD = " %7.5f `sd_c_`s'' ///
        "  Mean = " %7.5f `mean_c_`s'' ///
        "  N = " `n_c_`s''
    di as text "        P10 = " %7.4f `p10_c_`s'' ///
        "  P90 = " %7.4f `p90_c_`s''
}

* --- Variance ratio test ---
quietly sdtest dlnc, by(informal)
local F_raw = r(F)
local p_F_raw = r(p)
di as text _n "Variance ratio test (informal/formal): F = " %7.3f `F_raw' ///
    "  p = " %6.4f `p_F_raw'

* --- Durable-inclusive consumption ---
di as text _n "--- Durable-inclusive consumption ---"
forvalues s = 0/1 {
    quietly summarize dlncD if informal == `s', detail
    local var_cD_`s' = r(Var)
    local sd_cD_`s'  = r(sd)
    local sec = cond(`s' == 0, "Formal", "Informal")
    di as text "`sec': Var(dlnCD) = " %7.5f `var_cD_`s'' ///
        "  SD = " %7.5f `sd_cD_`s''
}

* --- Food consumption only ---
di as text _n "--- Food consumption only ---"
forvalues s = 0/1 {
    quietly summarize dlnfood if informal == `s', detail
    local var_food_`s' = r(Var)
    local sec = cond(`s' == 0, "Formal", "Informal")
    di as text "`sec': Var(dlnFood) = " %7.5f `var_food_`s''
}

* --- Income variance for comparison ---
di as text _n "--- Income variance ---"
forvalues s = 0/1 {
    quietly summarize dlny_lab if informal == `s', detail
    local var_y_`s' = r(Var)
    local sec = cond(`s' == 0, "Formal", "Informal")
    di as text "`sec': Var(dlnY) = " %7.5f `var_y_`s''
}

* --- Variance ratio: consumption pass-through ---
di as text _n "--- Variance ratios: Var(dlnC)/Var(dlnY) ---"
di as text "Formal:   " %7.5f (`var_c_0' / `var_y_0')
di as text "Informal: " %7.5f (`var_c_1' / `var_y_1')
di as text "  (closer to 0 = better insurance; closer to 1 = no insurance)"

*===============================================================================
* 2. RESIDUAL CONSUMPTION VARIANCE (after removing observables)
*===============================================================================

di as text _n "=============================================="
di as text    "  2. RESIDUAL VARIANCE"
di as text    "=============================================="

* Regress dlnC on demographics and year FE; use residuals
* This removes predictable variation due to lifecycle, demographics, and
* aggregate trends, isolating idiosyncratic consumption risk.

quietly regress dlnc age age2 i.female i.married i.educat ///
    hh_size n_children i.urban i.year

predict double resid_dlnc, residuals

* Residual variance by sector
forvalues s = 0/1 {
    quietly summarize resid_dlnc if informal == `s'
    local rvar_c_`s' = r(Var)
    local rsd_c_`s'  = r(sd)
    local rn_c_`s'   = r(N)
    local sec = cond(`s' == 0, "Formal", "Informal")
    di as text "`sec': Residual Var(dlnC) = " %7.5f `rvar_c_`s'' ///
        "  SD = " %7.5f `rsd_c_`s'' ///
        "  N = " `rn_c_`s''
}

di as text _n "Variance reduction from removing observables:"
di as text "  Formal:   " %5.1f (1 - `rvar_c_0'/`var_c_0') * 100 "%"
di as text "  Informal: " %5.1f (1 - `rvar_c_1'/`var_c_1') * 100 "%"

* Residual variance test
quietly sdtest resid_dlnc, by(informal)
local F_resid = r(F)
local p_F_resid = r(p)
di as text _n "Residual variance ratio test: F = " %7.3f `F_resid' ///
    "  p = " %6.4f `p_F_resid'

* --- Similarly for income ---
quietly regress dlny_lab age age2 i.female i.married i.educat ///
    hh_size n_children i.urban i.year

predict double resid_dlny, residuals

forvalues s = 0/1 {
    quietly summarize resid_dlny if informal == `s'
    local rvar_y_`s' = r(Var)
    local sec = cond(`s' == 0, "Formal", "Informal")
    di as text "`sec': Residual Var(dlnY) = " %7.5f `rvar_y_`s''
}

* --- Residual variance ratios ---
di as text _n "--- Residual variance ratios: Var(dlnC)/Var(dlnY) ---"
di as text "Formal:   " %7.5f (`rvar_c_0' / `rvar_y_0')
di as text "Informal: " %7.5f (`rvar_c_1' / `rvar_y_1')

*===============================================================================
* 3. PERMANENT/TRANSITORY DECOMPOSITION (GPS APPROACH)
*===============================================================================

di as text _n "=============================================="
di as text    "  3. PERMANENT/TRANSITORY DECOMPOSITION"
di as text    "=============================================="

* Following Guvenen, Pistaferri, and Schivardi (GPS, 2010):
*   y_it = alpha_it + eps_it          (permanent + transitory income)
*   alpha_it = alpha_{i,t-1} + eta_it (random walk permanent component)
*
* Var(dy) = Var(eta) + Var(deps) = Var(eta) + 2*Var(eps)   [if eps iid]
*
* Using autocovariance structure:
*   Cov(dy_t, dy_{t-1}) = -Var(eps)         [MA(1) structure]
*   Var(dy_t)            = Var(eta) + 2*Var(eps)
*
* Same decomposition for consumption.

* --- Compute autocovariances ---
gen double L_resid_dlnc = L.resid_dlnc
gen double L_resid_dlny = L.resid_dlny

* By sector
foreach sector in 0 1 {
    local sec = cond(`sector' == 0, "Formal", "Informal")

    * --- Income decomposition ---
    quietly corr resid_dlny L_resid_dlny if informal == `sector', covariance
    local cov_dy_`sector' = r(cov_12)
    quietly summarize resid_dlny if informal == `sector'
    local var_dy_`sector' = r(Var)

    * Var(eps) = -Cov(dy_t, dy_{t-1})
    local var_eps_y_`sector' = max(-`cov_dy_`sector'', 0)
    * Var(eta) = Var(dy) - 2*Var(eps)
    local var_eta_y_`sector' = max(`var_dy_`sector'' - 2 * `var_eps_y_`sector'', 0)

    di as text _n "`sec' income:"
    di as text "  Cov(dy_t, dy_{t-1}) = " %7.5f `cov_dy_`sector''
    di as text "  Var(dy)             = " %7.5f `var_dy_`sector''
    di as text "  Var(eps_y)          = " %7.5f `var_eps_y_`sector'' "  (transitory)"
    di as text "  Var(eta_y)          = " %7.5f `var_eta_y_`sector'' "  (permanent)"
    if `var_dy_`sector'' > 0 {
        di as text "  Perm share          = " %5.1f ///
            `var_eta_y_`sector'' / `var_dy_`sector'' * 100 "%"
    }

    * --- Consumption decomposition ---
    quietly corr resid_dlnc L_resid_dlnc if informal == `sector', covariance
    local cov_dc_`sector' = r(cov_12)
    quietly summarize resid_dlnc if informal == `sector'
    local var_dc_`sector' = r(Var)

    local var_eps_c_`sector' = max(-`cov_dc_`sector'', 0)
    local var_eta_c_`sector' = max(`var_dc_`sector'' - 2 * `var_eps_c_`sector'', 0)

    di as text "`sec' consumption:"
    di as text "  Cov(dc_t, dc_{t-1}) = " %7.5f `cov_dc_`sector''
    di as text "  Var(dc)             = " %7.5f `var_dc_`sector''
    di as text "  Var(eps_c)          = " %7.5f `var_eps_c_`sector'' "  (transitory)"
    di as text "  Var(eta_c)          = " %7.5f `var_eta_c_`sector'' "  (permanent)"

    * --- Insurance coefficients ---
    * phi (permanent): Var(eta_c) / Var(eta_y)
    * psi (transitory): Var(eps_c) / Var(eps_y)
    if `var_eta_y_`sector'' > 0 {
        local phi_`sector' = `var_eta_c_`sector'' / `var_eta_y_`sector''
    }
    else {
        local phi_`sector' = .
    }
    if `var_eps_y_`sector'' > 0 {
        local psi_`sector' = `var_eps_c_`sector'' / `var_eps_y_`sector''
    }
    else {
        local psi_`sector' = .
    }

    di as text "  phi (permanent insurance)  = " %7.4f `phi_`sector''
    di as text "  psi (transitory insurance) = " %7.4f `psi_`sector''
    di as text ""
}

* --- Cross-sector comparison of insurance ---
di as text _n "--- Insurance comparison ---"
di as text "Permanent (phi):  Formal = " %6.4f `phi_0' "  Informal = " %6.4f `phi_1'
di as text "  (phi = 1 means no insurance; phi = 0 means full insurance)"
di as text "Transitory (psi): Formal = " %6.4f `psi_0' "  Informal = " %6.4f `psi_1'
di as text "  (psi = 1 means no insurance; psi = 0 means full insurance)"

*===============================================================================
* 4. CRRA WELFARE COST CALCULATION
*===============================================================================

di as text _n "=============================================="
di as text    "  4. CRRA WELFARE COSTS"
di as text    "=============================================="

* CRRA welfare cost of consumption variance:
*   W_j = (1/2) * gamma * Var(dlnC_j)
*
* This is the fraction of permanent consumption a risk-averse agent
* would give up to eliminate all consumption volatility.
*
* Express as fraction of permanent consumption.

* --- Create results matrix ---
tempname W
matrix `W' = J(4, 7, .)
matrix colnames `W' = "gamma" "W_formal" "W_informal" "W_gap" "W_gap_pct" "N_formal" "N_informal"

local row = 0
foreach gamma of local gamma_list {
    local ++row

    * Welfare cost using residual variance
    local W_f = 0.5 * `gamma' * `rvar_c_0'
    local W_i = 0.5 * `gamma' * `rvar_c_1'

    * Gap
    local W_gap     = `W_i' - `W_f'
    local W_gap_pct = (`W_i' - `W_f') / `W_f' * 100

    matrix `W'[`row', 1] = `gamma'
    matrix `W'[`row', 2] = `W_f'
    matrix `W'[`row', 3] = `W_i'
    matrix `W'[`row', 4] = `W_gap'
    matrix `W'[`row', 5] = `W_gap_pct'
    matrix `W'[`row', 6] = `rn_c_0'
    matrix `W'[`row', 7] = `rn_c_1'

    di as text "gamma = `gamma':"
    di as text "  Formal:   W = " %8.5f `W_f' " (% of permanent consumption)"
    di as text "  Informal: W = " %8.5f `W_i' " (% of permanent consumption)"
    di as text "  Gap:      dW = " %8.5f `W_gap' " (" %5.1f `W_gap_pct' "% larger)"
}

matrix list `W', format(%9.5f) title("CRRA Welfare Costs (residual variance)")

* --- Also report using raw variance ---
di as text _n "--- Using raw (unadjusted) variance ---"
foreach gamma of local gamma_list {
    local W_f_raw = 0.5 * `gamma' * `var_c_0'
    local W_i_raw = 0.5 * `gamma' * `var_c_1'
    di as text "gamma = `gamma':  Formal = " %8.5f `W_f_raw' ///
        "  Informal = " %8.5f `W_i_raw' ///
        "  Gap = " %8.5f (`W_i_raw' - `W_f_raw')
}

*===============================================================================
* 5. WELFARE COST WITH PERMANENT/TRANSITORY COMPONENTS
*===============================================================================

di as text _n "=============================================="
di as text    "  5. WELFARE COST -- DECOMPOSED"
di as text    "=============================================="

* Using rho = 0.05 (5% discount rate) for present value of permanent shocks
* W_j = (1/2)*gamma*[Var(eta_c)/rho + Var(eps_c)]
*
* Permanent shocks are discounted at rate rho because they affect all
* future consumption. Transitory shocks affect only one period.

tempname WD
matrix `WD' = J(4, 8, .)
matrix colnames `WD' = "gamma" "W_perm_F" "W_perm_I" "W_trans_F" "W_trans_I" ///
    "W_total_F" "W_total_I" "W_gap"

local row = 0
foreach gamma of local gamma_list {
    local ++row

    * Permanent component welfare cost: discounted at rho
    local W_perm_f = 0.5 * `gamma' * `var_eta_c_0' / `rho'
    local W_perm_i = 0.5 * `gamma' * `var_eta_c_1' / `rho'

    * Transitory component welfare cost: one-period
    local W_trans_f = 0.5 * `gamma' * `var_eps_c_0'
    local W_trans_i = 0.5 * `gamma' * `var_eps_c_1'

    * Total
    local W_tot_f = `W_perm_f' + `W_trans_f'
    local W_tot_i = `W_perm_i' + `W_trans_i'

    matrix `WD'[`row', 1] = `gamma'
    matrix `WD'[`row', 2] = `W_perm_f'
    matrix `WD'[`row', 3] = `W_perm_i'
    matrix `WD'[`row', 4] = `W_trans_f'
    matrix `WD'[`row', 5] = `W_trans_i'
    matrix `WD'[`row', 6] = `W_tot_f'
    matrix `WD'[`row', 7] = `W_tot_i'
    matrix `WD'[`row', 8] = `W_tot_i' - `W_tot_f'

    di as text "gamma = `gamma' (rho = `rho'):"
    di as text "  Permanent:  Formal = " %8.5f `W_perm_f'  "  Informal = " %8.5f `W_perm_i'
    di as text "  Transitory: Formal = " %8.5f `W_trans_f'  "  Informal = " %8.5f `W_trans_i'
    di as text "  Total:      Formal = " %8.5f `W_tot_f'    "  Informal = " %8.5f `W_tot_i'
    di as text "  Gap (I-F):  " %8.5f (`W_tot_i' - `W_tot_f')
    di as text "  Share from permanent: " ///
        %5.1f ((`W_perm_i' - `W_perm_f') / (`W_tot_i' - `W_tot_f') * 100) "%"
}

matrix list `WD', format(%9.5f) title("Decomposed Welfare Costs")

* Export decomposed welfare table
preserve
    clear
    svmat `WD'
    rename `WD'1 gamma
    rename `WD'2 W_perm_formal
    rename `WD'3 W_perm_informal
    rename `WD'4 W_trans_formal
    rename `WD'5 W_trans_informal
    rename `WD'6 W_total_formal
    rename `WD'7 W_total_informal
    rename `WD'8 W_gap
    export delimited using "$tables/W6_decomposed_welfare.csv", replace
restore

*===============================================================================
* 6. COUNTERFACTUAL: WHAT IF INFORMAL HAD FORMAL VARIANCE?
*===============================================================================

di as text _n "=============================================="
di as text    "  6. COUNTERFACTUAL ANALYSIS"
di as text    "=============================================="

* Compensating variation: how much consumption would informal workers
* need to receive to be indifferent between their actual variance
* and the formal-sector variance?
*
* Under CRRA: CV = 1 - exp(-0.5 * gamma * [Var_I - Var_F])
* This is the fraction of consumption an informal worker would
* pay to obtain formal-sector consumption risk.

di as text "Compensating variation (fraction of consumption):"
di as text "  (using residual variance)"
foreach gamma of local gamma_list {
    local cv = 1 - exp(-0.5 * `gamma' * (`rvar_c_1' - `rvar_c_0'))
    di as text "  gamma = `gamma': CV = " %8.6f `cv' ///
        " (" %5.3f `cv' * 100 "% of consumption)"
}

* --- Also compute using decomposed components ---
di as text _n "Compensating variation (decomposed, rho = `rho'):"
foreach gamma of local gamma_list {
    local cv_perm  = 1 - exp(-0.5 * `gamma' * (`var_eta_c_1' - `var_eta_c_0') / `rho')
    local cv_trans = 1 - exp(-0.5 * `gamma' * (`var_eps_c_1' - `var_eps_c_0'))
    di as text "  gamma = `gamma':  CV(perm) = " %8.6f `cv_perm' ///
        "  CV(trans) = " %8.6f `cv_trans'
}

* --- In ruble terms ---
* Mean consumption levels
quietly summarize cons_nondur_eq if informal == 0
local mean_c_formal = r(mean)
quietly summarize cons_nondur_eq if informal == 1
local mean_c_informal = r(mean)

di as text _n "Monthly consumption (Dec 2016 rubles):"
di as text "  Formal mean:   " %10.0f `mean_c_formal'
di as text "  Informal mean: " %10.0f `mean_c_informal'

di as text _n "Welfare cost in monthly rubles (Dec 2016):"
tempname RUB
matrix `RUB' = J(4, 4, .)
matrix colnames `RUB' = "gamma" "CV_pct" "CV_rubles_month" "CV_rubles_year"

local row = 0
foreach gamma of local gamma_list {
    local ++row
    local cv = 1 - exp(-0.5 * `gamma' * (`rvar_c_1' - `rvar_c_0'))
    local rub_month = `cv' * `mean_c_informal'
    local rub_year  = `rub_month' * 12

    matrix `RUB'[`row', 1] = `gamma'
    matrix `RUB'[`row', 2] = `cv' * 100
    matrix `RUB'[`row', 3] = `rub_month'
    matrix `RUB'[`row', 4] = `rub_year'

    di as text "  gamma = `gamma': " %10.0f `rub_month' ///
        " rubles/month  (" %10.0f `rub_year' " rubles/year)"
}

matrix list `RUB', format(%10.2f) title("Welfare cost in rubles")

*===============================================================================
* 7. FRACTION OF WAGE GAP EXPLAINED
*===============================================================================

di as text _n "=============================================="
di as text    "  7. WAGE GAP DECOMPOSITION"
di as text    "=============================================="

* How much of the formal-informal wage gap is explained by
* the welfare cost of higher consumption volatility?

quietly summarize labor_inc_eq if informal == 0
local mean_w_f = r(mean)
quietly summarize labor_inc_eq if informal == 1
local mean_w_i = r(mean)

local wage_gap     = `mean_w_f' - `mean_w_i'
local wage_gap_pct = (`mean_w_f' - `mean_w_i') / `mean_w_f' * 100

di as text "Mean monthly labor income (Dec 2016 rubles):"
di as text "  Formal:   " %10.0f `mean_w_f'
di as text "  Informal: " %10.0f `mean_w_i'
di as text "  Gap:      " %10.0f `wage_gap' " (" %5.1f `wage_gap_pct' "%)"

di as text _n "Fraction of wage gap explained by welfare cost of excess volatility:"
tempname WGAP
matrix `WGAP' = J(4, 4, .)
matrix colnames `WGAP' = "gamma" "CV_rubles" "wage_gap" "pct_explained"

local row = 0
foreach gamma of local gamma_list {
    local ++row
    local cv = 1 - exp(-0.5 * `gamma' * (`rvar_c_1' - `rvar_c_0'))
    local rub = `cv' * `mean_c_informal'

    matrix `WGAP'[`row', 1] = `gamma'
    matrix `WGAP'[`row', 2] = `rub'
    matrix `WGAP'[`row', 3] = `wage_gap'

    if `wage_gap' > 0 {
        local frac = `rub' / `wage_gap' * 100
        matrix `WGAP'[`row', 4] = `frac'
        di as text "  gamma = `gamma': " %5.1f `frac' "% of wage gap" ///
            " (" %8.0f `rub' " / " %8.0f `wage_gap' " rubles)"
    }
    else {
        di as text "  gamma = `gamma': wage gap is non-positive — cannot compute"
    }
}

matrix list `WGAP', format(%10.2f) title("Fraction of wage gap explained")

* Export wage gap table
preserve
    clear
    svmat `WGAP'
    rename `WGAP'1 gamma
    rename `WGAP'2 CV_rubles
    rename `WGAP'3 wage_gap
    rename `WGAP'4 pct_explained
    export delimited using "$tables/W6_wage_gap_explained.csv", replace
restore

*===============================================================================
* 8. WELFARE COSTS OVER TIME
*===============================================================================

di as text _n "=============================================="
di as text    "  8. TIME VARIATION IN WELFARE COSTS"
di as text    "=============================================="

* Compute Var(dlnC) by year and sector using residual variance
* First, get residual variance by year-sector cell

* Determine year range
quietly summarize year
local ymin = r(min)
local ymax = r(max)
local nyears = `ymax' - `ymin' + 1

tempname VT
matrix `VT' = J(`nyears', 8, .)
matrix colnames `VT' = "year" "var_formal" "var_informal" "rvar_formal" ///
    "rvar_informal" "W_gap_g1" "W_gap_g2" "N"

local row = 0
forvalues y = `ymin'/`ymax' {
    local ++row
    matrix `VT'[`row', 1] = `y'

    * Raw variance
    quietly summarize dlnc if informal == 0 & year == `y'
    local vf = r(Var)
    local nf = r(N)
    matrix `VT'[`row', 2] = `vf'

    quietly summarize dlnc if informal == 1 & year == `y'
    local vi = r(Var)
    local ni = r(N)
    matrix `VT'[`row', 3] = `vi'

    * Residual variance
    quietly summarize resid_dlnc if informal == 0 & year == `y'
    local rvf = r(Var)
    matrix `VT'[`row', 4] = `rvf'

    quietly summarize resid_dlnc if informal == 1 & year == `y'
    local rvi = r(Var)
    matrix `VT'[`row', 5] = `rvi'

    * Welfare gap at gamma = 1
    matrix `VT'[`row', 6] = 0.5 * 1 * (`rvi' - `rvf')

    * Welfare gap at gamma = 2
    matrix `VT'[`row', 7] = 0.5 * 2 * (`rvi' - `rvf')

    * Total observations
    matrix `VT'[`row', 8] = `nf' + `ni'

    di as text "`y': Var_F = " %7.5f `vf' "  Var_I = " %7.5f `vi' ///
        "  ResVar_F = " %7.5f `rvf' "  ResVar_I = " %7.5f `rvi' ///
        "  N = " (`nf' + `ni')
}

matrix list `VT', format(%9.5f) title("Welfare costs over time")

* Save as dataset for plotting in W8
preserve
    clear
    svmat `VT'
    rename `VT'1 year
    rename `VT'2 var_formal
    rename `VT'3 var_informal
    rename `VT'4 rvar_formal
    rename `VT'5 rvar_informal
    rename `VT'6 welfare_gap_g1
    rename `VT'7 welfare_gap_g2
    rename `VT'8 n_obs
    label variable year "Year"
    label variable var_formal "Var(dlnC) formal - raw"
    label variable var_informal "Var(dlnC) informal - raw"
    label variable rvar_formal "Var(dlnC) formal - residual"
    label variable rvar_informal "Var(dlnC) informal - residual"
    label variable welfare_gap_g1 "Welfare gap gamma=1"
    label variable welfare_gap_g2 "Welfare gap gamma=2"
    label variable n_obs "Number of observations"
    save "$data/welfare_costs_by_year.dta", replace
restore

*===============================================================================
* 9. WELFARE COSTS BY SUBGROUP
*===============================================================================

di as text _n "=============================================="
di as text    "  9. SUBGROUP ANALYSIS"
di as text    "=============================================="

* --- Build subgroup results matrix ---
* Rows: education (3) + urban/rural (2) + gender (2) = 7 subgroups
* For each: Var_F, Var_I, W_F(g=2), W_I(g=2), CV(g=2), N_F, N_I

tempname SG
matrix `SG' = J(7, 8, .)
matrix colnames `SG' = "group" "VarC_F" "VarC_I" "W_F_g2" "W_I_g2" "CV_g2_pct" "N_F" "N_I"

* By education
local sgrow = 0
foreach edu in 1 2 3 {
    local ++sgrow
    local edlbl "Low"
    if `edu' == 2 local edlbl "Medium"
    if `edu' == 3 local edlbl "High"

    di as text _n "Education group `edu' (`edlbl'):"
    forvalues s = 0/1 {
        quietly summarize resid_dlnc if informal == `s' & educat == `edu'
        local v = r(Var)
        local n = r(N)
        local sec = cond(`s' == 0, "Formal", "Informal")
        di as text "  `sec': Var(dlnC) = " %7.5f `v' ///
            "  W(gamma=2) = " %7.5f 0.5 * 2 * `v' "  N = " `n'
        if `s' == 0 {
            matrix `SG'[`sgrow', 2] = `v'
            matrix `SG'[`sgrow', 4] = 0.5 * 2 * `v'
            matrix `SG'[`sgrow', 7] = `n'
        }
        else {
            matrix `SG'[`sgrow', 3] = `v'
            matrix `SG'[`sgrow', 5] = 0.5 * 2 * `v'
            matrix `SG'[`sgrow', 8] = `n'
        }
    }
    matrix `SG'[`sgrow', 1] = `edu'
    local cv_sg = (1 - exp(-0.5 * 2 * (`SG'[`sgrow', 3] - `SG'[`sgrow', 2]))) * 100
    matrix `SG'[`sgrow', 6] = `cv_sg'
    di as text "  CV(gamma=2) = " %5.2f `cv_sg' "%"
}

* By urban/rural
foreach u in 0 1 {
    local ++sgrow
    local loc = cond(`u' == 0, "Rural", "Urban")
    di as text _n "`loc':"
    forvalues s = 0/1 {
        quietly summarize resid_dlnc if informal == `s' & urban == `u'
        local v = r(Var)
        local n = r(N)
        local sec = cond(`s' == 0, "Formal", "Informal")
        di as text "  `sec': Var(dlnC) = " %7.5f `v' ///
            "  W(gamma=2) = " %7.5f 0.5 * 2 * `v' "  N = " `n'
        if `s' == 0 {
            matrix `SG'[`sgrow', 2] = `v'
            matrix `SG'[`sgrow', 4] = 0.5 * 2 * `v'
            matrix `SG'[`sgrow', 7] = `n'
        }
        else {
            matrix `SG'[`sgrow', 3] = `v'
            matrix `SG'[`sgrow', 5] = 0.5 * 2 * `v'
            matrix `SG'[`sgrow', 8] = `n'
        }
    }
    matrix `SG'[`sgrow', 1] = 10 + `u'
    local cv_sg = (1 - exp(-0.5 * 2 * (`SG'[`sgrow', 3] - `SG'[`sgrow', 2]))) * 100
    matrix `SG'[`sgrow', 6] = `cv_sg'
    di as text "  CV(gamma=2) = " %5.2f `cv_sg' "%"
}

* By gender
foreach g in 0 1 {
    local ++sgrow
    local gen = cond(`g' == 0, "Male", "Female")
    di as text _n "`gen':"
    forvalues s = 0/1 {
        quietly summarize resid_dlnc if informal == `s' & female == `g'
        local v = r(Var)
        local n = r(N)
        local sec = cond(`s' == 0, "Formal", "Informal")
        di as text "  `sec': Var(dlnC) = " %7.5f `v' ///
            "  W(gamma=2) = " %7.5f 0.5 * 2 * `v' "  N = " `n'
        if `s' == 0 {
            matrix `SG'[`sgrow', 2] = `v'
            matrix `SG'[`sgrow', 4] = 0.5 * 2 * `v'
            matrix `SG'[`sgrow', 7] = `n'
        }
        else {
            matrix `SG'[`sgrow', 3] = `v'
            matrix `SG'[`sgrow', 5] = 0.5 * 2 * `v'
            matrix `SG'[`sgrow', 8] = `n'
        }
    }
    matrix `SG'[`sgrow', 1] = 20 + `g'
    local cv_sg = (1 - exp(-0.5 * 2 * (`SG'[`sgrow', 3] - `SG'[`sgrow', 2]))) * 100
    matrix `SG'[`sgrow', 6] = `cv_sg'
    di as text "  CV(gamma=2) = " %5.2f `cv_sg' "%"
}

matrix list `SG', format(%9.5f) title("Subgroup welfare costs (gamma=2)")

* Export subgroup table
preserve
    clear
    svmat `SG'
    gen subgroup = ""
    replace subgroup = "Edu: Low"    in 1
    replace subgroup = "Edu: Medium" in 2
    replace subgroup = "Edu: High"   in 3
    replace subgroup = "Rural"       in 4
    replace subgroup = "Urban"       in 5
    replace subgroup = "Male"        in 6
    replace subgroup = "Female"      in 7
    rename `SG'2 VarC_formal
    rename `SG'3 VarC_informal
    rename `SG'4 W_formal_g2
    rename `SG'5 W_informal_g2
    rename `SG'6 CV_g2_pct
    rename `SG'7 N_formal
    rename `SG'8 N_informal
    drop `SG'1
    order subgroup
    export delimited using "$tables/W6_subgroup_welfare.csv", replace
restore

*===============================================================================
* 10. EXPORT MAIN SUMMARY TABLE
*===============================================================================

di as text _n "=============================================="
di as text    "  10. EXPORT SUMMARY TABLE"
di as text    "=============================================="

* Build comprehensive summary: raw + residual + decomposed, for each gamma
tempname R
matrix `R' = J(8, 10, .)
matrix colnames `R' = "gamma" "method" "VarC_F" "VarC_I" "W_F_pct" "W_I_pct" ///
    "W_gap_pct" "CV_pct" "CV_rub_month" "CV_rub_year"

* method: 1 = raw, 2 = residual
local row = 0

* Raw variance based
foreach gamma of local gamma_list {
    local ++row
    local W_f = 0.5 * `gamma' * `var_c_0'
    local W_i = 0.5 * `gamma' * `var_c_1'
    local cv  = 1 - exp(-0.5 * `gamma' * (`var_c_1' - `var_c_0'))

    matrix `R'[`row', 1]  = `gamma'
    matrix `R'[`row', 2]  = 1
    matrix `R'[`row', 3]  = `var_c_0'
    matrix `R'[`row', 4]  = `var_c_1'
    matrix `R'[`row', 5]  = `W_f' * 100
    matrix `R'[`row', 6]  = `W_i' * 100
    matrix `R'[`row', 7]  = (`W_i' - `W_f') * 100
    matrix `R'[`row', 8]  = `cv' * 100
    matrix `R'[`row', 9]  = `cv' * `mean_c_informal'
    matrix `R'[`row', 10] = `cv' * `mean_c_informal' * 12
}

* Residual variance based
foreach gamma of local gamma_list {
    local ++row
    local W_f = 0.5 * `gamma' * `rvar_c_0'
    local W_i = 0.5 * `gamma' * `rvar_c_1'
    local cv  = 1 - exp(-0.5 * `gamma' * (`rvar_c_1' - `rvar_c_0'))

    matrix `R'[`row', 1]  = `gamma'
    matrix `R'[`row', 2]  = 2
    matrix `R'[`row', 3]  = `rvar_c_0'
    matrix `R'[`row', 4]  = `rvar_c_1'
    matrix `R'[`row', 5]  = `W_f' * 100
    matrix `R'[`row', 6]  = `W_i' * 100
    matrix `R'[`row', 7]  = (`W_i' - `W_f') * 100
    matrix `R'[`row', 8]  = `cv' * 100
    matrix `R'[`row', 9]  = `cv' * `mean_c_informal'
    matrix `R'[`row', 10] = `cv' * `mean_c_informal' * 12
}

matrix list `R', format(%9.4f) title("Summary: CRRA Welfare Costs")

* Export
preserve
    clear
    svmat `R'
    gen method_label = "Raw" if `R'2 == 1
    replace method_label = "Residual" if `R'2 == 2
    rename `R'1  gamma
    rename `R'3  VarC_formal
    rename `R'4  VarC_informal
    rename `R'5  W_formal_pct
    rename `R'6  W_informal_pct
    rename `R'7  W_gap_pct
    rename `R'8  CV_pct
    rename `R'9  CV_rubles_month
    rename `R'10 CV_rubles_year
    drop `R'2
    order method_label gamma
    export delimited using "$tables/W6_welfare_summary.csv", replace
restore

*===============================================================================

di as text _n "=============================================="
di as text    "  Step W6 complete."
di as text    "=============================================="
di as text    "  Key output files:"
di as text    "    $tables/W6_welfare_summary.csv"
di as text    "    $tables/W6_decomposed_welfare.csv"
di as text    "    $tables/W6_wage_gap_explained.csv"
di as text    "    $tables/W6_subgroup_welfare.csv"
di as text    "    $data/welfare_costs_by_year.dta"

log close
