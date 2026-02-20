*===============================================================================
* R11: Formal-Sector Lambda Recovery with Insurance Controls
*===============================================================================
*
* Core Test: The model claims formal workers have the same λ (loss aversion)
* but institutions mask it. Test this by finding "exposed" formal workers
* who lack insurance channels:
*   - Temporary/fixed-term contracts (no severance)
*   - Workers in firms with wage arrears (effective UI failure)
*   - Probationary periods
*
* Prediction: If model is correct, exposed formal workers should show δ⁻ > 0
* similar to informal workers. If δ⁻ ≈ 0, asymmetry is about worker types.
*
* Author: Generated for JEEA revision
* Date: February 2026
*===============================================================================

clear all
set more off
capture log close

* Set globals
global base "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/_Research/Credit_Market/Credit market (1)"
global welfare "${base}/Welfare analysis"
global data "${welfare}/Data"
global tables "${welfare}/Tables"
global figures "${welfare}/Figures"
global logdir "${welfare}/Logs"

log using "${logdir}/R11_exposed_formal_workers.log", replace text

di as text _n "=============================================="
di as text    "  R11: Exposed Formal Workers Test"
di as text    "=============================================="

*===============================================================================
* 0. LOAD DATA AND IDENTIFY RLMS VARIABLES
*===============================================================================

* Load main analysis data
capture use "$data/welfare_panel_cbr.dta", clear
if _rc != 0 {
    use "$data/welfare_panel_shocks.dta", clear
}

keep if analysis_sample == 1
xtset idind year

* Check what contract/arrears variables exist
di as text _n "--- Checking available insurance-related variables ---"

