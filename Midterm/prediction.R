# Import the libraries we use.
library(stringr)
library(forecast)
#setwd("C:/Users/Admin/Documents/DataScience/Midterm")
#sink("prediction_output.txt")
source("predict_config.R")
setwd("./data")

if (exists("training_quarter") && !is.na(training_quarter) && (nchar(training_quarter) > 1)) {
    print(sprintf("training quarter found: %s", training_quarter))
} else {
    print("Using default training quarter: Q1 2005")
    training_quarter <- "Q12005"
}

# Find the next quarter.
quarter <- substring(training_quarter, 2, 2)
training_year <- substring(training_quarter, 3, 6)

if (quarter == "4") {
    test_year <- as.character(1 + as.integer(training_year))
    test_quarter <- sprintf("Q1%s", test_year)
} else {
    quarter_next <- as.character(1 + as.integer(quarter))
    test_quarter <- sprintf("Q%s%s", quarter_next, training_year)
}

# Assemble the filenames for the training and test files.
training_zipfilename <- sprintf("./historical_data1_%s.zip", training_quarter)
training_txtfilename_orig <- sprintf("./historical_data1_%s.txt", training_quarter)
test_zipfilename <- sprintf("./historical_data1_%s.zip", test_quarter)
test_txtfilename_orig <- sprintf("./historical_data1_%s.txt", test_quarter)

# Check to see if the training text files are available.
if (!file.exists(training_txtfilename_orig)) {
    # Check to see if the training ZIP file has been downloaded.
    if (!file.exists(training_zipfilename)) {
        # File hasn't been downloaded, that's an error.
        stop(sprintf("training file '%s' is missing", training_zipfilename))
    } else {
        # If either of the text files is missing, unzip the archive.
        # Don't extract files that have already been extracted (overwrite=FALSE).
        unzip(training_zipfilename, overwrite=FALSE)
    }
}

# Check to see if the test text files are available.
if (!file.exists(test_txtfilename_orig)) {
    # Check to see if the test ZIP file has been downloaded.
    if (!file.exists(test_zipfilename)) {
        # File hasn't been downloaded, that's an error.
        stop(sprintf("test file '%s' is missing", test_zipfilename))
    } else {
        # If either of the text files is missing, unzip the archive.
        # Don't extract files that have already been extracted (overwrite=FALSE).
        unzip(test_zipfilename, overwrite=FALSE)
    }
}

# Read the training data into a dataframe.
origination_columns <- c('integer', 'integer', 'character', 'integer', 'character', 'real', 'integer', 'character', 'real', 'integer', 'integer','integer', 'real', 'character', 'character', 'character', 'character', 'character', 'character', 'character', 'character', 'integer', 'integer', 'character', 'character', 'character')

full_training_df <- read.table(training_txtfilename_orig,
                          sep="|",
                          header=FALSE,
                          colClasses=origination_columns )

names(full_training_df) = c('fico', 'dt_first_pi', 'flag_fthb', 'dt_matr', 'cd_msa', 'mi_pct', 'cnt_units', 'occpy_sts', 'cltv', 'dti', 'orig_upb', 'ltv', 'int_rt', 'channel', 'ppmt_pnlty', 'prod_type', 'st', 'prop_type', 'zipcode', 'id_loan', 'loan_purpose', 'orig_loan_term', 'cnt_borr', 'seller_name', 'servicer_name', 'flag_sc')

# flag_sc has no values, so can be dropped.
# prod_type has only 1 value: FRM, so can be dropped.
# id_loan is a synthetic value, so can be dropped.
# cd_msa is a factor with a large number of values that causes problems (memory, time) for the regression.
# But zipcode and state are also in there and they should be correlated (geographic location).
# Leave state, since that has the fewest factor levels.
# prop_type shows as insignificant.
# ltv shows as insignificant (and there's cltv, which is correlated)
# seller_name and servicer_name cause problems because they may have values in the test data that weren't present in the training data.
training_df <- subset(full_training_df, select=-c(prod_type, cd_msa, id_loan, flag_sc, dt_matr, zipcode, prop_type, ltv, seller_name, servicer_name))

model_all <- lm(int_rt ~ ., training_df)
summary(model_all)

# Read the test data.
test_df <- read.table(test_txtfilename_orig,
                          sep="|",
                          header=FALSE,
                          colClasses=origination_columns)

names(test_df) = c('fico', 'dt_first_pi', 'flag_fthb', 'dt_matr', 'cd_msa', 'mi_pct', 'cnt_units', 'occpy_sts', 'cltv', 'dti', 'orig_upb', 'ltv', 'int_rt', 'channel', 'ppmt_pnlty', 'prod_type', 'st', 'prop_type', 'zipcode', 'id_loan', 'loan_purpose', 'orig_loan_term', 'cnt_borr', 'seller_name', 'servicer_name', 'flag_sc')

# Make the predictions.
predictions = predict.lm(model_all, test_df)

