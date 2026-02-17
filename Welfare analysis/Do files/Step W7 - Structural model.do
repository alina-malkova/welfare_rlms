/*==============================================================================
  Step W7 - Structural lifecycle model (outline)

  Project:  Welfare Cost of Labor Informality
  Purpose:  Outline a structural lifecycle model with endogenous sector
            choice and credit constraints; calibrate to reduced-form evidence
  Input:    Welfare analysis/Data/welfare_panel_shocks.dta
            Reduced-form estimates from Steps W4-W6
  Output:   Welfare analysis/Results/Tables/W7_*.csv

  Sections:
    1. Model specification (detailed comments)
    2. Calibration targets from data (8 target moments)
    3. Parameter table (externally calibrated + to estimate)
    4. Simulated method of moments (SMM) setup
    5. Value function iteration (VFI) outline
    6. Simplified counterfactual: if informal had formal-sector beta
    7. Credit equalization counterfactual using CMA variation

  Note: Full structural estimation requires Mata or an external solver.
  This file computes the empirical inputs and outlines the algorithm.

  Author:
  Created:  February 2026
==============================================================================*/

clear all
capture set maxvar 32767
do "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/Credit market (1)/Welfare analysis/Do files/welfare_globals.do"

capture log close
log using "$logdir/Step_W7_structural.log", replace

*===============================================================================
* 1. MODEL SPECIFICATION
*===============================================================================

/*
  LIFECYCLE MODEL WITH ENDOGENOUS SECTOR CHOICE AND CREDIT CONSTRAINTS
  ====================================================================

  Environment:
    - T-period lifecycle (T = 40, corresponding to ages 20-59)
    - Two sectors: Formal (s=0) and Informal (s=1)
    - Incomplete markets: no state-contingent claims
    - Differential borrowing constraints by sector

  Timing within period t:
    1. Agent enters with assets a_t, permanent productivity z_t,
       previous sector s_{t-1}
    2. Agent observes current-period shocks (eta_t, eps_t)
    3. Agent chooses:
       - Sector: s_t in {Formal, Informal}
       - Consumption: c_t >= 0
       - Savings: a_{t+1} = (1+r)*a_t + y_t(s_t) - c_t
    4. Subject to sector-specific borrowing constraint:
       - Formal:    a_{t+1} >= -b_F   (can borrow up to b_F)
       - Informal:  a_{t+1} >= -b_I   (b_I < b_F, income not verifiable)

  Preferences:
    - Period utility:  u(c) = c^{1-gamma} / (1-gamma)   [CRRA]
    - Discount factor: beta
    - No labor-leisure choice (extensive margin only: sector choice)

  Income process:
    - Permanent component (random walk):
        ln(z_t) = ln(z_{t-1}) + eta_t,   eta ~ N(0, sigma_eta_s^2)
    - Observed earnings:
        ln(y_t) = ln(w_s) + ln(z_t) + eps_t,   eps ~ N(0, sigma_eps_s^2)
    - Wage levels: w_F > w_I (formal wage premium)
    - Variance components differ by sector:
        sigma_eta_F, sigma_eps_F for formal
        sigma_eta_I, sigma_eps_I for informal

  Sector choice:
    - Formal: higher mean wage w_F, better credit access (b_F),
              possible social insurance (UI, pensions)
    - Informal: lower mean wage w_I, restricted credit (b_I < b_F),
                higher income variance, no social insurance
    - Switching cost kappa: if s_t != s_{t-1}, pay kappa units of
      consumption equivalent. This captures job search frictions,
      retraining costs, and bureaucratic hurdles.

  State space:
    S = {a, z, s_{t-1}, age}
    where a in [a_min, a_max], z discretized via Tauchen method,
    s in {0, 1}, age in {1, ..., T}

  Value function:
    V(a, z, s, age) = max_{s', c} { u(c) - kappa*I(s'!=s)
                       + beta * E[V(a', z', s', age+1) | z] }

    subject to:
      a' = (1+r)*a + y(s') - c
      a' >= -b_{s'}
      c > 0

  Terminal condition:
    V(a, z, s, T+1) = u((1+r)*a)   [consume all remaining assets]

  KEY MECHANISM:
    Informal workers face b_I < b_F. When hit by income shocks,
    they cannot borrow as much, leading to larger consumption drops.
    This generates higher Var(dlnC) for informal workers even
    conditional on similar income processes.

  COUNTERFACTUAL EXPERIMENTS:
    CF1: Set b_I = b_F (equalize credit access)
         -> How much does Var(dlnC)_I fall? What is the welfare gain?
    CF2: Set sigma_eta_I = sigma_eta_F, sigma_eps_I = sigma_eps_F
         -> What if informal workers faced formal-sector risk?
    CF3: Remove switching cost kappa = 0
         -> How does informality rate change?
*/

