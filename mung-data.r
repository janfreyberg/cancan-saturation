library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(magrittr)

# find latest spreadsheet
current.file <- tail(list.files(pattern='*.csv'), n=1)

# read data
data <- read_csv(current.file)

# turn id into ID and visit factor
data %<>%
  mutate(ID = str_extract(ids, "[:digit:]+") %>%
           str_pad(3, side="left", pad="0") %>%
           str_sub(start=-3, end=-1),
         visit = str_extract(ids, "[:alpha:]+") %>%
           str_to_lower())
# turn the 4 different variables into a tall list & factor
data %<>%
  gather(condition, amplitude, starts_with("stim_"))

# now create a contrast variable that's a numeric index & a variable for averaging method
data %<>%
  separate(condition, c("blah", "contrast", "datatype")) %>%
  mutate(contrast = as.numeric(contrast)) %>%
  select(-blah)

data %<>%
         mutate(group = ID %>%
                  str_sub(start=1, end=1) %>%
                  str_replace("0", "Control") %>%
                  str_replace("1", "Patient"))
