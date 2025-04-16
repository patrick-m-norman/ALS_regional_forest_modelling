# Load necessary libraries
library(ggplot2)
library(dplyr)
library(plyr)
library(stringi)   
library(tidyr)
library(reshape2)
library(purrr)
library(extrafont)
library(data.table)
library(glmmTMB)
library(MuMIn)
library(caret)
library(gbm)
library(mltools)
library(gridExtra)
library(grid)
library(lattice)


setwd(".")

#Reading in your large dataframe containing the explanatory variable (eg tree height) and the response variables (eg. environmental and geographic variables)
data <- fread("All_crowns_10perc_data.csv") %>% 

#Cleaning and manipulate your data to suit the BRT modelling step
Rjoined_data <- data[clum_values, on = .(clum_cleaned), nomatch = 0L, mult = "all", allow.cartesian = TRUE] %>% 
  mutate(SECV8 = as.factor(SECV8)) %>% 
  select(!clum_cleaned) %>% 
  select(!Asp) %>% 
  select(!pct) %>% 
  filter(!SoilType == "") %>% 
  mutate(vegForm = as.factor(vegForm)) %>%
  na.omit()
# Generate some sample data with a time series component
set.seed(123)

cross_corr_data <- Rjoined_data %>%
  dplyr::select(height,vegForm,slope,SoilType,SECV8, SoilFert,elevation,TWI, TPI,Dist_rds,yrs_since_fire,ADI,ADX,PTI,RSI,RSX,TNI,TRA,TXX) %>%
  na.omit()

create_train_test <- function(cross_corr_data, size = 0.3, train = TRUE) {
  n_row <- nrow(cross_corr_data)
  total_row <- round(size * n_row)
  train_sample <- sample(1:n_row, total_row)
  if (train) {
    return(cross_corr_data[train_sample, ])
  } else {
    return(cross_corr_data[-train_sample, ])
  }
}

# Split data into training and test sets
data_train <- create_train_test(cross_corr_data, 0.1, train = TRUE)
test_data <- sample_n(cross_corr_data, nrow(data_train))
test_data2 <- sample_n(cross_corr_data, nrow(data_train))

# Function to run the BRT model with variable selection
run_BRT_model <- function(data_train, variables, model_num) {
  formula <- as.formula(paste("height ~", paste(variables, collapse = " + ")))

  set.seed(102)  # Reproducibility
  BRT_model <- gbm(formula, data = data_train,
                   distribution = "gaussian", n.trees = 1000, shrinkage = 0.05,             
                   interaction.depth = 3, bag.fraction = 0.5, train.fraction = 0.5,  
                   n.minobsinnode = 10, cv.folds = 5, 
                   verbose = FALSE) 

  # Create a directory for storing results
  dir_name <- paste0("Var_", length(variables))
  if (!dir.exists(dir_name)) {
    dir.create(dir_name)
  }

  # Save model summary
  summary_results <- as.data.frame(summary(BRT_model))
  summary_file <- file.path(dir_name, paste0("model_summary_", length(variables), ".csv"))
  write.csv(summary_results, summary_file, row.names = FALSE)

  # Model evaluation
  best.iter <- gbm.perf(BRT_model, method = "cv", plot.it = FALSE)

  # Predictions on train and test datasets
  predictions_train <- predict(BRT_model, newdata = data_train, n.trees = best.iter, type = "response")
  predictions <- predict(BRT_model, newdata = test_data, n.trees = best.iter, type = "response")
  predictions2 <- predict(BRT_model, newdata = test_data2, n.trees = best.iter, type = "response")

  # Calculate Mean Absolute Error (MAE)
  mae_test <- mean(abs(predictions - test_data$height))
  print(mae_test)
  

  # Save **only one** MAE result
  mae_file <- file.path(dir_name, paste0("mae_results_", length(variables), ".csv"))
  write.csv(data.frame(mae_test), mae_file, row.names = FALSE)
  
  return(summary_results)
}

### Iterative Variable Selection Process ###
variables <- colnames(cross_corr_data)[-1]  # Exclude 'CBI_group' (dependent variable)
remaining_variables <- variables

while (length(remaining_variables) > 4) {
  print(paste("Running model with", length(remaining_variables), "variables..."))

  # Run model with the current set of variables
  summary_results <- run_BRT_model(data_train, remaining_variables, length(remaining_variables))

  # Print variable importance
  print(summary_results)

  # Identify the least important variable
  least_important_variable <- summary_results[which.min(summary_results$rel.inf), "var"]

  # Ensure we don't remove a crucial variable
  if (least_important_variable %in% remaining_variables) {
    remaining_variables <- setdiff(remaining_variables, least_important_variable)
    print(paste("Removing least important variable:", least_important_variable))
  } else {
    print("No valid variable found for removal. Exiting loop.")
    break
  }

  print(paste("Remaining variables:", paste(remaining_variables, collapse = ", ")))
}

print("Final model with 4 variables completed!")
