library(ez)

data %>% 
  filter(!is.nan(amplitude)) %>%
  filter(datatype=="maxelec") %>%
  mutate(contrast = as.factor(contrast)) %>%
  ezANOVA(dv=amplitude, wid=ID,
          within=contrast,
          between=group)

data %>%
  filter(!is.nan(amplitude)) %>%
  filter(datatype=="allelec") %>%
  filter(contrast == 100) %$%
  t.test(amplitude[group=="Control"], amplitude[group=="Patient"])
