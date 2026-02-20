# Welfare Cost of Labor Informality

## Research Question
What is the welfare cost of labor informality through the consumption smoothing channel? Do informal workers face asymmetric ability to smooth positive vs negative income shocks?

## Key Finding
- Informal workers have **impaired downside consumption smoothing**
- The informality penalty is concentrated on **negative income shocks**
- Welfare cost estimated at 2.3% of permanent consumption

## Data

### RLMS-HSE 1994-2023
- `Data/IND/RLMS_IND_1994_2023_eng_dta.dta` (~11 GB, person-year)
- `Data/HH/RLMS_HH_1994_2023_eng_dta.dta` (~2.5 GB, household-year)
- Both files are in **long format** (no reshaping needed)

### CBR Regional Financial Data
- `Data/CBR_data/bank_branches_annual.csv` - Bank branches by region-year
- `Data/CBR_data/bank_branches_panel.csv` - Monthly panel
- Source: Central Bank of Russia

### Rosstat Data
- `Data/Rosstat_data/regional_informal_employment.csv` - Regional informal employment rates

### Processed Datasets
- `Data/welfare_panel_raw.dta` - Base panel
- `Data/welfare_panel_consumption.dta` - With consumption measures
- `Data/welfare_panel_shocks.dta` - With shock variables
- `Data/welfare_panel_cbr.dta` - Merged with CBR regional data
- `Data/welfare_costs_by_year.dta` - Welfare cost estimates

## Directory Structure
```
Welfare analysis/
├── Data/           # Raw and processed data
│   ├── HH/         # Household-level RLMS
│   ├── IND/        # Individual-level RLMS
│   ├── CBR_data/   # Central Bank data
│   └── Rosstat_data/
├── Do files/       # Stata do-files (Step W0-W10)
├── Revision/       # Revision-specific analyses (R1, R2, ...)
├── Figures/        # Output figures
├── Tables/         # Output tables
├── Results/        # Paper, variable descriptions
└── Logs/           # Stata log files
```

## Do-File Pipeline

| Step | File | Description |
|------|------|-------------|
| W0 | `Step W0 - Setup and extract RLMS data.do` | Define globals, verify data |
| W1 | `Step W1 - Build welfare analysis panel.do` | Construct panel dataset |
| W2 | `Step W2 - Consumption and income measures.do` | Create consumption/income vars |
| W3 | `Step W3 - Shocks and informality classification.do` | Define shocks, informality |
| W4 | `Step W4 - Consumption smoothing.do` | Main consumption smoothing results |
| W4b-e | `Step W4b-e` | Extended robustness checks |
| W5 | `Step W5 - Credit access mechanism.do` | Credit mechanism tests |
| W6 | `Step W6 - Welfare cost quantification.do` | Welfare cost calculations |
| W7 | `Step W7 - Structural model.do` | Structural estimation |
| W8 | `Step W8 - Tables and figures.do` | Generate output |
| W9 | `Step W9 - Merge CBR regional data.do` | Add regional bank data |
| W10 | `Step W10 - Mechanism and robustness solutions.do` | Mechanism tests |

## Stata Globals
All do-files source `welfare_globals.do` which defines:
```stata
global base     "/Users/amalkova/.../Credit market (1)"
global welfare  "${base}/Welfare analysis"
global dodir    "${welfare}/Do files"
global data     "${welfare}/Data"
global results  "${welfare}/Results"
global tables   "${welfare}/Tables"
global figures  "${welfare}/Figures"
global logdir   "${welfare}/Logs"
```

## Key Variables

### Dependent
- `dlnc` - Change in log consumption

### Income Shocks
- `dlny_lab` - Change in log labor income
- `dlny_pos` - Positive income shocks (dlny_lab if > 0)
- `dlny_neg` - Negative income shocks (dlny_lab if < 0)

### Informality
- `informal` - Registration-based indicator (unregistered, self-employed, hired by private person)

### Interactions (Asymmetric Smoothing)
- `dlny_pos_x_inf` - Positive shock x Informal
- `dlny_neg_x_inf` - Negative shock x Informal

