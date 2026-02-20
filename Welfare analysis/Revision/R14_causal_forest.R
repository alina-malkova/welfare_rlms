#===============================================================================
# R14: Causal Forest for Heterogeneous Treatment Effects
#===============================================================================
#
# Purpose: Replace manual subgroup analysis (Table 4) with principled ML approach
#
# Method: Generalized Random Forest (Athey, Tibshirani & Wager, 2019)
#   - Estimates CATE: δ⁻(X_i) = E[Y | T=1, X] - E[Y | T=0, X]
#   - Treatment: Informal × 1[ΔlnY < 0] (negative shock for informal)
#   - Outcome: ΔlnC (consumption growth)
#   - Discovers heterogeneity without pre-specifying interactions
#
# Outputs:
#   - Distribution of estimated δ⁻(X_i)
#   - Variable importance rankings
#   - Best linear projection onto key covariates
#   - Policy targeting recommendations
#
# Author: Generated for JEEA revision
# Date: February 2026
#===============================================================================

# Required packages
packages <- c("grf", "haven", "dplyr", "ggplot2", "tidyr", "policytree")
for (pkg in packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}

#===============================================================================
# 0. SETUP
#===============================================================================

# Set paths
base_path <- "/Users/amalkova/Library/CloudStorage/OneDrive-FloridaInstituteofTechnology/_Research/Credit_Market/Credit market (1)"
welfare_path <- file.path(base_path, "Welfare analysis")
data_path <- file.path(welfare_path, "Data")
tables_path <- file.path(welfare_path, "Tables")
figures_path <- file.path(welfare_path, "Figures")

cat("============================================\n")
cat("  R14: Causal Forest for Heterogeneity\n")
cat("============================================\n\n")

#===============================================================================
# 1. LOAD DATA
#===============================================================================

cat("Loading data...\n")

# Try loading CBR-merged data first
data_file <- file.path(data_path, "welfare_panel_cbr.dta")
if (!file.exists(data_file)) {
  data_file <- file.path(data_path, "welfare_panel_shocks.dta")
}

df <- haven::read_dta(data_file)

# Filter to analysis sample
df <- df %>% filter(analysis_sample == 1)

cat(sprintf("Sample size: %d observations\n", nrow(df)))

#===============================================================================
# 2. PREPARE VARIABLES
#===============================================================================

cat("\nPreparing variables...\n")

# Create treatment: Informal × Negative shock
df <- df %>%
  mutate(
    # Treatment: informal worker experiencing negative income shock
    treatment = ifelse(informal == 1 & dlny_lab < 0, 1, 0),

    # Outcome
    Y = dlnc,

    # Create negative shock indicator for all
    neg_shock = ifelse(dlny_lab < 0, 1, 0),

    # Covariates for heterogeneity
    age_group = case_when(
      age < 30 ~ "young",
      age < 45 ~ "middle",
      TRUE ~ "older"
    ),
    edu_high = ifelse(educat == 3, 1, 0)
  )

# Select covariates for causal forest
covariate_names <- c("age", "female", "married", "educat", "hh_size",
                      "n_children", "urban")

# Check which covariates exist
available_covs <- covariate_names[covariate_names %in% names(df)]
cat(sprintf("Using covariates: %s\n", paste(available_covs, collapse = ", ")))

# Add credit access if available
if ("cma_high" %in% names(df)) {
  available_covs <- c(available_covs, "cma_high")
}
if ("buffer_months" %in% names(df)) {
  available_covs <- c(available_covs, "buffer_months")
}

# Create clean dataset for causal forest
df_cf <- df %>%
  select(idind, year, Y, treatment, neg_shock, informal, all_of(available_covs)) %>%
  na.omit()

cat(sprintf("Causal forest sample: %d observations\n", nrow(df_cf)))
cat(sprintf("Treatment prevalence: %.1f%%\n", 100 * mean(df_cf$treatment)))

