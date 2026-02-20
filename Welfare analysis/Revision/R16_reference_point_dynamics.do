*===============================================================================
* R16: Reference Point Dynamics Using Transition Workers
*===============================================================================
*
* Test: Do reference points adapt slowly or quickly after formality transitions?
*
* Kőszegi-Rabin Model:
*   - If r = c_{t-1} (lagged consumption is reference)
*   - Reference points may adapt slowly after life changes
*
* Prediction:
*   - If reference points adapt SLOWLY:
*     Recently transitioned formal→informal workers show stronger loss aversion
*     than long-term informal workers (reference still calibrated to formal consumption)
*     δ⁻(k=0) > δ⁻(k=3+) where k = years since becoming informal
*
*   - If reference points adapt QUICKLY:
*     Penalty is immediate and stable after transition
*     δ⁻(k=0) ≈ δ⁻(k=3+)
*
* Estimation:
*   δ⁻(k) for k = 0, 1, 2, 3+ years since becoming informal
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

log using "${logdir}/R16_reference_point_dynamics.log", replace text

di as text _n "=============================================="
di as text    "  R16: Reference Point Dynamics"
di as text    "=============================================="

*===============================================================================
* 0. DATA SETUP
*===============================================================================

* Load data
capture use "$data/welfare_panel_cbr.dta", clear
if _rc != 0 {
    use "$data/welfare_panel_shocks.dta", clear
}

keep if analysis_sample == 1
xtset idind year

*===============================================================================
* 1. IDENTIFY TRANSITION WORKERS
*===============================================================================

di as text _n "=============================================="
di as text    "  1. Identify Formality Transitions"
di as text    "=============================================="

* Lagged informal status
sort idind year
by idind: gen L_informal = informal[_n-1]

* Identify transitions
gen byte trans_f2i = (informal == 1 & L_informal == 0)  // Formal to informal
gen byte trans_i2f = (informal == 0 & L_informal == 1)  // Informal to formal

label variable trans_f2i "Transition: Formal → Informal"
label variable trans_i2f "Transition: Informal → Formal"

* Year of first transition to informal
by idind (year): gen first_f2i_year = year if trans_f2i == 1
by idind: egen min_f2i_year = min(first_f2i_year)

* Time since transition to informal
gen time_since_f2i = year - min_f2i_year if !missing(min_f2i_year) & informal == 1
label variable time_since_f2i "Years since formal→informal transition"

* Categorize time since transition
gen byte tenure_informal = .
replace tenure_informal = 0 if time_since_f2i == 0  // Just transitioned
replace tenure_informal = 1 if time_since_f2i == 1
replace tenure_informal = 2 if time_since_f2i == 2
replace tenure_informal = 3 if time_since_f2i >= 3 & !missing(time_since_f2i)

label define tenure_lbl 0 "k=0 (just transitioned)" 1 "k=1" 2 "k=2" 3 "k=3+"
label values tenure_informal tenure_lbl

* Also identify always-informal workers
by idind: egen ever_formal = max(L_informal == 0)
gen byte always_informal = (ever_formal == 0)
label variable always_informal "Never observed as formal"

* Summary
tab tenure_informal, missing
tab always_informal if informal == 1, missing

count if tenure_informal == 0
local N_k0 = r(N)
count if tenure_informal == 1
local N_k1 = r(N)
count if tenure_informal == 2
local N_k2 = r(N)
count if tenure_informal == 3
local N_k3 = r(N)
count if always_informal == 1 & informal == 1
local N_always = r(N)

di as text _n "Sample composition (informal workers):"
di as text "  k=0 (just transitioned):  `N_k0'"
di as text "  k=1:                       `N_k1'"
di as text "  k=2:                       `N_k2'"
di as text "  k=3+:                      `N_k3'"
di as text "  Always informal:           `N_always'"

*===============================================================================
* 2. ASYMMETRIC SHOCKS
*===============================================================================

di as text _n "=============================================="
di as text    "  2. Prepare Asymmetric Shock Variables"
di as text    "=============================================="

* Ensure asymmetric shock variables exist
capture confirm variable dlny_pos
if _rc != 0 {
    gen dlny_pos = max(dlny_lab, 0)
    gen dlny_neg = min(dlny_lab, 0)
}

