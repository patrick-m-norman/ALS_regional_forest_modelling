# BRT_for_height_variablesBestCombination.R

# Load the required packages
library(gbm)
library(data.table)
library(dplyr)
library(tidyr)
library(caret)
library(shapr)

# Set working directory
setwd("/home/patrick/Desktop/AutoFilter_version/AllVars/Rerunning_best_model")

# Read and preprocess Land use data
clum_values <- fread('./clum_values.csv') %>% 
  mutate(clum_cleaned = as.numeric(substr(as.character(VALUE_first), 1, 2))) %>% 
  select(SECV8, clum_cleaned)
clum_values <- unique(clum_values, by = "clum_cleaned")

# Read and preprocess Forest type data
stvm_values <- fread('./pctid_values.csv') %>% 
  select(PCTID, vegForm)
stvm_values <- unique(stvm_values, by = "PCTID")

# Define a function to convert degrees to cardinal directions
degree2cardinal <- function(x) {
  upper <- seq(from = 11.25, by = 22.5, length.out = 17)
  upper <- append(upper, rep(NA, times=5)) 
  card1 <- c('N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW', 'N', '', '-', '--', '---', 'NA')
  compare <- x<=upper
  card1[which(compare)][1]
}

# Read and preprocess main data
data <- fread("./All_crowns_10perc_data.csv") %>% 
  filter(slope < 30) %>% 
  select(!fid) %>% 
  mutate(clum_cleaned = as.numeric(substr(as.character(clum), 1, 2))) %>% 
  mutate(replace(., is.na(.), 250)) %>% 
  mutate(SoilType = as.factor(SoilType)) %>% 
  mutate(clum = as.factor(clum)) %>% 
  mutate(cardinal = as.factor(sapply(Asp, degree2cardinal))) 

# Join clum_values and data
Rjoined_data <- data[clum_values, on = .(clum_cleaned), nomatch = 0L, mult = "all", allow.cartesian = TRUE] %>% 
  mutate(SECV8 = as.factor(SECV8)) %>% 
  select(!clum_cleaned) %>% 
  select(!Asp) %>% 
  left_join(stvm_values, join_by(pct == PCTID)) %>% 
  select(!pct) %>% 
  filter(!SoilFert > 4) %>% 
  filter(!SoilType == "") %>% 
  filter(height < 83) %>% 
  filter(height > 4) %>% 
  filter(slope < 31) %>% 
  select(height, vegForm, SoilType, elevation, TNI, ADX, PTI, TXX, TPI, slope) %>% 
  na.omit()

# Convert character columns to factors
for (i in 1:ncol(Rjoined_data)) { 
  if (typeof(Rjoined_data[[i]]) == 'character') { 
    Rjoined_data[[i]] <- as.factor(Rjoined_data[[i]]) 
  }
}

# Split data into training and test sets
training_test_split <- as.integer(nrow(Rjoined_data) / 3)
randomised_order <- sample(Rjoined_data)
training_data <- randomised_order[1:training_test_split, ]
test_data <- randomised_order[(training_test_split + 1):round(nrow(training_data) * 2), ]

print(nrow(training_data))
print(nrow(test_data))

# Fit a boosted regression tree model
boost_model <- gbm(
  height ~ .,
  data = training_data,
  distribution = "gaussian",
  n.trees = 10000,
  shrinkage = 0.05,
  interaction.depth = 5,
  bag.fraction = 0.5,
  train.fraction = 0.5,
  n.minobsinnode = 10,
  cv.folds = 5,
  verbose = FALSE,
  keep.data=TRUE,
  n.cores = 5
)
summary(boost_model)

# Save variable importance to CSV
summary_results <- as.data.frame(summary(boost_model))
write.csv(summary_results, "variable_importance.csv")

# Plot relative influence of each variable
par(mfrow = c(1, 2))
summary(boost_model, n.trees = 1)          # using first tree
summary(boost_model, n.trees = best.iter)  # using estimated best number of trees

# Print the first and last trees for curiosity
print(pretty.gbm.tree(boost_model, i.tree = 1))
print(pretty.gbm.tree(boost_model, i.tree = boost_model$n.trees))

Yhat <- predict(boost_model, newdata = test_data, n.trees = 50, type = "link")
mean_error <- sqrt(min(boost_model$cv.error))
best.iter <- gbm.perf(boost_model, method = "cv")
mae <- mean(abs(Yhat - test_data$height))

# Check performance using the 50% heldout test set
best.iter.oob <- gbm.perf(boost_model, method = "OOB")
print(best.iter.oob)

# Plot relative influence of each variable
par(mfrow = c(1, 2))
summary(boost_model, n.trees = 1)          # using first tree
summary(boost_model, n.trees = best.iter)  # using estimated best number of trees

# Plot individual variable effects
plot(boost_model, i.var = 1, n.trees = best.iter)
plot(boost_model, i.var = 2, n.trees = best.iter)
plot(boost_model, i.var = 3, n.trees = best.iter)
plot(boost_model, i.var = 4, n.trees = best.iter)
plot(boost_model, i.var = 5, n.trees = best.iter)
plot(boost_model, i.var = 6, n.trees = best.iter)
plot(boost_model, i.var = 7, n.trees = best.iter)
plot(boost_model, i.var = 8, n.trees = best.iter)
plot(boost_model, i.var = 9, n.trees = best.iter)
plot(boost_model, i.var = 10, n.trees = best.iter)

# Specify the phi_0, i.e. the expected prediction without any features
p0 <- mean(training_data$height)

y_var <- "height"
x_var <- c("SECV8", "slope", "vegForm", "TNI", "TPI", "elevation", "SoilType", "TXX", "PTI", "ADX")

ind_x_explain <- 1:10
x_train <- training_data[-ind_x_explain, ..x_var]
y_train <- training_data[-ind_x_explain, get(y_var)]
x_explain <- training_data[ind_x_explain, ..x_var]

# Define a prediction function for the model
MY_MINIMAL_predict_model <- function(x, newdata) {
  predict(x, as.data.frame(newdata), n.trees = x$n.trees)
}

# Compute Shapley values using Kernel SHAP
explanation <- explain(
  model = boost_model,
  x_explain = x_explain,
  x_train = x_train,
  approach = "empirical",
  phi0 = p0,
  predict_model = MY_MINIMAL_predict_model
)