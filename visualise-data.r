library(ggplot2)
library(magrittr)

data %>%
  filter(datatype=="maxelec") %>%
  ggplot(aes(x = contrast, y = amplitude, color = group, group = group)) +
  stat_summary(fun.y = "mean", geom="line") +
  stat_summary(fun.data="mean_se", geom="pointrange")

data %>%
  filter(datatype=="maxelec" & !is.nan(amplitude)) %>%
  # filter outliers
  group_by(group, contrast) %>%
  filter(!(abs(amplitude - mean(amplitude)) > 3*sd(amplitude))) %>%
  ungroup() %>%
  # make plot
  ggplot(aes(x = contrast, y = amplitude, color = group, group = group)) +
  stat_summary(fun.y = "mean", geom="line", position=position_dodge(width=1)) +
  stat_summary(fun.data="mean_se", geom="pointrange", position=position_dodge(width=1))


data %>%
  filter(datatype=="maxelec" & !is.nan(amplitude)) %>%
  # filter outliers
  # group_by(group, contrast) %>%
  filter(!(abs(amplitude - mean(amplitude)) > 3*sd(amplitude))) %>%
  ungroup() %>%
  # Make ratio of lowest contrast
  group_by(ID) %>%
  mutate(amplitude = amplitude/amplitude[contrast==16]) %>%
  ggplot(aes(x = contrast, y = amplitude, color = group, group = group)) +
  stat_summary(fun.y = "mean", geom="line", position=position_dodge(width=3)) +
  stat_summary(fun.data="mean_se", geom="pointrange", position=position_dodge(width=3))

data %>%
  # Make ratio of lowest contrast
  group_by(ID) %>%
  mutate(amplitude = amplitude/amplitude[contrast==16]) %>%
  filter(datatype=="maxelec" & !is.nan(amplitude)) %>%
  # filter outliers
  group_by(group, contrast) %>%
  filter(!(abs(amplitude - mean(amplitude)) > 3*sd(amplitude))) %>%
  # only pick highest contrast ratio right now
  filter(contrast==100) %>%
  ggplot(aes(x = group, y = amplitude, color = group, group = group)) +
  geom_violin() +
  stat_summary(fun.data="mean_se", geom="pointrange", position=position_dodge(width=3))