*===============================================================================
* 2. CALIBRATION TARGETS FROM DATA
*===============================================================================

di as text _n "=============================================="
di as text    "  2. CALIBRATION TARGETS"
di as text    "=============================================="

use "$data/welfare_panel_shocks.dta", clear
keep if analysis_sample == 1
xtset idind year

* --- Target 1: Informality rate ---
quietly summarize informal
local target_inf_rate = r(mean)
local target_inf_rate_se = r(sd) / sqrt(r(N))
di as text "T1. Informality rate:          " %6.4f `target_inf_rate' ///
    " (SE = " %6.4f `target_inf_rate_se' ")"

* --- Target 2: Formal-informal wage ratio ---
quietly summarize labor_inc_eq if informal == 0
local mean_w_f = r(mean)
quietly summarize labor_inc_eq if informal == 1
local mean_w_i = r(mean)
local wage_ratio = `mean_w_f' / `mean_w_i'
di as text "T2. Wage ratio (F/I):          " %6.3f `wage_ratio'

* --- Target 3: Consumption smoothing coefficients ---
* (replicates key result from Step W4)
quietly regress dlnc dlny_lab if informal == 0, vce(cluster idind)
local beta_formal    = _b[dlny_lab]
local beta_formal_se = _se[dlny_lab]
quietly regress dlnc dlny_lab if informal == 1, vce(cluster idind)
local beta_informal    = _b[dlny_lab]
local beta_informal_se = _se[dlny_lab]
di as text "T3. beta (formal):             " %6.4f `beta_formal' ///
    " (SE = " %6.4f `beta_formal_se' ")"
di as text "T4. beta (informal):           " %6.4f `beta_informal' ///
    " (SE = " %6.4f `beta_informal_se' ")"

* --- Target 4: Income variance components ---
* (replicates GPS decomposition from Step W6)
gen double L_dlny = L.dlny_lab

foreach s in 0 1 {
    quietly corr dlny_lab L_dlny if informal == `s', covariance
    local cov_`s' = r(cov_12)
    quietly summarize dlny_lab if informal == `s'
    local var_`s' = r(Var)
    local var_eps_`s' = max(-`cov_`s'', 0)
    local var_eta_`s' = max(`var_`s'' - 2 * `var_eps_`s'', 0)
}
di as text "T5. Income Var(eta) formal:    " %7.5f `var_eta_0'
di as text "T6. Income Var(eta) informal:  " %7.5f `var_eta_1'
di as text "T7. Income Var(eps) formal:    " %7.5f `var_eps_0'
di as text "T8. Income Var(eps) informal:  " %7.5f `var_eps_1'

* --- Target 5: Transition rates ---
quietly summarize trans_form_to_inf if L_informal == 0
local trans_f_to_i = r(mean)
local trans_f_to_i_se = r(sd) / sqrt(r(N))
quietly summarize trans_inf_to_form if L_informal == 1
local trans_i_to_f = r(mean)
local trans_i_to_f_se = r(sd) / sqrt(r(N))
di as text "T9.  Transition F->I:          " %6.4f `trans_f_to_i' ///
    " (SE = " %6.4f `trans_f_to_i_se' ")"
di as text "T10. Transition I->F:          " %6.4f `trans_i_to_f' ///
    " (SE = " %6.4f `trans_i_to_f_se' ")"

* --- Target 6: Credit access rates ---
local credit_formal   = .
local credit_informal = .
capture confirm variable has_formal_credit
if _rc == 0 {
    quietly summarize has_formal_credit if informal == 0
    local credit_formal = r(mean)
    quietly summarize has_formal_credit if informal == 1
    local credit_informal = r(mean)
    di as text "T11. Formal credit (formal):   " %6.4f `credit_formal'
    di as text "T12. Formal credit (informal): " %6.4f `credit_informal'
}
else {
    di as text "T11-T12. Formal credit access: variable not available"
}

* --- Target 7: Savings rate proxy ---
local save_formal   = .
local save_informal = .
capture confirm variable buffer_low
if _rc == 0 {
    quietly summarize buffer_low if informal == 0
    local buffer_formal = r(mean)
    quietly summarize buffer_low if informal == 1
    local buffer_informal = r(mean)
    di as text "T13. Buffer < 1 month (formal):   " %6.4f `buffer_formal'
    di as text "T14. Buffer < 1 month (informal): " %6.4f `buffer_informal'
}

* --- Target 8: Consumption variance ---
quietly summarize dlnc if informal == 0
local var_c_formal = r(Var)
quietly summarize dlnc if informal == 1
local var_c_informal = r(Var)
di as text "T15. Var(dlnC) formal:         " %7.5f `var_c_formal'
di as text "T16. Var(dlnC) informal:       " %7.5f `var_c_informal'

*===============================================================================
* 3. PARAMETER TABLE
*===============================================================================

di as text _n "=============================================="
di as text    "  3. MODEL PARAMETERS"
di as text    "=============================================="

* --- Externally calibrated parameters ---
di as text _n "--- Externally calibrated ---"
di as text "  beta (discount factor):          0.96"
di as text "  r    (interest rate):            0.04"
di as text "  gamma (risk aversion):           2.00"
di as text "  T    (working life periods):     40 (ages 20-59)"
di as text ""
di as text "  sigma_eta_F (perm shock, formal):   " %7.5f sqrt(`var_eta_0')
di as text "  sigma_eta_I (perm shock, informal): " %7.5f sqrt(`var_eta_1')
di as text "  sigma_eps_F (trans shock, formal):  " %7.5f sqrt(`var_eps_0')
di as text "  sigma_eps_I (trans shock, informal):" %7.5f sqrt(`var_eps_1')
di as text "  w_F / w_I (wage ratio):             " %6.3f `wage_ratio'

* --- Parameters to estimate ---
di as text _n "--- To estimate via SMM ---"
di as text "  b_F  (formal borrowing limit):      to estimate"
di as text "  b_I  (informal borrowing limit):     to estimate (b_I < b_F)"
di as text "  kappa (sector switching cost):       to estimate"
di as text "  sigma_pref (preference heterogeneity): to estimate"

* --- Store parameter table as matrix ---
tempname params
matrix `params' = J(12, 2, .)
matrix colnames `params' = "value" "estimated"
matrix rownames `params' = "beta" "r" "gamma" "T" ///
    "sigma_eta_F" "sigma_eta_I" "sigma_eps_F" "sigma_eps_I" ///
    "b_F" "b_I" "kappa" "sigma_pref"

* Externally calibrated (estimated = 0)
matrix `params'[1,1]  = 0.96
matrix `params'[1,2]  = 0
matrix `params'[2,1]  = 0.04
matrix `params'[2,2]  = 0
matrix `params'[3,1]  = 2.00
matrix `params'[3,2]  = 0
matrix `params'[4,1]  = 40
matrix `params'[4,2]  = 0
matrix `params'[5,1]  = sqrt(`var_eta_0')
matrix `params'[5,2]  = 0
matrix `params'[6,1]  = sqrt(`var_eta_1')
matrix `params'[6,2]  = 0
matrix `params'[7,1]  = sqrt(`var_eps_0')
matrix `params'[7,2]  = 0
matrix `params'[8,1]  = sqrt(`var_eps_1')
matrix `params'[8,2]  = 0

* To estimate (estimated = 1)
matrix `params'[9,1]  = .
matrix `params'[9,2]  = 1
matrix `params'[10,1] = .
matrix `params'[10,2] = 1
matrix `params'[11,1] = .
matrix `params'[11,2] = 1
matrix `params'[12,1] = .
matrix `params'[12,2] = 1

matrix list `params', format(%9.5f) title("Model Parameters")

