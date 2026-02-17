# Credit Market and Labor Informality Project

## Paper
**"Labor Informality and Credit Market"** — under revision at the *Journal of Comparative Economics*.

The final manuscript and revision materials are in `Comparative Economics/`.

## Research Question
How does credit market accessibility influence the transition of workers from informal to formal employment in Russia? The paper shows that improved access to banking services incentivizes informal workers to seek formal jobs (with verifiable income) in order to qualify for loans, thereby reducing labor informality and tax evasion.

## Data
- **RLMS-HSE** (Russia Longitudinal Monitoring Survey - Higher School of Economics), 2006-2016
- Individual, household, and community-level panel data
- 160 communities across 32 regions and 7 federal districts
- Prime-age individuals (20-59 years old)
- Main dataset: `Comparative Economics/rlms_credit_workfile.dta` (~222 MB)
- Loan size data: `Comparative Economics/size of loan.dta`

## Key Variables
- **Dependent variable**: Employment status (formal / informal / non-employed)
- **Credit market accessibility**: Composite index from (1) bank presence in community, (2) distance to nearest Sberbank branch, (3) distance to nearest other bank, (4) regional bank branches per capita
- **Informality definitions**: (a) Registration-based (unregistered employees, self-employed, hired by private person, IEA workers); (b) Tax-based ("envelope earnings" - official vs unofficial pay)
- **Loan variables**: Household loan incidence, loan intention, loan type (consumer, mortgage, auto)
- **Controls**: Age, gender, ethnicity, education, marital status, household size, children, consumption, community population, urban/rural, federal district, year FE

## Methodology
- **Dynamic multinomial logit model** with correlated random effects
- **Mundlak-Chamberlain device** for correlated random effects
- **Wooldridge-Rabe-Hesketh-Skrondal (WRS)** method for endogenous initial conditions
- **Event study analysis** around first loan year
- **Logit model** for loan probability (Hypothesis 2)
- **Markov transition matrices** for borrowers vs non-borrowers
- **Policy simulations** of bank openings on labor market structure
- Robustness: Heckman initial conditions, excluding Moscow, additional controls, restricting to no-loan-intention sample, accounting for survey exit

## Key Findings
1. Formal workers have significantly higher probability of obtaining loans than informal workers
2. Informal-to-formal transition probability spikes in the year of loan acquisition (event study)
3. A 1SD improvement in credit accessibility increases informal-to-formal switching by 5.4 pp
4. Credit accessibility reduces "envelope earnings" (unofficial pay) by incentivizing income declaration
5. Effects are stronger in credit-constrained communities (lower income, higher unemployment, fewer banks)
6. Opening a bank branch in an underserved community increases formal sector share by ~2-2.5 pp

## Project Structure

### Main folder (`Credit market (1)/`)
- `Comparative Economics/` — Final revision package (manuscript, appendix, response, data, do-files)
- `Do files/` — Stata do-files for the full analysis pipeline
- `Data/` — Raw and processed data
- `Results/` — Output tables and figures
- `Literature/` — Reference papers
- `Paper/` — Earlier drafts
- `Revision/` — Revision-related materials
- `Submition/` and `Submition RES/` — Submission packages

### Stata Do-File Pipeline (`Do files/`)
| File | Description |
|------|-------------|
| `Step CRM1` | Community-regional variables for credit project |
| `Step CRM2` | Extract variables for the credit project |
| `Step CRM3` | Summary statistics |
| `Step CRM4` | Dynamic employment model (main model) |
| `Step CRM5` | Adjustment for attrition |
| `Step CRM6` | Alternative definitions of informality |
| `Step CRM7` | Policy simulation |
| `Step CRM8` | Heterogeneity of response |
| `Step CRM9` | Loan equation |
| `Revision.do` | Revision-specific analyses |

### Comparative Economics folder
- `Revised man.docx` / `.pdf` — Revised manuscript
- `Informality and credit - Appendix .docx` / `.pdf` — Appendix
- `Response.docx` — Response to reviewers
- `Research Highlights.docx` — Journal research highlights
- `AI statement.docx` — AI use statement
- `revision [Recovered].do` — Revision do-file (event study, triple-diff, wage analysis)
- `*.gph` — Stata graph files for figures

## Software
- **Stata** (primary) — all estimation, data cleaning, and visualization
- Key Stata commands: `gsem` (for dynamic multinomial logit with random effects), `eventdd`, `nnmatch`, `reghdfe`, `margins`, `marginsplot`, `oaxaca`

## Global Macros (in do-files)
```stata
global X1 "age age2 female russian ib1.educat_p schadjC married nmember nage13y lnhhcon lnpopsite urban intervday ib1.okrug ib1.year"
global IC "lnearn17 unrate17 pre1992 hhleftjob hhinvolun"
```

