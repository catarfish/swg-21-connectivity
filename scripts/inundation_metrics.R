### this code compiles all the variations on inundation for the days that chl-a was collected
## 1 - inundation duration (inund_days from inundation package)
## 2 - inundation yes/no (inundation from inundation package)
## 3 - days since last inundation (day count for no inundation dates and zero for inundation dates)
## 4 - inundation duration on an annual scale (will only vary from 1 if multiple events within one year)
## 5 - total inundation in the previous water year

# bring in latest inundation data
library(devtools)
devtools::install_github("goertler/inundation")

library(inundation)

inun <- calc_inundation()

head(inun)
str(inun)

# get chl-a dates
chl <- read.csv("data_model/chlorophyll_fin.csv")
head(chl)
str(chl)

chl$date <- as.Date(chl$date)
max(chl$date) #2019-12-27
min(chl$date) #1998-01-06

# 1 & 2
# cut inundation data by chl-a dates
inun_metrics <- subset(inun, date > as.Date("1998-01-05") & date <= as.Date("2019-12-31"))

# get annual data summarized from inundation package
summary <- calc_summary()

# Jeanette's water year code
dates.posix <- as.POSIXlt(inun_metrics$date)
offset <- ifelse(dates.posix$mon >= 10 - 1, 1, 0)
inun_metrics$match_water_year <- dates.posix$year + 1900 + offset

# 5
# make previous year
summary$match_water_year <- summary$water_year+1
# pull in water yearly totals
inun_metrics <- merge(inun_metrics, summary[,c(2,4,8)], by = "match_water_year")
colnames(inun_metrics)[8] <- "total_inund_last_year"
colnames(inun_metrics)[1] <- "water_year"

# Cat found NAs
unique(inun_metrics$total_inund_last_year)
summary$total_days_inund # NAs should be zero
inun_metrics$total_inund_last_year[is.na(inun_metrics$total_inund_last_year)] <- 0

# 3
# assign 0 for days with inundation and NA otherwise (could also just make NAs)
inun_metrics$days_since_last_inundation <- ifelse(inun_metrics$inundation == 1, 0, NA)
# order by date
inun_metrics <- inun_metrics[order(as.Date(inun_metrics$date, format="%Y/%m/%d")),]

# for each row, make 0 if inundation = 1, then make consecutive sum for days between 0s
for(i in 2:nrow(inun_metrics)){
  if(inun_metrics[i, "inundation"] == 1)
    inun_metrics[i, "days_since_last_inundation"] <- 0
  else
    inun_metrics[i, "days_since_last_inundation"] <- inun_metrics[i-1, "days_since_last_inundation"]+1
  #browser()
  }

# fix beginning of time series
as.Date("1997-02-18")-as.Date("1998-01-06")# 322
inun_metrics[c(1:9),10] <- c(322, 323, 324, 325, 326, 327, 328, 329, 330)
inun_metrics <- inun_metrics[,-9]

# 4
# pull in number of inundation events per year
inun_metrics <- merge(inun_metrics, summary[,c(1,3,4,7)], by = "water_year")
# make NAs to zeros
unique(inun_metrics$number_overtopping_events)
inun_metrics$number_overtopping_events <- ifelse(is.na(inun_metrics$number_overtopping_events), 0,
                                                 inun_metrics$number_overtopping_events)

# get dates when more than one event in a water year
inun_metrics_with <- subset(inun_metrics, number_overtopping_events > 1)

# subset dry vs inundation and create new inundation seq to incorporate previous events
inun_metrics_with$days_of_inundation_until_now <- NA

inun_metrics_with_ind <- subset(inun_metrics_with, inundation == 1)

inun_metrics_with_dry <- subset(inun_metrics_with, inundation == 0)

# zero is still zero
inun_metrics_with_dry$days_of_inundation_until_now <- 0

head(inun_metrics_with_ind)

for(i in unique(inun_metrics_with_ind$water_year)){
  temp.d <- subset(inun_metrics_with_ind, water_year == i)
  inun_metrics_with_ind[row.names(temp.d), "days_of_inundation_until_now"] <- seq(1, nrow(temp.d), 1)
}

inun_metrics_with_new <- rbind(inun_metrics_with_ind, inun_metrics_with_dry)
inun_metrics_with_new <- inun_metrics_with_new[order(inun_metrics_with_new$date),]

head(inun_metrics_with_new)
View(inun_metrics_with_new)

# years with 0 or 1 events is the same as inund_days
inun_metrics_without <- subset(inun_metrics, number_overtopping_events < 2)
inun_metrics_without$days_of_inundation_until_now <- inun_metrics_without$inund_days

# put them back together
inun_metrics_fin <- rbind(inun_metrics_without, inun_metrics_with_new)
inun_metrics_fin <- inun_metrics_fin[,c(1:9,13)]

# write final data
write.csv(inun_metrics_fin, "data_clean/inundation_metrics.csv")