* Create interactions by tenure
gen dlny_neg_k0 = dlny_neg * (tenure_informal == 0)
gen dlny_neg_k1 = dlny_neg * (tenure_informal == 1)
gen dlny_neg_k2 = dlny_neg * (tenure_informal == 2)
gen dlny_neg_k3 = dlny_neg * (tenure_informal == 3)
gen dlny_neg_always = dlny_neg * (always_informal == 1 & informal == 1)

gen dlny_pos_k0 = dlny_pos * (tenure_informal == 0)
gen dlny_pos_k1 = dlny_pos * (tenure_informal == 1)
gen dlny_pos_k2 = dlny_pos * (tenure_informal == 2)
gen dlny_pos_k3 = dlny_pos * (tenure_informal == 3)
gen dlny_pos_always = dlny_pos * (always_informal == 1 & informal == 1)

* Controls
global X_controls "age age2 i.female i.married hh_size n_children i.urban i.year"

*===============================================================================
* 3. ESTIMATE δ⁻(k) BY TIME SINCE TRANSITION
*===============================================================================

di as text _n "=============================================="
di as text    "  3. Estimate δ⁻(k) by Transition Tenure"
di as text    "=============================================="

eststo clear

* --- Reference: Formal workers ---
di as text _n "--- Reference: Formal workers ---"
reghdfe dlnc dlny_pos dlny_neg $X_controls if informal == 0, ///
    absorb(idind) vce(cluster idind)

local beta_pos_F = _b[dlny_pos]
local beta_neg_F = _b[dlny_neg]
local se_pos_F = _se[dlny_pos]
local se_neg_F = _se[dlny_neg]

test dlny_pos = dlny_neg
local p_asym_F = r(p)

di as text "  β⁺ = " %6.4f `beta_pos_F' " (SE " %5.4f `se_pos_F' ")"
di as text "  β⁻ = " %6.4f `beta_neg_F' " (SE " %5.4f `se_neg_F' ")"
di as text "  Asymmetry p = " %5.3f `p_asym_F'

* --- Estimate by tenure category ---
di as text _n "--- Informal workers by tenure ---"

* Pooled model with tenure interactions
reghdfe dlnc dlny_pos dlny_neg ///
    dlny_pos_k0 dlny_neg_k0 ///
    dlny_pos_k1 dlny_neg_k1 ///
    dlny_pos_k2 dlny_neg_k2 ///
    dlny_pos_k3 dlny_neg_k3 ///
    i.tenure_informal ///
    if informal == 1 & !missing(tenure_informal), ///
    absorb(idind) vce(cluster idind)

est store tenure_model

* Extract coefficients (relative to formal - add base rates)
local beta_neg_k0 = `beta_neg_F' + _b[dlny_neg_k0]
local beta_neg_k1 = `beta_neg_F' + _b[dlny_neg_k1]
local beta_neg_k2 = `beta_neg_F' + _b[dlny_neg_k2]
local beta_neg_k3 = `beta_neg_F' + _b[dlny_neg_k3]

local se_neg_k0 = _se[dlny_neg_k0]
local se_neg_k1 = _se[dlny_neg_k1]
local se_neg_k2 = _se[dlny_neg_k2]
local se_neg_k3 = _se[dlny_neg_k3]

* Also get the base β⁻ for informal from this regression
local base_neg = _b[dlny_neg]
local base_pos = _b[dlny_pos]

di as text _n "δ⁻(k) estimates (interactions with base):"
di as text "  Base β⁻ (informal):  " %6.4f `base_neg'
di as text "  k=0 increment:       " %6.4f _b[dlny_neg_k0] " (SE " %5.4f `se_neg_k0' ")"
di as text "  k=1 increment:       " %6.4f _b[dlny_neg_k1] " (SE " %5.4f `se_neg_k1' ")"
di as text "  k=2 increment:       " %6.4f _b[dlny_neg_k2] " (SE " %5.4f `se_neg_k2' ")"
di as text "  k=3+ increment:      " %6.4f _b[dlny_neg_k3] " (SE " %5.4f `se_neg_k3' ")"

* --- Separate regressions by tenure for clarity ---
di as text _n "--- Separate regressions by tenure ---"

