library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(magrittr)

# process unblinding
unblinding <-
  read_csv('cancan-unblinding.csv', col_names = c('id', 'a', 'b', 'c')) %>%
  filter(a != 'a') %>%
  gather(visit, drug, a, b, c) %>%
  mutate(drug = str_to_lower(drug),
         id = str_pad(id, 3, pad=0))

# read data
outcomes <-
  read_csv(tail(list.files(pattern='data.csv'), n=1)) %>% select(-X1) %>%
  # create drug variable from visits
  rowwise() %>%
  mutate(drug = unblinding$drug[unblinding$id == id & unblinding$visit == visit]) %>%
  # create a group variable
  mutate(group = id %>% str_replace('0[0-9]{2}', "con") %>% str_replace('1[0-9]{2}', "asd")) %>%
  # make dataframe tall
  gather(datatype, value, contains("_")) %>%
  # separate datatype
  separate(datatype, c('type', 'evalmethod', 'contrast')) %>%
  # make contrast numeric
  mutate(contrast = as.numeric(contrast))

# find people with one visit
# data %>%
#   group_by(ID) %>%
#   mutate(visits = n()/8) %>%
#   filter(visits==1) %>%
#   mutate(attended = paste0(ID, visit)) %>%
#   ungroup %>%
#   distinct(attended) %>%
#   arrange(attended)