# Put the basic prediction results - loan ID, actual rate, predicted rate - into a CSV file.
prediction_df <- data.frame(test_df["id_loan"], test_df["int_rt"], predictions)
names(prediction_df) = c("id_loan", "int_rt", "pred_int_rt")

prediction_txtfilename <- sprintf("./historical_data1_predicted_%s.csv", test_quarter)
write.csv(prediction_df, prediction_txtfilename, row.names=FALSE, fileEncoding="UTF-8")

# Measures of predictive accuracy.
accuracy(predictions, prediction_df[['int_rt']])

# Below this point is some manual exploratory stuff.
if (FALSE) {
    # See which columns are factors - not very useful, it said none of them were.
    l<-sapply(training_df, function(x) is.factor(x))
    l

    # Check to see which columns are irrelevant (interactively).
    lapply(training_df, unique)

    # Find correlation between x-variables.
    # with more time, could subset training_df so only
    # Shows that dt_matr and orig_loan_term are highly correlated, so can omit dt_matr.
    numeric_training_df <- subset(training_df, select=c(fico, dt_first_pi, dt_matr, mi_pct, cnt_units, cltv, dti, orig_upb, ltv, int_rt, orig_loan_term, cnt_borr))
    cor(numeric_training_df, method='pearson')

    install.packages("ISLR")
    install.packages("leaps")
    install.packages("MASS")
    install.packages("grid")
    install.packages("neuralnet")
    install.packages("randomForest")
}
#sink()
## Regression (Subset selection)
### Needed package and datasets
library(ISLR)
attach(training_df)
training_df=na.omit(training_df) # Get rid of NAs
library(leaps)

##### Searching all subset models up to size 8 by default
#sink("exhaustive_search.txt")
#regfit.full=regsubsets(int_rt~.,data=training_df,really.big = T)
#exhaustive_summary <- summary(regfit.full)
#exhaustive_summary$rss
#exhaustive_summary$adjr2
#exhaustive_summary$rsq

##### Searching all subset models up to size number of variables
regfit.full=regsubsets (int_rt~.,data=training_df ,nvmax=11,really.big = T)
reg.summary =summary (regfit.full)
names(reg.summary)
reg.summary$rss
reg.summary$adjr2
reg.summary$rsq
reg.summary

## Plotting and choosing the subset
par(mfrow=c(2,2))
plot(reg.summary$rss ,xlab="Number of Variables ",ylab="RSS", type="l")
plot(reg.summary$adjr2 ,xlab="Number of Variables ", ylab="Adjusted RSq",type="l")
coef(regfit.full ,6)
#sink()

#### Forward selection
#sink("forward_output.txt")
regfit.fwd=regsubsets(int_rt~.,data=training_df,nvmax=11, method="forward")
forward_summary=summary(regfit.fwd)
names(forward_summary)
forward_summary
forward_summary$rss
forward_summary$adjr2
coef(regfit.fwd,6)

#sink()
#### Backward selection
#sink("backward_output.txt")
regfit.bwd=regsubsets(int_rt~.,data=training_df, nvmax=11, method="backward")
backward_summary=summary(regfit.bwd)
names(backward_summary)
backward_summary
backward_summary$rss
backward_summary$adjr2
coef(regfit.bwd,6)
#sink()


######## Neural network
library(MASS)
library (grid)
library (neuralnet)

#Generate 50 random numbers uniformly distributed between 0 and 100
#And store them as a dataframe
#training_df <-  as.data.frame(runif(50, min=0, max=100))
#trainingoutput <- sqrt(training_df)

#Column bind the data into one variable
#trainingdata <- cbind(training_df,trainingoutput)
#colnames(trainingdata) <- c("Input","Output")

# Work around a bug in the neuralnet code.
# Don't include dt_matr and ltv since those are already removed from the training_df.
f <- as.formula('int_rt ~ fico + dt_first_pi + mi_pct + cnt_units + cltv + dti + orig_upb + orig_loan_term + cnt_borr')

#Train the neural network
#Going to have 2 hidden layers, each layer has 12 neurons
#Threshold is a numeric value specifying the threshold for the partial
#derivatives of the error function as stopping criteria.
net.sqrt <- neuralnet(f, data=training_df, hidden=c(8,8), threshold=0.1, stepmax=500)
print(net.sqrt)

#Plot the neural network
plot(net.sqrt)

#Test the neural network on some training data
#test_df <- as.data.frame((1:10)^2) #Generate some squared numbers
neuralnet_test_df = data.frame(test_df['fico'], test_df['dt_first_pi'], test_df['mi_pct'], test_df['cnt_units'], test_df['cltv'], test_df['dti'], test_df['orig_upb'], test_df['orig_loan_term'], test_df['cnt_borr'])
net.results <- compute(net.sqrt, neuralnet_test_df) #Run them through the neural network