local k_list "0 1 2 3"
foreach k of local k_list {
    if `k' < 3 {
        reghdfe dlnc dlny_pos dlny_neg $X_controls ///
            if informal == 1 & tenure_informal == `k', ///
            absorb(idind) vce(cluster idind)
    }
    else {
        reghdfe dlnc dlny_pos dlny_neg $X_controls ///
            if informal == 1 & tenure_informal >= 3 & !missing(tenure_informal), ///
            absorb(idind) vce(cluster idind)
    }

    local beta_neg_sep_k`k' = _b[dlny_neg]
    local beta_pos_sep_k`k' = _b[dlny_pos]
    local se_neg_sep_k`k' = _se[dlny_neg]
    local se_pos_sep_k`k' = _se[dlny_pos]

    test dlny_pos = dlny_neg
    local p_asym_k`k' = r(p)

    if `k' < 3 {
        di as text "  k=`k': β⁻ = " %6.4f `beta_neg_sep_k`k'' " (SE " %5.4f `se_neg_sep_k`k'' "), asymmetry p = " %5.3f `p_asym_k`k''
    }
    else {
        di as text "  k=3+: β⁻ = " %6.4f `beta_neg_sep_k`k'' " (SE " %5.4f `se_neg_sep_k`k'' "), asymmetry p = " %5.3f `p_asym_k`k''
    }
}

* --- Always informal ---
di as text _n "--- Always informal (never observed formal) ---"
reghdfe dlnc dlny_pos dlny_neg $X_controls ///
    if always_informal == 1 & informal == 1, ///
    absorb(idind) vce(cluster idind)

local beta_neg_always = _b[dlny_neg]
local se_neg_always = _se[dlny_neg]
test dlny_pos = dlny_neg
local p_asym_always = r(p)

di as text "  β⁻ = " %6.4f `beta_neg_always' " (SE " %5.4f `se_neg_always' "), asymmetry p = " %5.3f `p_asym_always'

*===============================================================================
* 4. TEST FOR DECLINING PROFILE
*===============================================================================

di as text _n "=============================================="
di as text    "  4. Test for Reference Point Adaptation"
di as text    "=============================================="

di as text _n "MODEL PREDICTION:"
di as text "  SLOW adaptation: δ⁻(k=0) > δ⁻(k=3+)"
di as text "    Reference point still calibrated to formal consumption"
di as text ""
di as text "  FAST adaptation: δ⁻(k=0) ≈ δ⁻(k=3+)"
di as text "    Penalty emerges immediately and is stable"

* Test k=0 vs k=3+
est restore tenure_model
test dlny_neg_k0 = dlny_neg_k3
local p_k0_vs_k3 = r(p)

* Test for linear trend
* If slow adaptation: coefficient should decline with k
test (dlny_neg_k0 - dlny_neg_k1) = (dlny_neg_k1 - dlny_neg_k2)
local p_linear_trend = r(p)

di as text _n "EMPIRICAL RESULTS:"
di as text "  δ⁻(k=0): " %6.4f `beta_neg_sep_k0'
di as text "  δ⁻(k=1): " %6.4f `beta_neg_sep_k1'
di as text "  δ⁻(k=2): " %6.4f `beta_neg_sep_k2'
di as text "  δ⁻(k=3+): " %6.4f `beta_neg_sep_k3'

di as text _n "TESTS:"
di as text "  H₀: δ⁻(k=0) = δ⁻(k=3+):     p = " %5.3f `p_k0_vs_k3'

* Determine verdict
local verdict = "INCONCLUSIVE"
if `beta_neg_sep_k0' > `beta_neg_sep_k3' + 0.02 & `p_k0_vs_k3' < 0.10 {
    local verdict = "SLOW ADAPTATION: Recent transitions show stronger asymmetry"
}
else if abs(`beta_neg_sep_k0' - `beta_neg_sep_k3') < 0.02 {
    local verdict = "FAST ADAPTATION: Penalty is immediate and stable"
}

di as text _n "VERDICT: `verdict'"

*===============================================================================
* 5. VISUALIZATION
*===============================================================================

di as text _n "=============================================="
di as text    "  5. Create Coefficient Plot"
di as text    "=============================================="