### Regional/Mechanism
- `bank_branches_pc` - Bank branches per capita
- `cma_high` - High credit market access indicator
- `buffer_months` - Household buffer stock (from RLMS F12A)

## Main Empirical Equation

```
dlnc = alpha + beta_pos*dlny_pos + beta_neg*dlny_neg
     + delta_pos*(dlny_pos x informal) + delta_neg*(dlny_neg x informal)
     + X'theta + mu_i + epsilon
```

**Interpretation:**
- `delta_pos ~ 0`: Informal workers smooth positive shocks like formal workers
- `delta_neg > 0`: Informal workers have impaired downside smoothing
- **Wald test** rejects H0: delta_pos = delta_neg (asymmetry confirmed)

## Methodological Notes

### Mechanism Tests (Step W10)
1. **Part A**: Direct coping mechanisms (savings drawdown, asset sales, secondary jobs)
2. **Part B**: Buffer stock mediation (RLMS F12A question)
3. **Part C**: Regional financial infrastructure heterogeneity (CBR data)
4. **Part D**: Wealth distribution test (borrowing constraints vs loss aversion)
5. **Part E**: Reframed narrative - penalty on downside
6. **Part F**: Spousal formality mechanism

### Key Distinction
- Under **borrowing constraints**: asymmetry stronger for low-wealth households
- Under **loss aversion**: asymmetry constant across wealth distribution

## Software
- **Stata 16+** (requires `gsem`, `reghdfe`, `margins`)
- **Python 3** (for CBR/Rosstat data downloads)

## Revision Materials

Located in `Revision/` subfolder.

### R1: Partial Identification of Loss Aversion Parameter

**Problem:** Previous approach used ad hoc calibration (eta = 0.5) to get lambda = 2.25.

**Solution:** Partial identification bounds approach using moment inequalities.

**Methodology:**
- Under prospect theory: v(x) = x^eta for gains, v(x) = -lambda*(-x)^eta for losses
- Observe (beta+, beta-) for formal and informal workers (four moments)
- Compute R = |beta_neg| / |beta_pos| (response ratio)
- For each eta in [0.1, 1.0], compute lambda(eta) = R^(1/eta)
- Report identified set: lambda in [min, max] over all eta

**Key Output:**
- `Tables/R1_bounds_grid.csv` - Lambda for each eta value
- `Tables/R1_bounds_summary.tex` - Summary table for paper
- `Figures/R1_lambda_bounds.gph` - Visual of identified set

**Interpretation:**
- Converts "we picked eta to get lambda = 2.25" into
- "lambda in [1.8, 3.0] for any reasonable eta" (far more credible)

---

## JEEA Revision Materials (February 2026)

### Priority Tests for JEEA Submission

| Priority | Test | File | Status |
|----------|------|------|--------|
| 1 | Exposed formal workers | `R11_exposed_formal_workers.do` | Ready |
| 2 | GMM estimation of λ and η | `R13_gmm_lambda_eta.do` | Ready |
| 3 | Asymmetric BPP by shock sign | `R12_asymmetric_bpp.do` | Ready |
| 4 | Reference point dynamics | `R16_reference_point_dynamics.do` | Ready |
| 5 | Causal Forest heterogeneity | `R14_causal_forest.R` | Ready |
| 6 | Double ML robustness | `R15_double_ml.R` | Ready |

### R11: Exposed Formal Workers Test (Validates Core Model)

**Problem:** Model claims formal workers have same λ but institutions mask it.

**Test:** Find "exposed" formal workers lacking insurance:
- Temporary/fixed-term contracts (no severance)
- Workers in firms with wage arrears
- Short tenure (< 12 months)

**Prediction:**
- If model correct: Exposed formal δ⁻ > 0 (similar to informal)
- If model wrong: Exposed formal δ⁻ ≈ 0 (type hypothesis)

**Output:** `Tables/R11_exposed_formal.tex`, `R11_exposed_formal_summary.csv`