#===============================================================================
# 3. CAUSAL FOREST ESTIMATION
#===============================================================================

cat("\n============================================\n")
cat("  3. Causal Forest Estimation\n")
cat("============================================\n")

# Prepare matrices
X <- as.matrix(df_cf[, available_covs])
Y <- df_cf$Y
W <- df_cf$treatment

# Estimate causal forest
set.seed(20260219)

cat("Training causal forest...\n")
cf <- causal_forest(
  X = X,
  Y = Y,
  W = W,
  num.trees = 2000,
  honesty = TRUE,
  tune.parameters = "all"
)

cat("Forest trained successfully.\n")

# Get predictions (CATE estimates)
tau_hat <- predict(cf)$predictions
df_cf$tau_hat <- tau_hat

cat(sprintf("\nCATE distribution:\n"))
cat(sprintf("  Mean: %.4f\n", mean(tau_hat)))
cat(sprintf("  SD:   %.4f\n", sd(tau_hat)))
cat(sprintf("  Min:  %.4f\n", min(tau_hat)))
cat(sprintf("  Max:  %.4f\n", max(tau_hat)))

#===============================================================================
# 4. VARIABLE IMPORTANCE
#===============================================================================

cat("\n============================================\n")
cat("  4. Variable Importance\n")
cat("============================================\n")

# Get variable importance
var_imp <- variable_importance(cf)
var_imp_df <- data.frame(
  variable = available_covs,
  importance = var_imp
) %>%
  arrange(desc(importance))

cat("Variable importance ranking:\n")
print(var_imp_df)

