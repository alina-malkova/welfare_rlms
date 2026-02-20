#===============================================================================
# R15: Double/Debiased Machine Learning
#===============================================================================
#
# Purpose: Robustness check for main specification using flexible ML for
#          nuisance parameters
#
# Method: Chernozhukov et al. (2018) Double ML
#   - Use ML (LASSO, Random Forest) to flexibly estimate controls
#   - Cross-fitting for valid inference
#   - Compare to OLS: if similar, results robust to functional form
#
# Key Specification:
#   ΔlnC = α + δ⁻(ΔlnY⁻ × Informal) + X'θ + ε
#
# We estimate δ⁻ after partialling out controls X using ML
#
# Author: Generated for JEEA revision
# Date: February 2026
#===============================================================================

# Required packages
packages <- c("DoubleML", "mlr3", "mlr3learners", "haven", "dplyr", "data.table")
for (pkg in packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

#===============================================================================
# 0. SETUP
#===============================================================================

base_path <- "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/_Research/Credit_Market/Credit market (1)"
welfare_path <- file.path(base_path, "Welfare analysis")
data_path <- file.path(welfare_path, "Data")
tables_path <- file.path(welfare_path, "Tables")

cat("============================================\n")
cat("  R15: Double Machine Learning\n")
cat("============================================\n\n")

#===============================================================================
# 1. LOAD AND PREPARE DATA
#===============================================================================

cat("Loading data...\n")

data_file <- file.path(data_path, "welfare_panel_cbr.dta")
if (!file.exists(data_file)) {
  data_file <- file.path(data_path, "welfare_panel_shocks.dta")
}

df <- haven::read_dta(data_file)
df <- df %>% filter(analysis_sample == 1)

# Create treatment variable
df <- df %>%
  mutate(
    # Treatment: negative shock interaction with informal
    dlny_neg_x_inf = pmin(dlny_lab, 0) * informal,

    # Also create positive shock interaction
    dlny_pos_x_inf = pmax(dlny_lab, 0) * informal,

    # Main shocks
    dlny_pos = pmax(dlny_lab, 0),
    dlny_neg = pmin(dlny_lab, 0)
  )

# Select covariates
covariate_names <- c("age", "female", "married", "educat", "hh_size",
                     "n_children", "urban", "year")
available_covs <- covariate_names[covariate_names %in% names(df)]

# Add year dummies
years <- unique(df$year[!is.na(df$year)])
for (yr in years[-1]) {  # Exclude reference year
  df[[paste0("year_", yr)]] <- ifelse(df$year == yr, 1, 0)
  available_covs <- c(available_covs[available_covs != "year"],
                       paste0("year_", yr))
}

# Create analysis dataset
df_dml <- df %>%
  select(idind, year, dlnc, dlny_neg_x_inf, dlny_pos_x_inf,
         dlny_pos, dlny_neg, informal, all_of(available_covs)) %>%
  na.omit()

cat(sprintf("Sample size: %d\n", nrow(df_dml)))

#===============================================================================
# 2. BENCHMARK OLS ESTIMATE
#===============================================================================

cat("\n============================================\n")
cat("  2. Benchmark OLS\n")
cat("============================================\n")

# Simple OLS for comparison
formula_ols <- as.formula(paste(
  "dlnc ~ dlny_pos + dlny_neg + dlny_pos_x_inf + dlny_neg_x_inf + informal +",
  paste(available_covs, collapse = " + ")
))

ols_fit <- lm(formula_ols, data = df_dml)
ols_coef <- coef(summary(ols_fit))

cat("OLS estimates:\n")
cat(sprintf("  δ⁺ (dlny_pos_x_inf): %.4f (SE %.4f)\n",
            ols_coef["dlny_pos_x_inf", "Estimate"],
            ols_coef["dlny_pos_x_inf", "Std. Error"]))
cat(sprintf("  δ⁻ (dlny_neg_x_inf): %.4f (SE %.4f)\n",
            ols_coef["dlny_neg_x_inf", "Estimate"],
            ols_coef["dlny_neg_x_inf", "Std. Error"]))

#===============================================================================
# 3. DOUBLE ML SETUP
#===============================================================================

cat("\n============================================\n")
cat("  3. Double ML Setup\n")
cat("============================================\n")

# Create DoubleML data object
# For partially linear model: Y = θ*D + g(X) + ε

# We'll estimate δ⁻ (coefficient on dlny_neg_x_inf)
# treating dlny_neg_x_inf as the treatment D
# and other variables as controls X

X_vars <- c("dlny_pos", "dlny_neg", "dlny_pos_x_inf", "informal", available_covs)

# Convert to data.table for DoubleML
dt <- data.table(df_dml)

# Define learners
# ML methods for nuisance functions
ml_l <- lrn("regr.cv_glmnet", alpha = 1)  # LASSO for E[Y|X]
ml_m <- lrn("regr.cv_glmnet", alpha = 1)  # LASSO for E[D|X]

# Alternative: Random Forest
ml_l_rf <- lrn("regr.ranger", num.trees = 500)
ml_m_rf <- lrn("regr.ranger", num.trees = 500)

#===============================================================================
# 4. DOUBLE ML ESTIMATION - LASSO
#===============================================================================

cat("\n============================================\n")
cat("  4. Double ML with LASSO\n")
cat("============================================\n")

# Create DoubleML data
dml_data <- DoubleMLData$new(
  dt,
  y_col = "dlnc",
  d_col = "dlny_neg_x_inf",
  x_cols = X_vars
)

# Partially linear regression with LASSO
set.seed(20260219)
dml_plr_lasso <- DoubleMLPLR$new(
  dml_data,
  ml_l = ml_l,
  ml_m = ml_m,
  n_folds = 5,
  score = "partialling out"
)

dml_plr_lasso$fit()
dml_plr_lasso$summary()

lasso_coef <- dml_plr_lasso$coef
lasso_se <- dml_plr_lasso$se

cat(sprintf("\nDML-LASSO estimate for δ⁻:\n"))
cat(sprintf("  Coefficient: %.4f (SE %.4f)\n", lasso_coef, lasso_se))
cat(sprintf("  95%% CI: [%.4f, %.4f]\n",
            lasso_coef - 1.96 * lasso_se,
            lasso_coef + 1.96 * lasso_se))

#===============================================================================
# 5. DOUBLE ML ESTIMATION - RANDOM FOREST
#===============================================================================

cat("\n============================================\n")
cat("  5. Double ML with Random Forest\n")
cat("============================================\n")

# Partially linear regression with RF
set.seed(20260219)
dml_plr_rf <- DoubleMLPLR$new(
  dml_data,
  ml_l = ml_l_rf,
  ml_m = ml_m_rf,
  n_folds = 5,
  score = "partialling out"
)

dml_plr_rf$fit()
dml_plr_rf$summary()

rf_coef <- dml_plr_rf$coef
rf_se <- dml_plr_rf$se

cat(sprintf("\nDML-RF estimate for δ⁻:\n"))
cat(sprintf("  Coefficient: %.4f (SE %.4f)\n", rf_coef, rf_se))
cat(sprintf("  95%% CI: [%.4f, %.4f]\n",
            rf_coef - 1.96 * rf_se,
            rf_coef + 1.96 * rf_se))

#===============================================================================
# 6. ALSO ESTIMATE δ⁺ FOR COMPARISON
#===============================================================================

cat("\n============================================\n")
cat("  6. Also Estimate δ⁺\n")
cat("============================================\n")

# Create data for δ⁺
X_vars_pos <- c("dlny_pos", "dlny_neg", "dlny_neg_x_inf", "informal", available_covs)

dml_data_pos <- DoubleMLData$new(
  dt,
  y_col = "dlnc",
  d_col = "dlny_pos_x_inf",
  x_cols = X_vars_pos
)

# LASSO for δ⁺
set.seed(20260219)
dml_plr_pos <- DoubleMLPLR$new(
  dml_data_pos,
  ml_l = lrn("regr.cv_glmnet", alpha = 1),
  ml_m = lrn("regr.cv_glmnet", alpha = 1),
  n_folds = 5
)
dml_plr_pos$fit()

pos_coef <- dml_plr_pos$coef
pos_se <- dml_plr_pos$se

cat(sprintf("DML-LASSO estimate for δ⁺:\n"))
cat(sprintf("  Coefficient: %.4f (SE %.4f)\n", pos_coef, pos_se))

#===============================================================================
# 7. COMPARISON TABLE
#===============================================================================

cat("\n============================================\n")
cat("  7. Comparison: OLS vs DML\n")
cat("============================================\n")

comparison <- data.frame(
  Method = c("OLS", "DML-LASSO", "DML-RF"),
  delta_neg = c(ols_coef["dlny_neg_x_inf", "Estimate"], lasso_coef, rf_coef),
  se_neg = c(ols_coef["dlny_neg_x_inf", "Std. Error"], lasso_se, rf_se),
  delta_pos = c(ols_coef["dlny_pos_x_inf", "Estimate"], pos_coef, NA),
  se_pos = c(ols_coef["dlny_pos_x_inf", "Std. Error"], pos_se, NA)
)

print(comparison)

# Check if DML and OLS are similar
diff_lasso <- abs(lasso_coef - ols_coef["dlny_neg_x_inf", "Estimate"])
diff_rf <- abs(rf_coef - ols_coef["dlny_neg_x_inf", "Estimate"])

cat(sprintf("\nOLS-DML comparison:\n"))
cat(sprintf("  |OLS - LASSO|: %.4f\n", diff_lasso))
cat(sprintf("  |OLS - RF|:    %.4f\n", diff_rf))

if (diff_lasso < 0.02 & diff_rf < 0.02) {
  cat("\n✓ ROBUST: DML estimates close to OLS\n")
  cat("  Results not sensitive to functional form assumptions\n")
} else {
  cat("\n⚠ Some difference between OLS and DML\n")
  cat("  Consider reporting DML as robustness check\n")
}

#===============================================================================
# 8. SENSITIVITY ANALYSIS
#===============================================================================

cat("\n============================================\n")
cat("  8. Sensitivity to Tuning\n")
cat("============================================\n")

# Try different LASSO penalty
alphas <- c(0.1, 0.5, 1.0)  # elastic net mixing
results_alpha <- data.frame(alpha = numeric(), coef = numeric(), se = numeric())

for (a in alphas) {
  ml_l_a <- lrn("regr.cv_glmnet", alpha = a)
  ml_m_a <- lrn("regr.cv_glmnet", alpha = a)

  set.seed(20260219)
  dml_a <- DoubleMLPLR$new(dml_data, ml_l = ml_l_a, ml_m = ml_m_a, n_folds = 5)
  dml_a$fit()

  results_alpha <- rbind(results_alpha, data.frame(
    alpha = a,
    coef = dml_a$coef,
    se = dml_a$se
  ))
}

cat("Sensitivity to elastic net alpha:\n")
print(results_alpha)

#===============================================================================
# 9. EXPORT RESULTS
#===============================================================================

cat("\n============================================\n")
cat("  9. Export Results\n")
cat("============================================\n")

# Main comparison table
write.csv(comparison, file.path(tables_path, "R15_dml_comparison.csv"),
          row.names = FALSE)

# Sensitivity results
write.csv(results_alpha, file.path(tables_path, "R15_dml_sensitivity.csv"),
          row.names = FALSE)

# Summary for paper
summary_dml <- data.frame(
  specification = c("OLS", "DML-LASSO", "DML-RF"),
  delta_minus = c(ols_coef["dlny_neg_x_inf", "Estimate"], lasso_coef, rf_coef),
  se = c(ols_coef["dlny_neg_x_inf", "Std. Error"], lasso_se, rf_se),
  ci_lo = c(ols_coef["dlny_neg_x_inf", "Estimate"] - 1.96 * ols_coef["dlny_neg_x_inf", "Std. Error"],
            lasso_coef - 1.96 * lasso_se,
            rf_coef - 1.96 * rf_se),
  ci_hi = c(ols_coef["dlny_neg_x_inf", "Estimate"] + 1.96 * ols_coef["dlny_neg_x_inf", "Std. Error"],
            lasso_coef + 1.96 * lasso_se,
            rf_coef + 1.96 * rf_se)
)

write.csv(summary_dml, file.path(tables_path, "R15_dml_summary.csv"),
          row.names = FALSE)

cat(sprintf("\nFiles saved to %s/R15_*.csv\n", tables_path))

cat("\n============================================\n")
cat("  R15: Double ML Complete\n")
cat("============================================\n")
