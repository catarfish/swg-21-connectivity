# clean chlorophyll data
library(dplyr)
library(readr)
library(contentid)
library(sf)
library(janitor)

f_clean_ybfmp_chla_nuts <- function() {

  # get raw data ID:
  chla_nuts_id <- contentid::store("data_raw/raw_chla_nuts_ybfmp.csv")
  chla_nuts_file <- contentid::resolve(chla_nuts_id)

  # read in data
  chla_nuts <- readr::read_csv(chla_nuts_file) %>%
    janitor::clean_names() %>%
    dplyr::mutate(date = lubridate::date(datetime),
                  source = "YBFMP",
                  field_coords = "FALSE",
                  depth = 1) %>%
    dplyr::mutate(field_coords = is.logical(field_coords)) %>%
    dplyr::filter(year(date) < 2020) %>%
    dplyr::select(-pheophytin, -wy, -sample_code)

  # write data
  readr::write_csv(chla_nuts, file="data_clean/clean_chla_nuts_ybfmp.csv")

  # print
  print("Data saved here: 'data_clean/clean_chla_nuts_ybfmp.csv'")
}
f_clean_ybfmp_chla_nuts()
