library(ez)

data %>% 
  filter(!is.nan(amplitude)) %>%
  ezANOVA(dv=amplitude, wid=ID,
          within=contrast,
          between=group)