### R12: Asymmetric BPP by Shock Sign (Novel Methodological Contribution)

**Novel contribution:** Four-way BPP decomposition:
- Permanent × Positive/Negative
- Transitory × Positive/Negative
- Formal vs Informal

**Prediction:**
- φ⁻_I ≫ φ⁻_F (informal penalty on negative transitory)
- φ⁺_I ≈ φ⁺_F (no difference on positive transitory)

**Method:**
```
Permanent shock proxy: ζ_t ≈ (Δy_t + Δy_{t+1})/2
Transitory shock: v_t = Δy_t - ζ_t
```

**Output:** `Tables/R12_asymmetric_bpp.tex`, `Figures/R12_fourway_bpp.png`

### R13: GMM Estimation of λ and η (Replaces Ad Hoc Calibration)

**Problem:** Current approach assumes η = 0.5 to get λ = 2.25.

**Solution:** Joint GMM estimation using moment conditions:
- m₁: R_I = λ^(1/η) where R_I = |β⁻_I|/|β⁺_I|
- m₂: R_F ≈ 1 (formal symmetry as overidentifying restriction)

**Identification:**
- λ = R_I^η (given η)
- Partial ID: λ ∈ [R_I^1.0, R_I^0.5] for η ∈ [0.5, 1]

**Output:** `Tables/R13_gmm_lambda_eta.tex`, `R13_lambda_eta_grid.csv`

### R14: Causal Forest for Heterogeneity (ML Method)

**Purpose:** Replace manual subgroup analysis with principled ML approach.

**Method:** Generalized Random Forest (Athey, Tibshirani & Wager, 2019)
- Estimates CATE: δ⁻(X_i) = E[Y | T=1, X] - E[Y | T=0, X]
- Treatment: Informal × 1[ΔlnY < 0]
- Discovers interactions without pre-specification

**Output:**
- Variable importance rankings
- Best linear projection onto covariates
- Policy targeting tree
- `Tables/R14_causal_forest_summary.csv`
- `Figures/R14_cate_distribution.png`

**R Package:** `grf`, `policytree`

### R15: Double ML Robustness (Functional Form)

**Purpose:** Test robustness to control function specification.

**Method:** Chernozhukov et al. (2018) Double ML
- Use LASSO/RF to flexibly estimate nuisance parameters
- Cross-fitting for valid inference
- If DML ≈ OLS: robust to functional form

**Specification:**
```
ΔlnC = α + δ⁻(ΔlnY⁻ × Informal) + g(X) + ε
```

**Output:** `Tables/R15_dml_comparison.csv`, `R15_dml_summary.csv`

**R Package:** `DoubleML`, `mlr3`

### R16: Reference Point Dynamics (K-R Model Test)

**Test:** Do reference points adapt slowly or quickly after formality transitions?

**Method:** Estimate δ⁻(k) for k = 0, 1, 2, 3+ years since becoming informal

**Predictions:**
- **Slow adaptation:** δ⁻(k=0) > δ⁻(k=3+) — reference still calibrated to formal consumption
- **Fast adaptation:** δ⁻(k=0) ≈ δ⁻(k=3+) — penalty immediate and stable

**Output:** `Tables/R16_reference_dynamics.tex`, `Figures/R16_reference_dynamics.png`

---

### Existing Revision Files (R1-R10)

| File | Description |
|------|-------------|
| R1 | Partial identification bounds for λ |
| R2 | Quantile regression (asymmetric effects) |
| R3 | Correlated random effects model |
| R4 | Permutation test for inference |
| R5 | Callaway-Sant'Anna event study |
| R6 | BPP decomposition (perm/trans) |
| R7 | Loss aversion vs habit formation |
| R8 | Regression kink design |
| R9 | Entropy balancing |
| R10 | Multiple hypothesis testing correction |

---

## Related Project
Parent project: **Labor Informality and Credit Market** (under revision at *Journal of Comparative Economics*)
See `../CLAUDE.md` for full project documentation.