## Key Empirical Equations
- **Equation (4)**: Dynamic multinomial logit — `Y_{ij,t+1}* = Y_{ijt} * gamma_1j + C_{it} * gamma_2j + (Y_{ijt} . C_{it}) * gamma_3j + X_bar_i * beta_1j + X_{it} * beta_2j + mu_{ij} + epsilon`
- **Equation (5)**: Loan probability logit — `L* = Y_{ijt} * phi_j1 + C_{it} * phi_2 + X_bar_i * phi_3 + X_{it} * phi_4 + lambda_i + v`
- Base outcome (dependent): Informal job; Omitted lagged category: Formal job

---

## Welfare Analysis Extension

### Project: Welfare Cost of Labor Informality

Located in `Welfare analysis/` subfolder. Extends the credit market analysis to quantify welfare costs of informality through consumption smoothing.

### Research Question
What is the welfare cost of labor informality through the consumption smoothing channel? Do informal workers face asymmetric ability to smooth positive vs negative income shocks?

### Key Finding
- Informal workers have **impaired downside consumption smoothing**
- The informality penalty is concentrated on **negative income shocks**
- Welfare cost estimated at 2.3% of permanent consumption

### Data
- **RLMS-HSE 1994-2023** (extended panel)
  - `Data/IND/RLMS_IND_1994_2023_eng_dta.dta` (11 GB)
  - `Data/HH/RLMS_HH_1994_2023_eng_dta.dta` (2.5 GB)
- **CBR Regional Financial Data** (newly added)
  - `Data/CBR_data/bank_branches_annual.csv` - Bank branches by region-year (2019-2026)
  - `Data/CBR_data/bank_branches_panel.csv` - Monthly panel
  - Source: Central Bank of Russia (https://www.cbr.ru/eng/statistics/)
- **Rosstat Informal Employment** (newly added)
  - `Data/Rosstat_data/regional_informal_employment.csv` - Regional informal rates

### Welfare Analysis Do-Files (`Welfare analysis/Do files/`)
| File | Description |
|------|-------------|
| `Step W0` | Setup and extract RLMS data |
| `Step W1` | Build welfare analysis panel |
| `Step W2` | Consumption and income measures |
| `Step W3` | Shocks and informality classification |
| `Step W4` | Consumption smoothing (main results) |
| `Step W4b-e` | Extended robustness checks |
| `Step W5` | Credit access mechanism |
| `Step W6` | Welfare cost quantification |
| `Step W7` | Structural model |
| `Step W8` | Tables and figures |
| `Step W9` | **NEW**: Merge CBR regional data |
| `Step W10` | **NEW**: Mechanism tests and robustness solutions |

### Key Methodological Approaches (Step W10)

**Problem 1: Credit mechanism doesn't work**
- Part A: Direct coping mechanism analysis (savings drawdown, asset sales, secondary jobs)
- Part B: Buffer stock mediation test (RLMS F12A question)
- Part C: Regional financial infrastructure heterogeneity (CBR data)
- Part F: Spousal formality mechanism

**Problem 2: Borrowing constraints vs. loss aversion**
- Part D: Wealth distribution test
  - Under borrowing constraints: asymmetry stronger for low-wealth households
  - Under loss aversion: asymmetry constant across wealth distribution

**Problem 3: δ⁺ weakly significant**
- Part E: Reframed narrative - "penalty concentrated on downside"
- Key: Wald test rejecting symmetry is the headline result

### Key Variables
- **Dependent**: `dlnc` - Change in log consumption
- **Income shocks**: `dlny_lab`, `dlny_pos`, `dlny_neg` (positive/negative)
- **Informality**: `informal` - Registration-based indicator
- **Interactions**: `dlny_pos_x_inf`, `dlny_neg_x_inf` - Asymmetric smoothing
- **Regional**: `bank_branches_pc`, `cma_high`, `low_bank_access`
- **Buffer stock**: `buffer_months` (from F12A)

### Empirical Equation (Asymmetric Smoothing)
```
Δln(C) = α + β⁺·Δln(Y)⁺ + β⁻·Δln(Y)⁻
       + δ⁺·(Δln(Y)⁺ × Informal) + δ⁻·(Δln(Y)⁻ × Informal)
       + X'θ + μᵢ + ε
```

- δ⁺ ≈ 0: Informal workers smooth positive shocks like formal workers
- δ⁻ > 0: Informal workers have impaired downside smoothing
- Wald test: H₀: δ⁺ = δ⁻ → REJECT (asymmetry confirmed)
