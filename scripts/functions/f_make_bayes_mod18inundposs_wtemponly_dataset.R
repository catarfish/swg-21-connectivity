# make_model dataset for bayesian JAGS model

library(dplyr)
library(readr)
library(lubridate)
library(glue)
library(tidyr)
library(zoo)

f_make_bayes_mod18inundposs_wtemponly_dataset <- function() {

  mod_df <- read_csv("data_model/model_covars_chla_fulljoin.csv") %>%
  mutate(rdoy  = lubridate::yday(date) + 92,
        dowy = ifelse(rdoy > 366, rdoy - 366, rdoy))

  # constrain to "day of water year" when Yolo Bypass gets inundated
  mod_df.idys = subset(mod_df, mod_df$inundation == 1)
  range(mod_df.idys$dowy)
  # min "day of water year" 65; max 237

  mod_df.idys = subset(mod_df, (mod_df$dowy >= 65 & mod_df$dowy <= 237))

  # pull out datasets
  chla_all <- mod_df.idys %>% select(region, station_wq_chl, date, chlorophyll) %>%
    mutate(doy1999 = as.numeric(difftime(date, as.Date("1999-02-22"), "day")))
  # starting in 1999, and don't have covars beyond 2019-09-30
  chla_below <- chla_all %>% filter(date > "1999-02-22", date < "2019-10-01") %>% filter(region == "below") %>%
   drop_na()

  covars_below <- mod_df %>% select(-chlorophyll,-latitude, -longitude, -source, -doy1998) %>%
    filter(region == "below") %>% filter(date > "1999-02-22")


  # Need to ensure that indexing for doy starts at 1 for 1st row of covars.  Also, make complete days for index to check for NAs.
  #doy1999 = as.numeric(difftime(date, ymd("1999-02-22"), "day"))
  days <- data.frame(date = seq(as.Date("1999-02-23"), as.Date("2019-12-31"), "day"))
  # Join
  covars_below <- left_join(days, covars_below)

  # Fill remaining NAs
  covars_checkNAs <- covars_below %>% filter(date > "1999-02-22") %>% filter(is.na(water_year))
  covars_datesNAs <- covars_checkNAs %>% select(date)

  covars_below_fillNAs <- mod_df %>% select(-chlorophyll, -latitude, -longitude, -source, -doy1998) %>%
    filter(region == "below") %>% filter(date > "1999-02-22")

  covars_NAs_filled <- left_join(covars_datesNAs, covars_below_fillNAs)
  covars_below <- covars_below %>% filter(date > "1999-02-22")
  covars_below_1 <- bind_rows(covars_NAs_filled, covars_below) %>% arrange(date) %>%
    filter(!is.na(water_year)) %>%
    mutate(doy1999 = as.numeric(difftime(date, as.Date("1999-02-22"), "day")),                inund_fac2 = ifelse(inund_days == 0, "none", ifelse(inund_days > 21, "long", "short")),
           tily_fac = case_when(total_inund_last_year == 0 ~ "none",                                                                                total_inund_last_year>0 & total_inund_last_year < 16 ~ "2wk",
                                                                                                                                                          total_inund_last_year>16 & total_inund_last_year < 41 ~ "month",
                                                                                                                                                                                            TRUE ~ "months"),
  tily_fac = as.factor(tily_fac),
  inund_fac2 = as.factor(inund_fac2))

  ########
  # select and scale the data
  covars_below_scaled <- covars_below_1 %>%
    mutate(Q = scale(Q_sday),
           Srad_mwk = scale(Sradmwk),
           Wtemp_mwk = scale(WTmwk),
           inund_days = scale(inund_days)) %>%
           #diurnal_range = scale(diurnal_range))
    select(-Q_sday, -Sradmwk, -WTmwk, -WTrangemwk, -station_wq_chl, -diurnal_range, -din, -diss_orthophos)

  covars_below_scaled$Q <- as.numeric(covars_below_scaled$Q)
  covars_below_scaled$Srad_mwk <- as.numeric(covars_below_scaled$Srad_mwk)
  covars_below_scaled$inund_days <- as.numeric(covars_below_scaled$inund_days)
  covars_below_scaled$Wtemp_mwk <- as.numeric(covars_below_scaled$Wtemp_mwk)

  # make list to save out
  model_df <- list("chla_below"=chla_below, "covars_below"=covars_below_scaled)

  # write out
  # if needed write to rds files:
  write_rds(chla_below, "bayes_models/mod18_below_inund_poss_sradonly/mod_chla_data.rds")
  write_rds(covars_below_scaled, file = "bayes_models/mod18_below_inund_poss_sradonly/mod_covariates_complete.rds")
  cat("Model datasets saved in list:\nmodel_df$covars and model_df$chla_all")

  # return data
  return(model_df)
}