* Create dataset for plotting
preserve
    clear
    set obs 6
    gen tenure = .
    gen beta_neg = .
    gen se = .
    gen ci_lo = .
    gen ci_hi = .
    gen label = ""

    replace tenure = -1 in 1
    replace beta_neg = `beta_neg_F' in 1
    replace se = `se_neg_F' in 1
    replace label = "Formal" in 1

    replace tenure = 0 in 2
    replace beta_neg = `beta_neg_sep_k0' in 2
    replace se = `se_neg_sep_k0' in 2
    replace label = "k=0" in 2

    replace tenure = 1 in 3
    replace beta_neg = `beta_neg_sep_k1' in 3
    replace se = `se_neg_sep_k1' in 3
    replace label = "k=1" in 3

    replace tenure = 2 in 4
    replace beta_neg = `beta_neg_sep_k2' in 4
    replace se = `se_neg_sep_k2' in 4
    replace label = "k=2" in 4

    replace tenure = 3 in 5
    replace beta_neg = `beta_neg_sep_k3' in 5
    replace se = `se_neg_sep_k3' in 5
    replace label = "k=3+" in 5

    replace tenure = 4 in 6
    replace beta_neg = `beta_neg_always' in 6
    replace se = `se_neg_always' in 6
    replace label = "Always" in 6

    replace ci_lo = beta_neg - 1.96 * se
    replace ci_hi = beta_neg + 1.96 * se

    * Plot
    twoway (bar beta_neg tenure if tenure == -1, color(navy) barwidth(0.8)) ///
           (bar beta_neg tenure if tenure >= 0, color(maroon) barwidth(0.8)) ///
           (rcap ci_lo ci_hi tenure, color(black)), ///
        xlabel(-1 "Formal" 0 "k=0" 1 "k=1" 2 "k=2" 3 "k=3+" 4 "Always", noticks) ///
        xtitle("Years Since Becoming Informal") ///
        ytitle("β⁻ (Response to Negative Shocks)") ///
        title("Reference Point Dynamics") ///
        subtitle("Does asymmetry decline with tenure in informal sector?") ///
        legend(off) ///
        yline(0, lcolor(black) lpattern(dash)) ///
        note("Formal = reference. k=0 = just transitioned. Always = never formal.")

    graph export "${figures}/R16_reference_dynamics.png", replace width(1200)
    graph save "${figures}/R16_reference_dynamics.gph", replace
restore

*===============================================================================
* 6. ROBUSTNESS: SYMMETRIC TEST
*===============================================================================

di as text _n "=============================================="
di as text    "  6. Robustness: Also Check β⁺ Dynamics"
di as text    "=============================================="

di as text "If reference points adapt, we might also see β⁺ changes:"
di as text "  β⁺(k=0): " %6.4f `beta_pos_sep_k0'
di as text "  β⁺(k=1): " %6.4f `beta_pos_sep_k1'
di as text "  β⁺(k=2): " %6.4f `beta_pos_sep_k2'
di as text "  β⁺(k=3+): " %6.4f `beta_pos_sep_k3'

* The key is whether the ASYMMETRY changes, not just levels
local asym_k0 = `beta_neg_sep_k0' - `beta_pos_sep_k0'
local asym_k1 = `beta_neg_sep_k1' - `beta_pos_sep_k1'
local asym_k2 = `beta_neg_sep_k2' - `beta_pos_sep_k2'
local asym_k3 = `beta_neg_sep_k3' - `beta_pos_sep_k3'

di as text _n "Asymmetry (β⁻ - β⁺) by tenure:"
di as text "  k=0: " %6.4f `asym_k0'
di as text "  k=1: " %6.4f `asym_k1'
di as text "  k=2: " %6.4f `asym_k2'
di as text "  k=3+: " %6.4f `asym_k3'

*===============================================================================
* 7. EXPORT RESULTS
*===============================================================================

di as text _n "=============================================="
di as text    "  7. Export Results"
di as text    "=============================================="