* Export parameter table
preserve
    clear
    svmat `params'
    gen parameter = ""
    replace parameter = "beta"         in 1
    replace parameter = "r"            in 2
    replace parameter = "gamma"        in 3
    replace parameter = "T"            in 4
    replace parameter = "sigma_eta_F"  in 5
    replace parameter = "sigma_eta_I"  in 6
    replace parameter = "sigma_eps_F"  in 7
    replace parameter = "sigma_eps_I"  in 8
    replace parameter = "b_F"          in 9
    replace parameter = "b_I"          in 10
    replace parameter = "kappa"        in 11
    replace parameter = "sigma_pref"   in 12
    rename `params'1 value
    rename `params'2 estimated
    gen source = "Externally calibrated" if estimated == 0
    replace source = "SMM estimation" if estimated == 1
    order parameter value source estimated
    export delimited using "$tables/W7_parameters.csv", replace
restore

*===============================================================================
* 4. SIMULATED METHOD OF MOMENTS (SMM) SETUP
*===============================================================================

di as text _n "=============================================="
di as text    "  4. SMM -- MOMENT CONDITIONS"
di as text    "=============================================="

/*
  SIMULATED METHOD OF MOMENTS (SMM)
  ==================================

  Objective: Choose theta = {b_F, b_I, kappa, sigma_pref} to minimize

    Q(theta) = [m_data - m_model(theta)]' * W * [m_data - m_model(theta)]

  where:
    m_data    = vector of empirical moments (from RLMS)
    m_model() = corresponding moments from simulated model
    W         = weighting matrix

  Moment conditions (10 moments, 4 parameters -> overidentified):
  ----------------------------------------------------------------
  m1:  Informality rate
  m2:  Formal-informal wage ratio
  m3:  Transition rate F -> I
  m4:  Transition rate I -> F
  m5:  beta_formal (consumption smoothing coefficient, formal)
  m6:  beta_informal (consumption smoothing coefficient, informal)
  m7:  Var(dlnC) formal
  m8:  Var(dlnC) informal
  m9:  Credit access rate, formal workers
  m10: Credit access rate, informal workers

  Weighting matrix:
  - Step 1: Identity matrix (equally weighted moments)
  - Step 2: Diagonal matrix with inverse moment variances
  - Step 3: Optimal weighting (inverse of bootstrap covariance matrix)

  Standard errors:
  - Bootstrap the entire estimation procedure (data moments + SMM)
  - B = 200 bootstrap replications

  Identification:
  - b_F, b_I identified by credit access rates + smoothing coefficients
  - kappa identified by transition rates
  - sigma_pref identified by informality rate dispersion

  IMPLEMENTATION STRATEGY:
  - Inner loop: VFI to solve model for given theta
  - Simulation: draw N_sim = 10,000 agents, T = 40 periods
  - Compute model moments from simulated panel
  - Outer loop: Nelder-Mead simplex to minimize Q(theta)
*/

* Save calibration targets as matrix for SMM
tempname targets
matrix `targets' = J(10, 3, .)
matrix colnames `targets' = "target" "se" "weight"
matrix rownames `targets' = "inf_rate" "wage_ratio" "trans_fi" "trans_if" ///
    "beta_formal" "beta_informal" "varC_formal" "varC_informal" ///
    "credit_formal" "credit_informal"