# Put the basic prediction results - loan ID, actual rate, predicted rate - into a CSV file.
nn_prediction_df <- data.frame(test_df["id_loan"], test_df["int_rt"], net.results$net.result)
names(nn_prediction_df) = c("id_loan", "int_rt", "nn_pred_int_rt")

nn_prediction_txtfilename <- sprintf("./historical_data1_nn_predicted_%s.csv", test_quarter)
write.csv(nn_prediction_df, nn_prediction_txtfilename, row.names=FALSE, fileEncoding="UTF-8")

#Lets see what properties net.sqrt has
#ls(net.results)

#Lets see the results
#print(net.results$net.result)

#Lets display a better version of the results
#cleanoutput <- cbind(test_df,sqrt(test_df),
#                     as.data.frame(net.results$net.result))
#colnames(cleanoutput) <- c("Input","Expected Output","Neural Net Output")
#print(cleanoutput)


# Random forest
library("randomForest")

# Create the training data.  Character variables have to be converted to factors, but randomForest can only handle factors with 53 levels or fewer so we can't use the 'st' column.
rf_training_df <- subset(training_df, select=-c(st))

# Convert character columns to factors.
rf_training_df$flag_fthb <- as.factor(rf_training_df$flag_fthb)
rf_training_df$occpy_sts <- as.factor(rf_training_df$occpy_sts)
rf_training_df$channel <- as.factor(rf_training_df$channel)
rf_training_df$ppmt_pnlty <- as.factor(rf_training_df$ppmt_pnlty)
rf_training_df$loan_purpose <- as.factor(rf_training_df$loan_purpose)

rf_result <- randomForest(int_rt~., rf_training_df, ntree=3,nodesize=34, na.action=na.omit)

# View the forest results.
print(rf_result)

# Importance of each predictor.
print(importance(fit, type = 2))

# Create test data.
rf_test_df <- subset(test_df, select=-c(st))

# Convert character columns to factors.
rf_test_df$flag_fthb <- as.factor(rf_test_df$flag_fthb)
rf_test_df$occpy_sts <- as.factor(rf_test_df$occpy_sts)
rf_test_df$channel <- as.factor(rf_test_df$channel)
rf_test_df$ppmt_pnlty <- as.factor(rf_test_df$ppmt_pnlty)
rf_test_df$loan_purpose <- as.factor(rf_test_df$loan_purpose)

# Create predictions for the test data.
rf_predictions <- predict(rf_result, rf_test_df)

# Put the basic prediction results - loan ID, actual rate, predicted rate - into a CSV file.
rf_prediction_df <- data.frame(test_df["id_loan"], test_df["int_rt"], rf_predictions)
names(rf_prediction_df) = c("id_loan", "int_rt", "nn_pred_int_rt")

rf_prediction_txtfilename <- sprintf("./historical_data1_rf_predicted_%s.csv", test_quarter)
write.csv(rf_prediction_df, rf_prediction_txtfilename, row.names=FALSE, fileEncoding="UTF-8")

###########KNN algorithm

# Create a training data set that contains only numeric values, since we have to normalize it.
numeric_training_df <- subset(full_training_df, select=c(fico, dt_first_pi, dt_matr, mi_pct, cnt_units, cltv, dti, orig_upb, ltv, int_rt, orig_loan_term, cnt_borr))
summary(numeric_training_df)

# Drop NAs from the training data.
numeric_training_df <- na.omit(numeric_training_df)
summary(numeric_training_df)

numeric_test_df <- subset(test_df, select=c(fico, dt_first_pi, dt_matr, mi_pct, cnt_units, cltv, dti, orig_upb, ltv, int_rt, orig_loan_term, cnt_borr))
summary(numeric_test_df)

# Drop NAs from the training data.
numeric_test_df <- na.omit(numeric_test_df)
summary(numeric_test_df)


#Normalization function.
normalize<-function(x)(return((x-min(x))/(max(x)-min(x))))

# Normalize the training data set.
knn_training_df<-as.data.frame(lapply(numeric_training_df, normalize))
summary(knn_training_df)

# Normalize the test data set.
knn_test_df<-as.data.frame(lapply(numeric_test_df, normalize))
summary(knn_test_df)

# load the package
library(caret)

# fit model
fit <- knnreg(int_rt~., knn_training_df, k=3)

# summarize the fit
summary(fit)

# make predictions
predictions <- predict(fit, knn_test_df)

# summarize accuracy
mse <- mean((knn_test_df$int_rt - predictions)^2)
print(mse)

# Put the basic prediction results - loan ID, actual rate, predicted rate - into a CSV file.
#knn_prediction_df <- data.frame(test_df["id_loan"], test_df["int_rt"], predictions)
#names(knn_prediction_df) = c("id_loan", "int_rt", "rf_pred_int_rt")

#knn_prediction_txtfilename <- sprintf("./historical_data1_knn_predicted_%s.csv", test_quarter)
#write.csv(knn_prediction_df, knn_prediction_txtfilename, row.names=FALSE, fileEncoding="UTF-8")
