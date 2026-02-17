*===============================================================================
* R6: BPP Decomposition (Blundell-Pistaferri-Preston)
*===============================================================================
*
* Problem: The current approach conflates transitory and permanent income
* shocks. BPP decomposition allows separate identification of consumption
* response to permanent (ψ) vs transitory (φ) shocks.
*
* Solution: Implement BPP (2008) methodology:
* - Use income growth covariances to identify shock variances
* - Estimate ψ and φ separately for formal and informal workers
*
* Reference: Blundell, Pistaferri, Preston (2008) AER
*
* Author: Generated for revision
* Date: February 2026
*===============================================================================

clear all
set more off
capture log close

* Load globals
quietly do "${dodir}/welfare_globals.do"

* Start log
log using "${logdir}/R6_bpp_decomposition.log", replace text

di as text _n "=============================================="
di as text    "  R6: BPP Decomposition"
di as text    "      (Permanent vs Transitory Shocks)"
di as text    "=============================================="

*===============================================================================
* 0. SETUP AND DATA
*===============================================================================

* Load data
capture use "$data/welfare_panel_cbr.dta", clear
if _rc != 0 {
    use "$data/welfare_panel_shocks.dta", clear
}

keep if analysis_sample == 1
xtset idind year

*===============================================================================
* 1. BPP FRAMEWORK
*===============================================================================

di as text _n "=============================================="
di as text    "  1. BPP Framework Overview"
di as text    "=============================================="

di as text _n "The BPP model decomposes income process into:"
di as text "  y_it = P_it + v_it"
di as text "  P_it = P_{i,t-1} + ζ_it  (permanent component, random walk)"
di as text "  v_it = transitory shock (MA(q) process)"
di as text ""
di as text "Consumption smoothing:"
di as text "  Δc_it = ψ * ζ_it + φ * Δv_it"
di as text ""
di as text "Key prediction: ψ ≈ 1 (permanent shocks fully pass through)"
di as text "                φ < 1 (transitory shocks smoothed via assets/credit)"

*===============================================================================
* 2. CONSTRUCT LEADS AND LAGS
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Construct Income Leads/Lags"
di as text    "=============================================="

sort idind year

* Income growth leads and lags
by idind: gen dlny_lag1 = dlny_lab[_n-1]
by idind: gen dlny_lag2 = dlny_lab[_n-2]
by idind: gen dlny_lead1 = dlny_lab[_n+1]
by idind: gen dlny_lead2 = dlny_lab[_n+2]

label variable dlny_lag1 "Δln(Y)_{t-1}"
label variable dlny_lag2 "Δln(Y)_{t-2}"
label variable dlny_lead1 "Δln(Y)_{t+1}"
label variable dlny_lead2 "Δln(Y)_{t+2}"

* Consumption growth leads
by idind: gen dlnc_lead1 = dlnc[_n+1]
label variable dlnc_lead1 "Δln(C)_{t+1}"

* Sample with all needed lags/leads
gen byte bpp_sample = !missing(dlnc, dlny_lab, dlny_lag1, dlny_lead1)
count if bpp_sample == 1
local N_bpp = r(N)
di as text "BPP estimation sample: N = `N_bpp'"

*===============================================================================
* 3. MOMENT CONDITIONS FOR SHOCK VARIANCE IDENTIFICATION
*===============================================================================

di as text _n "=============================================="
di as text    "  3. Identify Shock Variances"
di as text    "=============================================="

* Under BPP assumptions:
* Cov(Δy_t, Δy_{t-1}) = -σ²_v (if transitory is MA(0))
* Var(Δy_t) = σ²_ζ + 2σ²_v
*
* So: σ²_v = -Cov(Δy_t, Δy_{t-1})
*     σ²_ζ = Var(Δy_t) - 2σ²_v

* Full sample
sum dlny_lab if bpp_sample == 1
local var_dlny = r(Var)

corr dlny_lab dlny_lag1 if bpp_sample == 1, cov
local cov_dlny_lag = r(cov_12)

local sigma2_v_full = -`cov_dlny_lag'
local sigma2_zeta_full = `var_dlny' - 2 * `sigma2_v_full'