matrix `targets'[1, 1] = `target_inf_rate'
matrix `targets'[2, 1] = `wage_ratio'
matrix `targets'[3, 1] = `trans_f_to_i'
matrix `targets'[4, 1] = `trans_i_to_f'
matrix `targets'[5, 1] = `beta_formal'
matrix `targets'[6, 1] = `beta_informal'
matrix `targets'[7, 1] = `var_c_formal'
matrix `targets'[8, 1] = `var_c_informal'
matrix `targets'[9, 1] = `credit_formal'
matrix `targets'[10, 1] = `credit_informal'

* Standard errors (approximate)
matrix `targets'[1, 2] = `target_inf_rate_se'
matrix `targets'[3, 2] = `trans_f_to_i_se'
matrix `targets'[4, 2] = `trans_i_to_f_se'
matrix `targets'[5, 2] = `beta_formal_se'
matrix `targets'[6, 2] = `beta_informal_se'

* Weights: inverse of squared SE (where available), else 1
forvalues i = 1/10 {
    if `targets'[`i', 2] != . & `targets'[`i', 2] > 0 {
        matrix `targets'[`i', 3] = 1 / (`targets'[`i', 2]^2)
    }
    else {
        matrix `targets'[`i', 3] = 1
    }
}

matrix list `targets', format(%9.5f) title("SMM Calibration Targets")

* Export targets
preserve
    clear
    svmat `targets'
    gen moment = ""
    replace moment = "Informality rate"           in 1
    replace moment = "Wage ratio (F/I)"           in 2
    replace moment = "Transition F->I"            in 3
    replace moment = "Transition I->F"            in 4
    replace moment = "beta (formal)"              in 5
    replace moment = "beta (informal)"            in 6
    replace moment = "Var(dlnC) formal"           in 7
    replace moment = "Var(dlnC) informal"         in 8
    replace moment = "Credit access (formal)"     in 9
    replace moment = "Credit access (informal)"   in 10
    rename `targets'1 target_value
    rename `targets'2 standard_error
    rename `targets'3 smm_weight
    order moment
    export delimited using "$tables/W7_calibration_targets.csv", replace
restore

*===============================================================================
* 5. VALUE FUNCTION ITERATION -- OUTLINE
*===============================================================================

di as text _n "=============================================="
di as text    "  5. VALUE FUNCTION ITERATION (OUTLINE)"
di as text    "=============================================="

/*
  SOLUTION ALGORITHM
  ==================

  1. DISCRETIZE STATE SPACE:
     - Assets: a in {a_min, ..., a_max}
       * a_min = -max(b_F, b_I) (natural borrowing limit)
       * a_max = 20 * mean(y) (generous upper bound)
       * N_a = 200 grid points (denser near borrowing limit)
       * Grid: use double-exponential spacing for accuracy near constraint
     - Permanent productivity: z in {z_1, ..., z_Nz}
       * N_z = 9 grid points
       * Tauchen (1986) method with 3 standard deviations
       * Separate transition matrices for each sector
     - Sector: s in {0 (formal), 1 (informal)}
     - Age: t in {1, ..., T}
     - Total state points: N_a * N_z * 2 * T = 200 * 9 * 2 * 40 = 144,000

  2. TERMINAL CONDITION:
     V(a, z, s, T+1) = u((1+r)*a + y_T)
     (Consume all remaining wealth in final period)

  3. BACKWARD INDUCTION: for t = T, T-1, ..., 1
     For each state (a, z, s):
       For each candidate sector s' in {0, 1}:
         * Switching cost: kappa_cost = kappa * I(s' != s)
         * Expected income: E[y | z, s']
         * For each candidate a':
           - Budget constraint: c = (1+r)*a + y - a' - kappa_cost
           - Check feasibility: c > 0 and a' >= -b_{s'}
           - Current utility: u(c)
           - Continuation: beta * sum_z' [ pi(z'|z,s') * V_{t+1}(a', z', s') ]
           - Total value: u(c) + continuation
         * Optimal savings: a'*(a, z, s, s') = argmax
       * Optimal sector: s'*(a, z, s) = argmax over {0, 1}
       * V_t(a, z, s) = max value
       * Store policy functions: c*(.), a'*(.), s'*(.)

  4. FORWARD SIMULATION:
     - Draw N_sim = 10,000 agents
     - Initial conditions:
       * a_0 = 0 (no initial assets)
       * z_0 ~ N(0, sigma_z0^2) (calibrate to cross-sectional dispersion)
       * s_0: draw from stationary sector distribution
     - For t = 1, ..., T:
       * Draw shocks: eta ~ N(0, sigma_eta_s^2), eps ~ N(0, sigma_eps_s^2)
       * Update z: z_t = z_{t-1} + eta_t
       * Income: y_t = w_{s_t} * exp(z_t + eps_t)
       * Apply policy functions: s_t, c_t, a_{t+1}
     - Compute model moments from simulated panel

  5. OUTER LOOP:
     - Initialize theta_0 = {b_F=2, b_I=0.5, kappa=0.3, sigma_pref=0.2}
     - Use Nelder-Mead simplex or BFGS to minimize Q(theta)
     - Convergence: ||theta_{k+1} - theta_k|| < 1e-6
     - Check multiple starting points for global minimum

  IMPLEMENTATION NOTE:
  Full VFI is best implemented in Mata (Stata's matrix language) or
  externally in Julia/Fortran. The Stata code below provides simplified
  counterfactuals using reduced-form estimates as inputs.
*/

di as text "  VFI algorithm specified in comments."
di as text "  State space: 200 (assets) x 9 (productivity) x 2 (sector) x 40 (age)"
di as text "  = 144,000 state points per iteration."
di as text "  Simulation: 10,000 agents x 40 periods = 400,000 obs."

*===============================================================================
* 6. SIMPLIFIED COUNTERFACTUAL SIMULATION
*===============================================================================

di as text _n "=============================================="
di as text    "  6. SIMPLIFIED COUNTERFACTUAL SIMULATION"
di as text    "=============================================="

* Without full structural estimation, we compute back-of-envelope
* counterfactuals using reduced-form estimates.
*
* KEY QUESTION: What if informal workers had the same consumption
* smoothing coefficient as formal workers?
*
* From Step W4:
*   beta_formal:   consumption sensitivity for formal workers
*   beta_informal: consumption sensitivity for informal workers
*
* Under the model, Var(dlnC) = beta^2 * Var(dlnY) + Var(meas. error)
* Counterfactual Var(dlnC)_I if beta_I -> beta_F:
*   Var(dlnC)_cf = (beta_F / beta_I)^2 * [Var(dlnC)_I - Var_noise] + Var_noise
*
* Approximation (ignoring measurement error):
*   Var(dlnC)_cf approx Var(dlnC)_I * (beta_F / beta_I)^2

di as text "Consumption smoothing coefficients:"
di as text "  beta (formal):   " %6.4f `beta_formal'
di as text "  beta (informal): " %6.4f `beta_informal'

if `beta_informal' != 0 & `beta_formal' != 0 {
    local var_ratio = (`beta_formal' / `beta_informal')^2
    local var_c_cf = `var_c_informal' * `var_ratio'

    di as text _n "Counterfactual: if informal had formal-sector beta..."
    di as text "  Var(dlnC)_I actual:        " %7.5f `var_c_informal'
    di as text "  Var(dlnC)_I counterfactual:" %7.5f `var_c_cf'
    di as text "  Variance reduction:        " %5.1f (1 - `var_ratio') * 100 "%"

    * Welfare gain from equalizing smoothing
    tempname CF
    matrix `CF' = J(4, 5, .)
    matrix colnames `CF' = "gamma" "W_actual" "W_cf" "W_gain" "W_gain_pct"

    local row = 0
    foreach gamma of numlist 1 2 3 5 {
        local ++row
        local W_actual = 0.5 * `gamma' * `var_c_informal'
        local W_cf     = 0.5 * `gamma' * `var_c_cf'
        local W_gain   = `W_actual' - `W_cf'
        local W_gain_pct = `W_gain' * 100

        matrix `CF'[`row', 1] = `gamma'
        matrix `CF'[`row', 2] = `W_actual'
        matrix `CF'[`row', 3] = `W_cf'
        matrix `CF'[`row', 4] = `W_gain'
        matrix `CF'[`row', 5] = `W_gain_pct'

        di as text "  gamma = `gamma': welfare gain = " %7.5f `W_gain' ///
            " (" %5.2f `W_gain_pct' "% of consumption)"
    }

    matrix list `CF', format(%9.5f) title("Counterfactual: equalize smoothing")

    * --- Also: what fraction of the total welfare gap is explained? ---
    di as text _n "Fraction of welfare gap explained by smoothing difference:"
    foreach gamma of numlist 1 2 3 5 {
        local W_actual_gap = 0.5 * `gamma' * (`var_c_informal' - `var_c_formal')
        local W_cf_gain    = 0.5 * `gamma' * (`var_c_informal' - `var_c_cf')
        if `W_actual_gap' > 0 {
            di as text "  gamma = `gamma': " %5.1f (`W_cf_gain'/`W_actual_gap'*100) "%"
        }
    }

    * Export counterfactual results
    preserve
        clear
        svmat `CF'
        rename `CF'1 gamma
        rename `CF'2 W_actual
        rename `CF'3 W_counterfactual
        rename `CF'4 W_gain
        rename `CF'5 W_gain_pct
        export delimited using "$tables/W7_counterfactual_smoothing.csv", replace
    restore
}
else {
    di as text "  Cannot compute: beta_formal or beta_informal is zero."
}

*===============================================================================
* 7. CREDIT EQUALIZATION COUNTERFACTUAL
*===============================================================================

di as text _n "=============================================="
di as text    "  7. CREDIT EQUALIZATION COUNTERFACTUAL"
di as text    "=============================================="

* Using the triple-interaction estimate from Step W5:
*   delta_2 = effect of CMA on consumption smoothing gap
*
* Strategy:
*   1. Estimate smoothing coefficients in high vs low CMA areas
*   2. Compute: if all informal had high-CMA smoothing, what is
*      the variance reduction?
*   3. This provides an empirical estimate of the credit mechanism
*      counterfactual that the structural model would deliver.

capture confirm variable cma_high
if _rc == 0 {
    * --- Estimate by CMA and sector ---
    * Informal in high CMA areas
    quietly regress dlnc dlny_lab if informal == 1 & cma_high == 1, vce(cluster idind)
    local beta_i_hcma    = _b[dlny_lab]
    local beta_i_hcma_se = _se[dlny_lab]

    * Informal in low CMA areas
    quietly regress dlnc dlny_lab if informal == 1 & cma_high == 0, vce(cluster idind)
    local beta_i_lcma    = _b[dlny_lab]
    local beta_i_lcma_se = _se[dlny_lab]

    * Formal (pooled)
    quietly regress dlnc dlny_lab if informal == 0, vce(cluster idind)
    local beta_f = _b[dlny_lab]

    di as text "Consumption smoothing by CMA:"
    di as text "  Informal, high CMA: beta = " %6.4f `beta_i_hcma' ///
        " (SE = " %6.4f `beta_i_hcma_se' ")"
    di as text "  Informal, low CMA:  beta = " %6.4f `beta_i_lcma' ///
        " (SE = " %6.4f `beta_i_lcma_se' ")"
    di as text "  Formal (pooled):    beta = " %6.4f `beta_f'

    * --- Variance in high vs low CMA ---
    quietly summarize dlnc if informal == 1 & cma_high == 1
    local var_i_hcma = r(Var)
    quietly summarize dlnc if informal == 1 & cma_high == 0
    local var_i_lcma = r(Var)

    di as text _n "Consumption variance by CMA (informal):"
    di as text "  High CMA: Var(dlnC) = " %7.5f `var_i_hcma'
    di as text "  Low CMA:  Var(dlnC) = " %7.5f `var_i_lcma'

    * --- Fraction of gap explained by credit access ---
    local gap_total = `beta_i_lcma' - `beta_f'
    local gap_cma   = `beta_i_lcma' - `beta_i_hcma'

    if `gap_total' != 0 {
        local frac_explained = `gap_cma' / `gap_total' * 100
        di as text _n "Smoothing gap decomposition:"
        di as text "  Total gap (informal_lowCMA - formal):   " %6.4f `gap_total'
        di as text "  CMA component (lowCMA - highCMA):       " %6.4f `gap_cma'
        di as text "  Credit access explains " %5.1f `frac_explained' ///
            "% of the informal-formal smoothing gap"
    }

    * --- Welfare gain from credit equalization ---
    * Counterfactual: all informal workers get high-CMA smoothing
    if `beta_i_lcma' != 0 {
        local var_cf_credit = `var_c_informal' * (`beta_i_hcma' / `beta_i_lcma')^2

        di as text _n "Credit equalization counterfactual:"
        di as text "  Var(dlnC)_I actual:        " %7.5f `var_c_informal'
        di as text "  Var(dlnC)_I if all high CMA: " %7.5f `var_cf_credit'
        di as text "  Variance reduction:        " ///
            %5.1f (1 - (`beta_i_hcma'/`beta_i_lcma')^2) * 100 "%"

        tempname CFC
        matrix `CFC' = J(4, 5, .)
        matrix colnames `CFC' = "gamma" "W_actual" "W_cf_credit" "W_gain_credit" "CV_credit_pct"

        local row = 0
        foreach gamma of numlist 1 2 3 5 {
            local ++row
            local W_actual = 0.5 * `gamma' * `var_c_informal'
            local W_cf_cr  = 0.5 * `gamma' * `var_cf_credit'
            local W_gain_cr = `W_actual' - `W_cf_cr'
            local cv_credit = 1 - exp(-0.5 * `gamma' * (`var_c_informal' - `var_cf_credit'))

            matrix `CFC'[`row', 1] = `gamma'
            matrix `CFC'[`row', 2] = `W_actual'
            matrix `CFC'[`row', 3] = `W_cf_cr'
            matrix `CFC'[`row', 4] = `W_gain_cr'
            matrix `CFC'[`row', 5] = `cv_credit' * 100

            di as text "  gamma = `gamma':  gain = " %7.5f `W_gain_cr' ///
                "  CV = " %5.2f `cv_credit'*100 "%"
        }

        matrix list `CFC', format(%9.5f) title("Credit equalization counterfactual")

        * Export
        preserve
            clear
            svmat `CFC'
            rename `CFC'1 gamma
            rename `CFC'2 W_actual
            rename `CFC'3 W_cf_credit
            rename `CFC'4 W_gain_credit
            rename `CFC'5 CV_credit_pct
            export delimited using "$tables/W7_counterfactual_credit.csv", replace
        restore
    }
}
else {
    di as text "CMA variable not available -- skipping credit equalization."
    di as text "To run this counterfactual, construct cma_high from regional"
    di as text "banking data (see Step W3 or the credit market main analysis)."
}

*===============================================================================
* 8. SUMMARY AND NEXT STEPS
*===============================================================================

di as text _n "=============================================="
di as text    "  MODEL SUMMARY"
di as text    "=============================================="

di as text "1. Model specification: lifecycle with endogenous sector choice,"
di as text "   differential borrowing constraints, and switching costs."
di as text "2. Calibration targets computed from RLMS data (Section 2)."
di as text "3. Parameter table: 8 externally calibrated, 4 to estimate (Section 3)."
di as text "4. SMM: 10 moment conditions, diagonal weighting (Section 4)."
di as text "5. VFI: backward induction on 144K state points (Section 5)."
di as text "6. Simplified counterfactual: equalizing smoothing (Section 6)."
di as text "7. Credit equalization counterfactual via CMA (Section 7)."
di as text ""
di as text "NEXT STEPS FOR FULL STRUCTURAL ESTIMATION:"
di as text "  a) Implement VFI in Mata or Julia"
di as text "  b) Code forward simulation to compute model moments"
di as text "  c) Minimize SMM objective using Nelder-Mead"
di as text "  d) Bootstrap standard errors (B = 200)"
di as text "  e) Run counterfactual CF1: set b_I = b_F"
di as text "  f) Run counterfactual CF2: equalize income risk"
di as text "  g) Run counterfactual CF3: remove switching cost"

di as text _n "=============================================="
di as text    "  Step W7 complete."
di as text    "=============================================="
di as text "  Output files:"
di as text "    $tables/W7_parameters.csv"
di as text "    $tables/W7_calibration_targets.csv"
di as text "    $tables/W7_counterfactual_smoothing.csv"
di as text "    $tables/W7_counterfactual_credit.csv"

log close
