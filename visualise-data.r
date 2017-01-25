library(ggplot2)

data %>%
  filter(datatype=="maxelec") %>%
  ggplot(aes(x = contrast, y = amplitude, color = group, group = group)) +
  stat_summary(fun.y = "mean", geom="line") +
  stat_summary(fun.data="mean_se", geom="pointrange")

data %>%
  filter(datatype=="allelec") %>%
  ggplot(aes(x = contrast, y = amplitude, color = group, group = group)) +
  stat_summary(fun.y = "mean", geom="line", position=position_dodge(width=1)) +
  stat_summary(fun.data="mean_se", geom="pointrange", position=position_dodge(width=1))


data %>%
  filter(datatype=="maxelec") %>%
  group_by(ID) %>%
  mutate(amplitude = amplitude/amplitude[contrast==16]) %>%
  ggplot(aes(x = contrast, y = amplitude, color = group, group = group)) +
  stat_summary(fun.y = "mean", geom="line", position=position_dodge(width=3)) +
  stat_summary(fun.data="mean_se", geom="pointrange", position=position_dodge(width=3))

data %>%
  filter(datatype=="maxelec") %>%
  group_by(ID) %>%
  mutate(amplitude = amplitude/amplitude[contrast==16]) %>%
  mutate(contrast = as.factor(contrast)) %>%
  filter(!is.nan(amplitude)) %>%
  ezANOVA(dv=amplitude, wid=ID,
          within=contrast,
          between=group)
  