di as text "FULL SAMPLE:"
di as text "  Var(Δy): " %8.5f `var_dlny'
di as text "  Cov(Δy_t, Δy_{t-1}): " %8.5f `cov_dlny_lag'
di as text "  → σ²_v (transitory): " %8.5f `sigma2_v_full'
di as text "  → σ²_ζ (permanent):  " %8.5f `sigma2_zeta_full'

* By formality
foreach group in 0 1 {
    if `group' == 0 {
        di as text _n "FORMAL WORKERS:"
    }
    else {
        di as text _n "INFORMAL WORKERS:"
    }

    sum dlny_lab if bpp_sample == 1 & informal == `group'
    local var_dlny_`group' = r(Var)

    corr dlny_lab dlny_lag1 if bpp_sample == 1 & informal == `group', cov
    local cov_dlny_lag_`group' = r(cov_12)

    local sigma2_v_`group' = -`cov_dlny_lag_`group''
    local sigma2_zeta_`group' = `var_dlny_`group'' - 2 * `sigma2_v_`group''

    di as text "  Var(Δy): " %8.5f `var_dlny_`group''
    di as text "  Cov(Δy_t, Δy_{t-1}): " %8.5f `cov_dlny_lag_`group''
    di as text "  → σ²_v (transitory): " %8.5f `sigma2_v_`group''
    di as text "  → σ²_ζ (permanent):  " %8.5f `sigma2_zeta_`group''
}

*===============================================================================
* 4. BPP CONSUMPTION RESPONSE ESTIMATION
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Estimate ψ and φ"
di as text    "=============================================="

* BPP use covariances of consumption and income changes:
* Cov(Δc_t, Δy_t) = ψ * σ²_ζ + φ * σ²_v
* Cov(Δc_t, Δy_{t+1}) = -φ * σ²_v (under MA(0) transitory)
*
* So: φ = -Cov(Δc_t, Δy_{t+1}) / σ²_v
*     ψ = [Cov(Δc_t, Δy_t) - φ * σ²_v] / σ²_ζ

* Full sample
corr dlnc dlny_lab if bpp_sample == 1, cov
local cov_cy = r(cov_12)

corr dlnc dlny_lead1 if bpp_sample == 1, cov
local cov_cy_lead = r(cov_12)

local phi_full = -`cov_cy_lead' / `sigma2_v_full'
local psi_full = (`cov_cy' - `phi_full' * `sigma2_v_full') / `sigma2_zeta_full'

di as text "FULL SAMPLE:"
di as text "  Cov(Δc_t, Δy_t): " %8.5f `cov_cy'
di as text "  Cov(Δc_t, Δy_{t+1}): " %8.5f `cov_cy_lead'
di as text "  → ψ (permanent response):  " %6.4f `psi_full'
di as text "  → φ (transitory response): " %6.4f `phi_full'

* By formality
foreach group in 0 1 {
    if `group' == 0 {
        di as text _n "FORMAL WORKERS:"
    }
    else {
        di as text _n "INFORMAL WORKERS:"
    }

    corr dlnc dlny_lab if bpp_sample == 1 & informal == `group', cov
    local cov_cy_`group' = r(cov_12)

    corr dlnc dlny_lead1 if bpp_sample == 1 & informal == `group', cov
    local cov_cy_lead_`group' = r(cov_12)

    * Check for valid denominators
    if `sigma2_v_`group'' > 0.001 & `sigma2_zeta_`group'' > 0.001 {
        local phi_`group' = -`cov_cy_lead_`group'' / `sigma2_v_`group''
        local psi_`group' = (`cov_cy_`group'' - `phi_`group'' * `sigma2_v_`group'') / `sigma2_zeta_`group''
    }
    else {
        local phi_`group' = .
        local psi_`group' = .
        di as text "  (Warning: shock variance too small for identification)"
    }

    di as text "  Cov(Δc_t, Δy_t): " %8.5f `cov_cy_`group''
    di as text "  Cov(Δc_t, Δy_{t+1}): " %8.5f `cov_cy_lead_`group''
    di as text "  → ψ (permanent response):  " %6.4f `psi_`group''
    di as text "  → φ (transitory response): " %6.4f `phi_`group''
}

