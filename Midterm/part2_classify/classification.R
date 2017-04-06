# Import the libraries we use.
library(stringr)
#setwd("C:/Users/Admin/Documents/DataScience/Midterm")
source("classification_config.R")
#setwd("./data")

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
training_txtfilename_perf <- sprintf("./historical_data1_time_%s.txt", training_quarter)
test_zipfilename <- sprintf("./historical_data1_%s.zip", test_quarter)
test_txtfilename_perf <- sprintf("./historical_data1_time_%s.txt", test_quarter)

# Check to see if the training text files are available.
if (!file.exists(training_txtfilename_perf)) {
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
if (!file.exists(test_txtfilename_perf)) {
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
performance_columns <- c('character', 'integer', 'real', 'character', 'integer', 'integer', 'character', 'character', 'character', 'integer', 'real', 'real', 'integer', 'integer', 'character', 'integer', 'integer', 'integer', 'integer', 'integer', 'integer', 'real', 'real')

training_df <- read.table(training_txtfilename_perf,
                          sep="|",
                          header=FALSE,
                          colClasses=performance_columns)

names(training_df)=c('id_loan', 'svcg_cycle', 'current_upb', 'delq_sts', 'loan_age', 'mths_remng', 'repch_flag', 'flag_mod', 'cd_zero_bal', 'dt_zero_bal', 'current_int_rt', 'non_int_brng_upb', 'dt_lst_pi', 'mi_recoveries', 'net_sale_proceeds', 'non_mi_recoveries', 'expenses', 'legal_costs', 'maint_pres_costs', 'taxes_ins_costs', 'misc_costs', 'actual_loss', 'modcost')

# Read the test data.
test_df <- read.table(test_txtfilename_perf,
                      sep="|",
                      header=FALSE,
                      colClasses=performance_columns)

names(test_df) = c('id_loan', 'svcg_cycle', 'current_upb', 'delq_sts', 'loan_age', 'mths_remng', 'repch_flag', 'flag_mod', 'cd_zero_bal', 'dt_zero_bal', 'current_int_rt', 'non_int_brng_upb', 'dt_lst_pi', 'mi_recoveries', 'net_sale_proceeds', 'non_mi_recoveries', 'expenses', 'legal_costs', 'maint_pres_costs', 'taxes_ins_costs', 'misc_costs', 'actual_loss', 'modcost')


# Create the 'Delinquent' column
training_df['Delinquent'] <- (training_df$delq_sts > 0)
test_df['Delinquent'] <- (test_df$delq_sts > 0)


# Below this point is some manual exploratory stuff.
if (FALSE) {
    # Check to see which columns are irrelevant (interactively).
    lapply(training_df, unique)

    install.packages('caret')
    install.packages('ROCR')
}

# Builds a Logistic regression model for the CURRENT LOAN DELINQUENCY STATUS
# using Q12005 data as training data (col 4).

# Only include data that is intrinsic to the loan, since we are trying to predict termination events.
glm_training_df <- data.frame(training_df['current_upb'], training_df['loan_age'], training_df['mths_remng'], training_df['repch_flag'], training_df['flag_mod'], training_df['current_int_rt'], training_df['non_int_brng_upb'], training_df['Delinquent'])
summary(lrg_training_df)
lapply(lrg_training_df, unique)

# Only include data that is intrinsic to the loan, since we are trying to predict termination events.
glm_test_df <- data.frame(test_df['current_upb'], test_df['loan_age'], test_df['mths_remng'], test_df['repch_flag'], test_df['flag_mod'], test_df['current_int_rt'], test_df['non_int_brng_upb'], test_df['Delinquent'])

# Fit a logistic regression model.
# A computer with 8GB memory and a Core i7 can't handle the full data set, so create a sample set.
set.seed(123)
sample_size <- 1000000
training_sample_df <- glm_training_df[sample(seq_len(nrow(glm_training_df)), size = sample_size), ]
test_sample_df <- glm_test_df[sample(seq_len(nrow(glm_test_df)), size = sample_size), ]


glm_model <- glm(Delinquent ~ ., data=training_sample_df, family=binomial(link="logit"))
summary(glm_model)

#Run the model on the test set
glm_predictions <- predict(glm_model, test_sample_df, type='response')
#pred <- rep(FALSE, length(glm_predictions))

#Set the cutoff value at 0.5
#pred[glm_predictions >= 0.5] <- TRUE

# Validates against Q22005 data and selects the best Classification model
# Compute ROC curve and Confusion matrices for training and testing datasets

# Repeat this using Random Forest algorithms.
# Repeat this using Neural Network models.
# Repeat this using SVN algorithms.


#Classification matrix
#library(caret)
#confusionMatrix(test$yndelq_sts, pred)

#ROC curve
#library(ROCR)
#prediction <- prediction(test.probs, test$ynadelq_sts)
#performance <- performance(prediction, measure = "tpr", x.measure = "fpr")
#plot(performance, main="ROC curve", xlab="1-Specificity", ylab="Sensitivity")

# fit in knn algorithm
#install.packages('class')
#library(class)
#m1<- knn(train= knn_training_df, test=knn_test_df, cl=train_target, k=13)

#result and comparison
#table(train_target,m1)