* Summary table
preserve
    clear
    set obs 6
    gen tenure = ""
    gen beta_neg = .
    gen se_neg = .
    gen beta_pos = .
    gen se_pos = .
    gen p_asymmetry = .
    gen N = .

    replace tenure = "Formal" in 1
    replace beta_neg = `beta_neg_F' in 1
    replace se_neg = `se_neg_F' in 1
    replace beta_pos = `beta_pos_F' in 1
    replace se_pos = `se_pos_F' in 1
    replace p_asymmetry = `p_asym_F' in 1

    replace tenure = "k=0" in 2
    replace beta_neg = `beta_neg_sep_k0' in 2
    replace se_neg = `se_neg_sep_k0' in 2
    replace beta_pos = `beta_pos_sep_k0' in 2
    replace se_pos = `se_pos_sep_k0' in 2
    replace p_asymmetry = `p_asym_k0' in 2
    replace N = `N_k0' in 2

    replace tenure = "k=1" in 3
    replace beta_neg = `beta_neg_sep_k1' in 3
    replace se_neg = `se_neg_sep_k1' in 3
    replace beta_pos = `beta_pos_sep_k1' in 3
    replace se_pos = `se_pos_sep_k1' in 3
    replace p_asymmetry = `p_asym_k1' in 3
    replace N = `N_k1' in 3

    replace tenure = "k=2" in 4
    replace beta_neg = `beta_neg_sep_k2' in 4
    replace se_neg = `se_neg_sep_k2' in 4
    replace beta_pos = `beta_pos_sep_k2' in 4
    replace se_pos = `se_pos_sep_k2' in 4
    replace p_asymmetry = `p_asym_k2' in 4
    replace N = `N_k2' in 4

    replace tenure = "k=3+" in 5
    replace beta_neg = `beta_neg_sep_k3' in 5
    replace se_neg = `se_neg_sep_k3' in 5
    replace beta_pos = `beta_pos_sep_k3' in 5
    replace se_pos = `se_pos_sep_k3' in 5
    replace p_asymmetry = `p_asym_k3' in 5
    replace N = `N_k3' in 5

    replace tenure = "Always informal" in 6
    replace beta_neg = `beta_neg_always' in 6
    replace se_neg = `se_neg_always' in 6
    replace p_asymmetry = `p_asym_always' in 6
    replace N = `N_always' in 6

    export delimited using "${tables}/R16_reference_dynamics.csv", replace
restore

* LaTeX table
file open texfile using "${tables}/R16_reference_dynamics.tex", write replace
file write texfile "\begin{table}[htbp]" _n
file write texfile "\centering" _n
file write texfile "\caption{Reference Point Dynamics: Consumption Smoothing by Tenure in Informal Sector}" _n
file write texfile "\begin{tabular}{lcccc}" _n
file write texfile "\toprule" _n
file write texfile " & $\beta^+$ & $\beta^-$ & Asymmetry & N \\" _n
file write texfile " & (SE) & (SE) & p-value & \\" _n
file write texfile "\midrule" _n
file write texfile "Formal (reference) & " %6.4f (`beta_pos_F') " & " %6.4f (`beta_neg_F') " & " %5.3f (`p_asym_F') " & \\" _n
file write texfile " & (" %5.4f (`se_pos_F') ") & (" %5.4f (`se_neg_F') ") & & \\" _n
file write texfile "\midrule" _n
file write texfile "\multicolumn{5}{l}{\textit{Informal workers by tenure:}} \\" _n
file write texfile "k=0 (just transitioned) & " %6.4f (`beta_pos_sep_k0') " & " %6.4f (`beta_neg_sep_k0') " & " %5.3f (`p_asym_k0') " & " %6.0f (`N_k0') " \\" _n
file write texfile "k=1 & " %6.4f (`beta_pos_sep_k1') " & " %6.4f (`beta_neg_sep_k1') " & " %5.3f (`p_asym_k1') " & " %6.0f (`N_k1') " \\" _n
file write texfile "k=2 & " %6.4f (`beta_pos_sep_k2') " & " %6.4f (`beta_neg_sep_k2') " & " %5.3f (`p_asym_k2') " & " %6.0f (`N_k2') " \\" _n
file write texfile "k=3+ & " %6.4f (`beta_pos_sep_k3') " & " %6.4f (`beta_neg_sep_k3') " & " %5.3f (`p_asym_k3') " & " %6.0f (`N_k3') " \\" _n
file write texfile "Always informal & --- & " %6.4f (`beta_neg_always') " & " %5.3f (`p_asym_always') " & " %6.0f (`N_always') " \\" _n
file write texfile "\midrule" _n
file write texfile "Test: $\delta^-(k=0) = \delta^-(k=3+)$ & \multicolumn{4}{c}{p = " %5.3f (`p_k0_vs_k3') "} \\" _n
file write texfile "\bottomrule" _n
file write texfile "\end{tabular}" _n
file write texfile "\label{tab:reference_dynamics}" _n
file write texfile "\end{table}" _n
file close texfile

*===============================================================================

log close

di as text _n "Log saved to: ${logdir}/R16_reference_point_dynamics.log"
di as text "Tables saved to: ${tables}/R16_reference_dynamics.tex"
di as text "Figures saved to: ${figures}/R16_reference_dynamics.png"

*===============================================================================
* END
*===============================================================================