*===============================================================================
* 5. BOOTSTRAP STANDARD ERRORS
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Bootstrap Standard Errors"
di as text    "=============================================="

* Set seed
set seed 20260217

* Number of bootstrap iterations
local B = 500

* Store bootstrap estimates
tempname BOOT_PSI BOOT_PHI
matrix `BOOT_PSI' = J(`B', 3, .)  // full, formal, informal
matrix `BOOT_PHI' = J(`B', 3, .)

* Save data to tempfile
tempfile bpp_data
save `bpp_data', replace

forvalues b = 1/`B' {
    if mod(`b', 100) == 0 {
        di as text "  Bootstrap iteration `b'/`B'..."
    }

    preserve
        * Cluster bootstrap
        bsample, cluster(idind)

        * Full sample estimates
        quietly {
            sum dlny_lab if bpp_sample == 1
            local var_dlny_b = r(Var)
            corr dlny_lab dlny_lag1 if bpp_sample == 1, cov
            local cov_dlny_lag_b = r(cov_12)
            local sigma2_v_b = -`cov_dlny_lag_b'
            local sigma2_zeta_b = `var_dlny_b' - 2 * `sigma2_v_b'

            corr dlnc dlny_lab if bpp_sample == 1, cov
            local cov_cy_b = r(cov_12)
            corr dlnc dlny_lead1 if bpp_sample == 1, cov
            local cov_cy_lead_b = r(cov_12)

            if `sigma2_v_b' > 0.001 & `sigma2_zeta_b' > 0.001 {
                local phi_b = -`cov_cy_lead_b' / `sigma2_v_b'
                local psi_b = (`cov_cy_b' - `phi_b' * `sigma2_v_b') / `sigma2_zeta_b'
            }
            else {
                local phi_b = .
                local psi_b = .
            }
        }
        matrix `BOOT_PSI'[`b', 1] = `psi_b'
        matrix `BOOT_PHI'[`b', 1] = `phi_b'

        * By formality (if data permits)
        foreach group in 0 1 {
            local col = `group' + 2
            quietly {
                capture {
                    sum dlny_lab if bpp_sample == 1 & informal == `group'
                    local var_b = r(Var)
                    corr dlny_lab dlny_lag1 if bpp_sample == 1 & informal == `group', cov
                    local cov_lag_b = r(cov_12)
                    local s2v = -`cov_lag_b'
                    local s2z = `var_b' - 2 * `s2v'

                    corr dlnc dlny_lab if bpp_sample == 1 & informal == `group', cov
                    local ccy = r(cov_12)
                    corr dlnc dlny_lead1 if bpp_sample == 1 & informal == `group', cov
                    local ccyl = r(cov_12)

                    if `s2v' > 0.001 & `s2z' > 0.001 {
                        local phi_g = -`ccyl' / `s2v'
                        local psi_g = (`ccy' - `phi_g' * `s2v') / `s2z'
                    }
                    else {
                        local phi_g = .
                        local psi_g = .
                    }
                }
                if _rc == 0 {
                    matrix `BOOT_PSI'[`b', `col'] = `psi_g'
                    matrix `BOOT_PHI'[`b', `col'] = `phi_g'
                }
            }
        }
    restore
}

* Reload original data
use `bpp_data', clear

* Compute bootstrap SEs
preserve
    clear
    svmat `BOOT_PSI'
    rename `BOOT_PSI'1 psi_full
    rename `BOOT_PSI'2 psi_formal
    rename `BOOT_PSI'3 psi_informal

    * Drop extreme outliers (likely identification failures)
    foreach var of varlist psi_* {
        replace `var' = . if abs(`var') > 5
    }

    sum psi_full, detail
    local se_psi_full = r(sd)
    sum psi_formal, detail
    local se_psi_formal = r(sd)
    sum psi_informal, detail
    local se_psi_informal = r(sd)
restore

preserve
    clear
    svmat `BOOT_PHI'
    rename `BOOT_PHI'1 phi_full
    rename `BOOT_PHI'2 phi_formal
    rename `BOOT_PHI'3 phi_informal

    foreach var of varlist phi_* {
        replace `var' = . if abs(`var') > 5
    }

    sum phi_full, detail
    local se_phi_full = r(sd)
    sum phi_formal, detail
    local se_phi_formal = r(sd)
    sum phi_informal, detail
    local se_phi_informal = r(sd)
restore

di as text _n "Bootstrap Standard Errors (`B' replications):"
di as text "                  Full Sample    Formal    Informal"
di as text "  ψ (permanent):  " %6.4f `se_psi_full' "        " %6.4f `se_psi_formal' "     " %6.4f `se_psi_informal'
di as text "  φ (transitory): " %6.4f `se_phi_full' "        " %6.4f `se_phi_formal' "     " %6.4f `se_phi_informal'

*===============================================================================
* 6. SUMMARY TABLE
*===============================================================================

di as text _n "=============================================="
di as text    "  6. Summary: BPP Estimates"
di as text    "=============================================="

di as text _n "============================================================"
di as text   "                    Full Sample    Formal       Informal"
di as text   "============================================================"
di as text   "Shock Variances:"
di as text   "  σ²_ζ (permanent)  " %8.5f `sigma2_zeta_full' "     " %8.5f `sigma2_zeta_0' "    " %8.5f `sigma2_zeta_1'
di as text   "  σ²_v (transitory) " %8.5f `sigma2_v_full' "     " %8.5f `sigma2_v_0' "    " %8.5f `sigma2_v_1'
di as text   "------------------------------------------------------------"
di as text   "Consumption Response:"
di as text   "  ψ (permanent)     " %6.4f `psi_full' "       " %6.4f `psi_0' "      " %6.4f `psi_1'
di as text   "                   (" %5.4f `se_psi_full' ")     (" %5.4f `se_psi_formal' ")    (" %5.4f `se_psi_informal' ")"
di as text   "  φ (transitory)    " %6.4f `phi_full' "       " %6.4f `phi_0' "      " %6.4f `phi_1'
di as text   "                   (" %5.4f `se_phi_full' ")     (" %5.4f `se_phi_formal' ")    (" %5.4f `se_phi_informal' ")"
di as text   "============================================================"

* Test: ψ_formal = ψ_informal?
local diff_psi = `psi_1' - `psi_0'
local se_diff_psi = sqrt(`se_psi_formal'^2 + `se_psi_informal'^2)
local t_diff_psi = `diff_psi' / `se_diff_psi'
local p_diff_psi = 2 * (1 - normal(abs(`t_diff_psi')))

di as text _n "Test: ψ_informal = ψ_formal"
di as text "  Difference: " %6.4f `diff_psi' " (SE " %5.4f `se_diff_psi' ")"
di as text "  t = " %5.2f `t_diff_psi' ", p = " %5.3f `p_diff_psi'

* Test: φ_formal = φ_informal?
local diff_phi = `phi_1' - `phi_0'
local se_diff_phi = sqrt(`se_phi_formal'^2 + `se_phi_informal'^2)
local t_diff_phi = `diff_phi' / `se_diff_phi'
local p_diff_phi = 2 * (1 - normal(abs(`t_diff_phi')))

di as text _n "Test: φ_informal = φ_formal"
di as text "  Difference: " %6.4f `diff_phi' " (SE " %5.4f `se_diff_phi' ")"
di as text "  t = " %5.2f `t_diff_phi' ", p = " %5.3f `p_diff_phi'

*===============================================================================
* 7. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  7. Export Results"
di as text    "=============================================="

* Export to CSV
preserve
    clear
    set obs 3
    gen group = ""
    gen sigma2_zeta = .
    gen sigma2_v = .
    gen psi = .
    gen se_psi = .
    gen phi = .
    gen se_phi = .

    replace group = "Full" in 1
    replace sigma2_zeta = `sigma2_zeta_full' in 1
    replace sigma2_v = `sigma2_v_full' in 1
    replace psi = `psi_full' in 1
    replace se_psi = `se_psi_full' in 1
    replace phi = `phi_full' in 1
    replace se_phi = `se_phi_full' in 1

    replace group = "Formal" in 2
    replace sigma2_zeta = `sigma2_zeta_0' in 2
    replace sigma2_v = `sigma2_v_0' in 2
    replace psi = `psi_0' in 2
    replace se_psi = `se_psi_formal' in 2
    replace phi = `phi_0' in 2
    replace se_phi = `se_phi_formal' in 2

    replace group = "Informal" in 3
    replace sigma2_zeta = `sigma2_zeta_1' in 3
    replace sigma2_v = `sigma2_v_1' in 3
    replace psi = `psi_1' in 3
    replace se_psi = `se_psi_informal' in 3
    replace phi = `phi_1' in 3
    replace se_phi = `se_phi_informal' in 3

    export delimited using "${tables}/R6_bpp_decomposition.csv", replace
restore

* LaTeX table
file open texfile using "${tables}/R6_bpp_decomposition.tex", write replace
file write texfile "\begin{table}[htbp]" _n
file write texfile "\centering" _n
file write texfile "\caption{BPP Decomposition: Permanent vs Transitory Shocks}" _n
file write texfile "\begin{tabular}{lccc}" _n
file write texfile "\toprule" _n
file write texfile " & Full Sample & Formal & Informal \\" _n
file write texfile "\midrule" _n
file write texfile "\multicolumn{4}{l}{\textit{Shock Variances:}} \\" _n
file write texfile "$\sigma^2_\zeta$ (permanent) & " %8.5f (`sigma2_zeta_full') " & " %8.5f (`sigma2_zeta_0') " & " %8.5f (`sigma2_zeta_1') " \\" _n
file write texfile "$\sigma^2_v$ (transitory) & " %8.5f (`sigma2_v_full') " & " %8.5f (`sigma2_v_0') " & " %8.5f (`sigma2_v_1') " \\" _n
file write texfile "\midrule" _n
file write texfile "\multicolumn{4}{l}{\textit{Consumption Response:}} \\" _n
file write texfile "$\psi$ (permanent) & " %6.4f (`psi_full') " & " %6.4f (`psi_0') " & " %6.4f (`psi_1') " \\" _n
file write texfile " & (" %5.4f (`se_psi_full') ") & (" %5.4f (`se_psi_formal') ") & (" %5.4f (`se_psi_informal') ") \\" _n
file write texfile "$\phi$ (transitory) & " %6.4f (`phi_full') " & " %6.4f (`phi_0') " & " %6.4f (`phi_1') " \\" _n
file write texfile " & (" %5.4f (`se_phi_full') ") & (" %5.4f (`se_phi_formal') ") & (" %5.4f (`se_phi_informal') ") \\" _n
file write texfile "\bottomrule" _n
file write texfile "\end{tabular}" _n
file write texfile "\label{tab:bpp}" _n
file write texfile "\end{table}" _n
file close texfile

*===============================================================================
* 8. SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  R6 SUMMARY: BPP Decomposition"
di as text    "=============================================="

di as text _n "METHODOLOGY:"
di as text "  - Decompose income into permanent (random walk) + transitory"
di as text "  - Use covariance structure to identify shock variances"
di as text "  - Estimate consumption response ψ (permanent) and φ (transitory)"

di as text _n "KEY FINDINGS:"
di as text "  Formal workers:"
di as text "    ψ = " %6.4f `psi_0' " (response to permanent shocks)"
di as text "    φ = " %6.4f `phi_0' " (response to transitory shocks)"
di as text "  Informal workers:"
di as text "    ψ = " %6.4f `psi_1' " (response to permanent shocks)"
di as text "    φ = " %6.4f `phi_1' " (response to transitory shocks)"

di as text _n "INTERPRETATION:"
if `psi_1' > `psi_0' {
    di as text "  ψ_informal > ψ_formal: Informal workers are MORE exposed to"
    di as text "  permanent income shocks (less insurance against career risk)"
}
if `phi_1' > `phi_0' {
    di as text "  φ_informal > φ_formal: Informal workers smooth transitory"
    di as text "  shocks LESS well (credit constraint / precautionary saving gap)"
}

log close

di as text _n "Log saved to: ${logdir}/R6_bpp_decomposition.log"
di as text "Tables saved to: ${tables}/R6_bpp_decomposition.tex"
di as text "                 ${tables}/R6_bpp_decomposition.csv"

*===============================================================================
* END
*===============================================================================