* RLMS variables for contract type (typically J6, J6.1, J6.2 in questionnaire)
* Common variable names: contract, contract_type, pj6, etc.
local contract_vars "contract contract_type pj6 j6 j6_1 j6_2 work_contract"
foreach var of local contract_vars {
    capture confirm variable `var'
    if _rc == 0 {
        di as text "Found: `var'"
        tab `var', missing
    }
}

* RLMS variables for wage arrears (J44 series)
local arrears_vars "wage_arrears arrears pj44 j44 j44_1 owed_wages unpaid_wages"
foreach var of local arrears_vars {
    capture confirm variable `var'
    if _rc == 0 {
        di as text "Found: `var'"
        tab `var', missing
    }
}

* Probation period (less common in RLMS)
local prob_vars "probation probationary prob_period trial_period"
foreach var of local prob_vars {
    capture confirm variable `var'
    if _rc == 0 {
        di as text "Found: `var'"
        tab `var', missing
    }
}

*===============================================================================
* 1. CONSTRUCT "EXPOSED" FORMAL WORKER INDICATORS
*===============================================================================

di as text _n "=============================================="
di as text    "  1. Construct Exposed Formal Worker Indicators"
di as text    "=============================================="

* Initialize indicators
gen byte exposed_temp = 0
gen byte exposed_arrears = 0
gen byte exposed_any = 0

label variable exposed_temp "Temporary/fixed-term contract"
label variable exposed_arrears "Firm has wage arrears"
label variable exposed_any "Any insurance exposure"

* --- Temporary contracts ---
* RLMS J6 typically: 1=permanent, 2=fixed-term, 3=oral agreement, etc.
capture confirm variable contract_type
if _rc == 0 {
    replace exposed_temp = 1 if inlist(contract_type, 2, 3, 4) & informal == 0
}
else {
    * Try alternative variable names
    capture confirm variable pj6
    if _rc == 0 {
        replace exposed_temp = 1 if inlist(pj6, 2, 3, 4) & informal == 0
    }
    else {
        * Create from job tenure if available
        capture confirm variable job_tenure
        if _rc == 0 {
            * Short tenure proxy: < 12 months = likely temporary/probation
            replace exposed_temp = 1 if job_tenure < 12 & informal == 0
            label variable exposed_temp "Short tenure (<12 months)"
        }
    }
}

* --- Wage arrears ---
* RLMS J44: "Have you been paid all wages owed?"
capture confirm variable wage_arrears
if _rc == 0 {
    replace exposed_arrears = 1 if wage_arrears == 1 & informal == 0
}
else {
    capture confirm variable pj44
    if _rc == 0 {
        replace exposed_arrears = 1 if pj44 == 1 & informal == 0
    }
    else {
        * Alternative: use income decline as proxy for arrears
        capture confirm variable dlny_neg
        if _rc == 0 {
            * Severe negative shock in formal sector suggests payment issues
            gen temp_severe = (dlny_neg < -0.30) if informal == 0
            label variable temp_severe "Severe income drop (>30%)"
        }
    }
}

* --- Combined exposure ---
replace exposed_any = (exposed_temp == 1 | exposed_arrears == 1)

* Summary
tab informal exposed_any, missing
tab informal exposed_temp if informal == 0, missing
tab informal exposed_arrears if informal == 0, missing

* Count observations
count if informal == 0 & exposed_any == 0
local N_protected = r(N)
count if informal == 0 & exposed_any == 1
local N_exposed = r(N)
count if informal == 1
local N_informal = r(N)

di as text _n "Sample sizes:"
di as text "  Protected formal workers: `N_protected'"
di as text "  Exposed formal workers:   `N_exposed'"
di as text "  Informal workers:         `N_informal'"

*===============================================================================
* 2. ASYMMETRIC SPECIFICATION BY WORKER TYPE
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Asymmetric Smoothing by Exposure Status"
di as text    "=============================================="

* Ensure asymmetric shock variables exist
capture confirm variable dlny_pos
if _rc != 0 {
    gen dlny_pos = max(dlny_lab, 0)
    gen dlny_neg = min(dlny_lab, 0)
}

* Create interaction terms
gen dlny_pos_x_exp = dlny_pos * exposed_any
gen dlny_neg_x_exp = dlny_neg * exposed_any
gen dlny_pos_x_inf = dlny_pos * informal
gen dlny_neg_x_inf = dlny_neg * informal

label variable dlny_pos_x_exp "Δln(Y)⁺ × Exposed formal"
label variable dlny_neg_x_exp "Δln(Y)⁻ × Exposed formal"
label variable dlny_pos_x_inf "Δln(Y)⁺ × Informal"
label variable dlny_neg_x_inf "Δln(Y)⁻ × Informal"

* Controls
global X_controls "age age2 i.female i.married hh_size n_children i.urban i.year"

eststo clear

* --- (A) Baseline: Protected formal vs Informal ---
di as text _n "--- Baseline: Protected Formal vs Informal ---"

eststo base: reghdfe dlnc dlny_pos dlny_neg ///
    dlny_pos_x_inf dlny_neg_x_inf ///
    if (informal == 0 & exposed_any == 0) | informal == 1, ///
    absorb(idind) vce(cluster idind)

* Wald test for asymmetry among informal
test dlny_pos_x_inf = dlny_neg_x_inf
local p_asym_inf = r(p)

di as text "Informal asymmetry test (δ⁺ = δ⁻): p = " %5.3f `p_asym_inf'

* --- (B) Three-way comparison ---
di as text _n "--- Three-way: Protected formal vs Exposed formal vs Informal ---"

* Create categorical variable
gen worker_type = 0 if informal == 0 & exposed_any == 0  // Protected formal (reference)
replace worker_type = 1 if informal == 0 & exposed_any == 1  // Exposed formal
replace worker_type = 2 if informal == 1  // Informal

label define worker_type_lbl 0 "Protected formal" 1 "Exposed formal" 2 "Informal"
label values worker_type worker_type_lbl

* Full interaction model
eststo threeway: reghdfe dlnc c.dlny_pos##i.worker_type c.dlny_neg##i.worker_type ///
    $X_controls, absorb(idind) vce(cluster idind)

* Extract key coefficients
* δ⁺ and δ⁻ for exposed formal (worker_type = 1)
local delta_pos_exp = _b[1.worker_type#c.dlny_pos]
local delta_neg_exp = _b[1.worker_type#c.dlny_neg]
local se_pos_exp = _se[1.worker_type#c.dlny_pos]
local se_neg_exp = _se[1.worker_type#c.dlny_neg]

* δ⁺ and δ⁻ for informal (worker_type = 2)
local delta_pos_inf = _b[2.worker_type#c.dlny_pos]
local delta_neg_inf = _b[2.worker_type#c.dlny_neg]
local se_pos_inf = _se[2.worker_type#c.dlny_pos]
local se_neg_inf = _se[2.worker_type#c.dlny_neg]

di as text _n "Key estimates (relative to protected formal):"
di as text "                     δ⁺            δ⁻"
di as text "  Exposed formal:  " %7.4f `delta_pos_exp' " (" %5.4f `se_pos_exp' ")  " ///
    %7.4f `delta_neg_exp' " (" %5.4f `se_neg_exp' ")"
di as text "  Informal:        " %7.4f `delta_pos_inf' " (" %5.4f `se_pos_inf' ")  " ///
    %7.4f `delta_neg_inf' " (" %5.4f `se_neg_inf' ")"

* --- Key test: Is exposed formal δ⁻ closer to informal or protected? ---
test 1.worker_type#c.dlny_neg = 0
local p_exp_vs_protected = r(p)

test 1.worker_type#c.dlny_neg = 2.worker_type#c.dlny_neg
local p_exp_vs_informal = r(p)

di as text _n "Hypothesis tests:"
di as text "  H0: Exposed formal δ⁻ = Protected formal δ⁻: p = " %5.3f `p_exp_vs_protected'
di as text "  H0: Exposed formal δ⁻ = Informal δ⁻:         p = " %5.3f `p_exp_vs_informal'

*===============================================================================
* 3. SEPARATE REGRESSIONS BY GROUP
*===============================================================================

di as text _n "=============================================="
di as text    "  3. Separate Regressions by Worker Type"
di as text    "=============================================="

* Protected formal only
di as text _n "--- Protected Formal Workers ---"
eststo prot: reghdfe dlnc dlny_pos dlny_neg $X_controls ///
    if informal == 0 & exposed_any == 0, ///
    absorb(idind) vce(cluster idind)

local beta_pos_prot = _b[dlny_pos]
local beta_neg_prot = _b[dlny_neg]
local se_pos_prot = _se[dlny_pos]
local se_neg_prot = _se[dlny_neg]

test dlny_pos = dlny_neg
local p_asym_prot = r(p)

di as text "  β⁺ = " %6.4f `beta_pos_prot' " (SE " %5.4f `se_pos_prot' ")"
di as text "  β⁻ = " %6.4f `beta_neg_prot' " (SE " %5.4f `se_neg_prot' ")"
di as text "  Asymmetry test p = " %5.3f `p_asym_prot'

* Exposed formal only
di as text _n "--- Exposed Formal Workers ---"
eststo exp: reghdfe dlnc dlny_pos dlny_neg $X_controls ///
    if informal == 0 & exposed_any == 1, ///
    absorb(idind) vce(cluster idind)

local beta_pos_exp = _b[dlny_pos]
local beta_neg_exp = _b[dlny_neg]
local se_pos_exp = _se[dlny_pos]
local se_neg_exp = _se[dlny_neg]

test dlny_pos = dlny_neg
local p_asym_exp = r(p)

di as text "  β⁺ = " %6.4f `beta_pos_exp' " (SE " %5.4f `se_pos_exp' ")"
di as text "  β⁻ = " %6.4f `beta_neg_exp' " (SE " %5.4f `se_neg_exp' ")"
di as text "  Asymmetry test p = " %5.3f `p_asym_exp'

* Informal only
di as text _n "--- Informal Workers ---"
eststo inf: reghdfe dlnc dlny_pos dlny_neg $X_controls ///
    if informal == 1, ///
    absorb(idind) vce(cluster idind)

local beta_pos_inf = _b[dlny_pos]
local beta_neg_inf = _b[dlny_neg]
local se_pos_inf = _se[dlny_pos]
local se_neg_inf = _se[dlny_neg]

test dlny_pos = dlny_neg
local p_asym_inf = r(p)

di as text "  β⁺ = " %6.4f `beta_pos_inf' " (SE " %5.4f `se_pos_inf' ")"
di as text "  β⁻ = " %6.4f `beta_neg_inf' " (SE " %5.4f `se_neg_inf' ")"
di as text "  Asymmetry test p = " %5.3f `p_asym_inf'

*===============================================================================
* 4. MODEL VALIDATION SUMMARY
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Model Validation Summary"
di as text    "=============================================="

di as text _n "MODEL PREDICTION:"
di as text "  If institutional coverage masks loss aversion:"
di as text "    - Protected formal: δ⁻ ≈ 0 (institutions smooth shocks)"
di as text "    - Exposed formal:   δ⁻ > 0 (like informal)"
di as text "    - Informal:         δ⁻ > 0 (no institutions)"
di as text ""
di as text "  If asymmetry is about worker types (not institutions):"
di as text "    - Protected formal: δ⁻ ≈ 0"
di as text "    - Exposed formal:   δ⁻ ≈ 0 (same type as protected)"
di as text "    - Informal:         δ⁻ > 0 (different type)"

di as text _n "EMPIRICAL RESULTS:"
di as text "                        β⁺         β⁻       Asymmetry p"
di as text "  Protected formal:  " %6.4f `beta_pos_prot' "     " %6.4f `beta_neg_prot' "        " %5.3f `p_asym_prot'
di as text "  Exposed formal:    " %6.4f `beta_pos_exp' "     " %6.4f `beta_neg_exp' "        " %5.3f `p_asym_exp'
di as text "  Informal:          " %6.4f `beta_pos_inf' "     " %6.4f `beta_neg_inf' "        " %5.3f `p_asym_inf'

* Determine verdict
local verdict "INCONCLUSIVE"
if `p_asym_exp' < 0.10 & `p_exp_vs_informal' > 0.10 {
    local verdict "SUPPORTS MODEL: Exposed formal shows asymmetry like informal"
}
else if `p_asym_exp' > 0.10 & `p_exp_vs_protected' > 0.10 {
    local verdict "REJECTS MODEL: Exposed formal shows no asymmetry (type hypothesis)"
}

di as text _n "VERDICT: `verdict'"

*===============================================================================
* 5. ROBUSTNESS: ALTERNATIVE EXPOSURE DEFINITIONS
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Robustness: Alternative Exposure Definitions"
di as text    "=============================================="

* (A) Temporary contract only
di as text _n "--- (A) Temporary contracts only ---"
capture {
    reghdfe dlnc dlny_pos dlny_neg $X_controls ///
        if informal == 0 & exposed_temp == 1, ///
        absorb(idind) vce(cluster idind)

    test dlny_pos = dlny_neg
    di as text "  Asymmetry test p = " %5.3f r(p)
}

* (B) Wage arrears only
di as text _n "--- (B) Wage arrears only ---"
capture {
    reghdfe dlnc dlny_pos dlny_neg $X_controls ///
        if informal == 0 & exposed_arrears == 1, ///
        absorb(idind) vce(cluster idind)

    test dlny_pos = dlny_neg
    di as text "  Asymmetry test p = " %5.3f r(p)
}

* (C) Small firm workers (less likely to have UI)
di as text _n "--- (C) Small firm workers (<10 employees) ---"
capture confirm variable firm_size
if _rc == 0 {
    gen byte small_firm = (firm_size < 10)

    reghdfe dlnc dlny_pos dlny_neg $X_controls ///
        if informal == 0 & small_firm == 1, ///
        absorb(idind) vce(cluster idind)

    test dlny_pos = dlny_neg
    di as text "  Asymmetry test p = " %5.3f r(p)
}

*===============================================================================
* 6. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  6. Export Results"
di as text    "=============================================="

* Regression table
esttab prot exp inf using "${tables}/R11_exposed_formal.tex", replace ///
    keep(dlny_pos dlny_neg) ///
    mtitles("Protected Formal" "Exposed Formal" "Informal") ///
    coeflabels(dlny_pos "$\beta^+$" dlny_neg "$\beta^-$") ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    title("Asymmetric Consumption Smoothing by Worker Type") ///
    label booktabs ///
    addnotes("Individual FE and year FE included." ///
             "Standard errors clustered at individual level.")

* Summary CSV
preserve
    clear
    set obs 3
    gen worker_type = ""
    gen beta_pos = .
    gen se_pos = .
    gen beta_neg = .
    gen se_neg = .
    gen p_asymmetry = .
    gen N = .

    replace worker_type = "Protected formal" in 1
    replace beta_pos = `beta_pos_prot' in 1
    replace se_pos = `se_pos_prot' in 1
    replace beta_neg = `beta_neg_prot' in 1
    replace se_neg = `se_neg_prot' in 1
    replace p_asymmetry = `p_asym_prot' in 1
    replace N = `N_protected' in 1

    replace worker_type = "Exposed formal" in 2
    replace beta_pos = `beta_pos_exp' in 2
    replace se_pos = `se_pos_exp' in 2
    replace beta_neg = `beta_neg_exp' in 2
    replace se_neg = `se_neg_exp' in 2
    replace p_asymmetry = `p_asym_exp' in 2
    replace N = `N_exposed' in 2

    replace worker_type = "Informal" in 3
    replace beta_pos = `beta_pos_inf' in 3
    replace se_pos = `se_pos_inf' in 3
    replace beta_neg = `beta_neg_inf' in 3
    replace se_neg = `se_neg_inf' in 3
    replace p_asymmetry = `p_asym_inf' in 3
    replace N = `N_informal' in 3

    export delimited using "${tables}/R11_exposed_formal_summary.csv", replace
restore

*===============================================================================

log close

di as text _n "Log saved to: ${logdir}/R11_exposed_formal_workers.log"
di as text "Tables saved to: ${tables}/R11_exposed_formal.tex"
di as text "                 ${tables}/R11_exposed_formal_summary.csv"

*===============================================================================
* END
*===============================================================================