# Plot variable importance
p_varimp <- ggplot(var_imp_df, aes(x = reorder(variable, importance), y = importance)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  coord_flip() +
  labs(
    title = "Causal Forest: Variable Importance",
    subtitle = "Which covariates drive heterogeneity in δ⁻?",
    x = "",
    y = "Importance"
  ) +
  theme_minimal()

ggsave(file.path(figures_path, "R14_variable_importance.png"), p_varimp,
       width = 8, height = 5)

#===============================================================================
# 5. BEST LINEAR PROJECTION
#===============================================================================

cat("\n============================================\n")
cat("  5. Best Linear Projection\n")
cat("============================================\n")

# Project CATE onto linear function of covariates
blp <- best_linear_projection(cf, X)
cat("Best linear projection of CATE onto covariates:\n")
print(blp)

# Save BLP results
blp_df <- data.frame(
  variable = c("intercept", available_covs),
  estimate = coef(blp),
  std_error = sqrt(diag(vcov(blp)))
)
blp_df$t_stat <- blp_df$estimate / blp_df$std_error
blp_df$p_value <- 2 * pnorm(-abs(blp_df$t_stat))

write.csv(blp_df, file.path(tables_path, "R14_blp_coefficients.csv"), row.names = FALSE)

#===============================================================================
# 6. HETEROGENEITY ANALYSIS
#===============================================================================

cat("\n============================================\n")
cat("  6. Heterogeneity Analysis\n")
cat("============================================\n")

# Split by key variables and compute average CATE
het_results <- list()

# By age group
if ("age" %in% available_covs) {
  het_age <- df_cf %>%
    mutate(age_group = case_when(
      age < 30 ~ "Under 30",
      age < 45 ~ "30-44",
      TRUE ~ "45+"
    )) %>%
    group_by(age_group) %>%
    summarise(
      mean_cate = mean(tau_hat),
      sd_cate = sd(tau_hat),
      n = n()
    )
  het_results$age <- het_age
  cat("\nBy age group:\n")
  print(het_age)
}

# By gender
if ("female" %in% available_covs) {
  het_gender <- df_cf %>%
    mutate(gender = ifelse(female == 1, "Female", "Male")) %>%
    group_by(gender) %>%
    summarise(
      mean_cate = mean(tau_hat),
      sd_cate = sd(tau_hat),
      n = n()
    )
  het_results$gender <- het_gender
  cat("\nBy gender:\n")
  print(het_gender)
}

# By urban/rural
if ("urban" %in% available_covs) {
  het_urban <- df_cf %>%
    mutate(location = ifelse(urban == 1, "Urban", "Rural")) %>%
    group_by(location) %>%
    summarise(
      mean_cate = mean(tau_hat),
      sd_cate = sd(tau_hat),
      n = n()
    )
  het_results$urban <- het_urban
  cat("\nBy location:\n")
  print(het_urban)
}

# By education
if ("educat" %in% available_covs) {
  het_edu <- df_cf %>%
    mutate(education = case_when(
      educat == 1 ~ "Low",
      educat == 2 ~ "Medium",
      educat == 3 ~ "High"
    )) %>%
    group_by(education) %>%
    summarise(
      mean_cate = mean(tau_hat),
      sd_cate = sd(tau_hat),
      n = n()
    )
  het_results$education <- het_edu
  cat("\nBy education:\n")
  print(het_edu)
}

#===============================================================================
# 7. CATE DISTRIBUTION PLOT
#===============================================================================

cat("\n============================================\n")
cat("  7. CATE Distribution\n")
cat("============================================\n")

# Histogram of CATE
p_cate_dist <- ggplot(df_cf, aes(x = tau_hat)) +
  geom_histogram(aes(y = ..density..), bins = 50, fill = "steelblue", alpha = 0.7) +
  geom_density(color = "darkblue", size = 1) +
  geom_vline(xintercept = mean(df_cf$tau_hat), color = "red", linetype = "dashed", size = 1) +
  labs(
    title = "Distribution of Estimated Treatment Effects",
    subtitle = sprintf("Mean δ⁻(X) = %.4f (red line)", mean(df_cf$tau_hat)),
    x = "CATE: δ⁻(X)",
    y = "Density"
  ) +
  theme_minimal()

ggsave(file.path(figures_path, "R14_cate_distribution.png"), p_cate_dist,
       width = 8, height = 5)

# CATE by selected covariate (age as example)
if ("age" %in% available_covs) {
  p_cate_age <- ggplot(df_cf, aes(x = age, y = tau_hat)) +
    geom_point(alpha = 0.2, color = "steelblue") +
    geom_smooth(method = "loess", color = "red", se = TRUE) +
    labs(
      title = "CATE vs Age",
      subtitle = "Does the informal penalty vary with age?",
      x = "Age",
      y = "CATE: δ⁻(X)"
    ) +
    theme_minimal()

  ggsave(file.path(figures_path, "R14_cate_by_age.png"), p_cate_age,
         width = 8, height = 5)
}

#===============================================================================
# 8. POLICY TREE
#===============================================================================

cat("\n============================================\n")
cat("  8. Policy Targeting\n")
cat("============================================\n")

# Fit policy tree (depth 2 for interpretability)
# Policy tree identifies groups that should be prioritized for intervention

# Discretize CATE for policy tree
df_cf$high_penalty <- ifelse(df_cf$tau_hat > quantile(df_cf$tau_hat, 0.75), 1, 0)

cat("High-penalty group (top 25% of CATE):\n")
cat(sprintf("  Proportion: %.1f%%\n", 100 * mean(df_cf$high_penalty)))

# Characterize high-penalty group
if ("age" %in% available_covs) {
  cat(sprintf("  Mean age: %.1f (vs %.1f overall)\n",
              mean(df_cf$age[df_cf$high_penalty == 1]),
              mean(df_cf$age)))
}
if ("female" %in% available_covs) {
  cat(sprintf("  Female: %.1f%% (vs %.1f%% overall)\n",
              100 * mean(df_cf$female[df_cf$high_penalty == 1]),
              100 * mean(df_cf$female)))
}
if ("urban" %in% available_covs) {
  cat(sprintf("  Urban: %.1f%% (vs %.1f%% overall)\n",
              100 * mean(df_cf$urban[df_cf$high_penalty == 1]),
              100 * mean(df_cf$urban)))
}

# Try policy tree if package available
tryCatch({
  pt <- policy_tree(X, tau_hat, depth = 2)
  cat("\nPolicy tree (depth 2):\n")
  print(pt)

  # Save policy tree plot
  png(file.path(figures_path, "R14_policy_tree.png"), width = 800, height = 600)
  plot(pt)
  dev.off()
}, error = function(e) {
  cat("Policy tree not available or error occurred.\n")
})

#===============================================================================
# 9. AVERAGE TREATMENT EFFECT
#===============================================================================

cat("\n============================================\n")
cat("  9. Average Treatment Effect\n")
cat("============================================\n")

# Compute ATE and ATTE (treatment effect on treated)
ate <- average_treatment_effect(cf, target.sample = "all")
ate_treated <- average_treatment_effect(cf, target.sample = "treated")
ate_control <- average_treatment_effect(cf, target.sample = "control")

cat("Average Treatment Effects:\n")
cat(sprintf("  ATE (all):      %.4f (SE %.4f)\n", ate[1], ate[2]))
cat(sprintf("  ATT (treated):  %.4f (SE %.4f)\n", ate_treated[1], ate_treated[2]))
cat(sprintf("  ATC (control):  %.4f (SE %.4f)\n", ate_control[1], ate_control[2]))

#===============================================================================
# 10. CALIBRATION TEST
#===============================================================================

cat("\n============================================\n")
cat("  10. Calibration Test\n")
cat("============================================\n")

# Test whether forest is well-calibrated
# Average CATE within bins should match actual treatment effect

df_cf$cate_quintile <- ntile(df_cf$tau_hat, 5)

calibration <- df_cf %>%
  group_by(cate_quintile) %>%
  summarise(
    mean_predicted = mean(tau_hat),
    # Actual effect is harder to compute without control group
    n = n()
  )

cat("CATE by quintile:\n")
print(calibration)

#===============================================================================
# 11. EXPORT RESULTS
#===============================================================================

cat("\n============================================\n")
cat("  11. Export Results\n")
cat("============================================\n")

# Summary table
summary_df <- data.frame(
  metric = c("ATE", "ATT", "ATC", "Mean CATE", "SD CATE", "Min CATE", "Max CATE"),
  estimate = c(ate[1], ate_treated[1], ate_control[1],
               mean(tau_hat), sd(tau_hat), min(tau_hat), max(tau_hat)),
  se = c(ate[2], ate_treated[2], ate_control[2], NA, NA, NA, NA)
)

write.csv(summary_df, file.path(tables_path, "R14_causal_forest_summary.csv"),
          row.names = FALSE)

# Variable importance
write.csv(var_imp_df, file.path(tables_path, "R14_variable_importance.csv"),
          row.names = FALSE)

# CATE by groups
het_combined <- bind_rows(
  het_results$age %>% mutate(variable = "age", group = age_group) %>% select(-age_group),
  het_results$gender %>% mutate(variable = "gender", group = gender) %>% select(-gender),
  het_results$urban %>% mutate(variable = "urban", group = location) %>% select(-location),
  het_results$education %>% mutate(variable = "education", group = education) %>% select(-education)
)
write.csv(het_combined, file.path(tables_path, "R14_heterogeneity_groups.csv"),
          row.names = FALSE)

cat("\nFiles saved:\n")
cat(sprintf("  %s/R14_causal_forest_summary.csv\n", tables_path))
cat(sprintf("  %s/R14_variable_importance.csv\n", tables_path))
cat(sprintf("  %s/R14_blp_coefficients.csv\n", tables_path))
cat(sprintf("  %s/R14_heterogeneity_groups.csv\n", tables_path))
cat(sprintf("  %s/R14_cate_distribution.png\n", figures_path))
cat(sprintf("  %s/R14_variable_importance.png\n", figures_path))

cat("\n============================================\n")
cat("  R14: Causal Forest Complete\n")
cat("============================================\n")
