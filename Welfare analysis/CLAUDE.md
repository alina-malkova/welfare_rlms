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

## Related Project
Parent project: **Labor Informality and Credit Market** (under revision at *Journal of Comparative Economics*)
See `../CLAUDE.md` for full project documentation.
