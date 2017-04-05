library(ez)

data %>% 
  filter(datatype=="maxelec") %>%
  # optional: divide by lowest contrast
  group_by(ID) %>%
  mutate(amplitude = amplitude/amplitude[contrast==16]) %>%
  mutate(contrast = as.factor(contrast)) %>%
  filter(!is.nan(amplitude)) %>%
  ezANOVA(dv=amplitude, wid=ID,
          within=contrast,
          between=group)

data %>%
  filter(!is.nan(amplitude)) %>%
  filter(datatype=="maxelec") %>%
  filter(contrast == 100) %$%
  t.test(amplitude[group=="Control"], amplitude[group=="Patient"])

data %>%
  filter(!is.nan(amplitude)) %>%
  group_by(ID) %>%
  mutate(amplitude = amplitude/amplitude[contrast==16]) %>%
  filter(datatype=="maxelec") %>%
  filter(contrast == 100) %$%
  t.test(amplitude[group=="Control"], amplitude[group=="Patient"])
