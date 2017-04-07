
# data %>%
#   filter(datatype=="maxelec") %>%
#   ggplot(aes(x = contrast, y = amplitude, color = group, group = group)) +
#   stat_summary(fun.y = "mean", geom="line") +
#   stat_summary(fun.data="mean_se", geom="pointrange")

outcomes %>%
  filter(!is.na(value) & !is.nan(value)) %>%
  filter(type=="maxamp" & evalmethod=='occipital') %>%
  # Make a ratio
  group_by(id) %>% mutate(ratio = value - value[contrast==16]) %>% ungroup() %>%
  # filter outliers
  group_by(group) %>% filter(!(abs(value - mean(value)) > 2*sd(value))) %>% ungroup() %>%
  group_by(interaction(contrast, group)) %>% filter(!(abs(ratio - mean(ratio)) > 2*sd(ratio))) %>% ungroup() %>%
  # make plot
  ggplot(aes(x = contrast, y = ratio, color = group, group = group, fill = group)) +
  facet_grid(. ~ drug) +
  # geom_violin(aes(group = interaction(contrast, group))) +
  stat_summary(fun.y = "mean", geom="line", position=position_dodge(width=1)) +
  stat_summary(fun.data="mean_se", geom="pointrange", position=position_dodge(width=1))

# outcomes %>%
#   filter(type=="avsnr" & evalmethod=='occipital' & drug=='placebo' & !is.na(value) & value > 1) %>%
#   # filter outliers
#   # group_by(contrast) %>% filter(!(abs(value - mean(value)) > 2*sd(value))) %>% ungroup() %>%
#   # make new variable
#   group_by(id) %>% mutate(ratio = value/value[contrast==16]) %>%
#   # make plot
#   ggplot(aes(x = contrast, y = value, color = group, group = group)) +
#   # stat_summary(fun.y = "mean", geom="line", position=position_dodge(width=1)) +
#   # stat_summary(fun.data="mean_se", geom="pointrange", position=position_dodge(width=1)) +
#   geom_violin(aes(x = contrast, y = value, color = group, group = group))


# data %>%
#   filter(datatype=="maxelec" & !is.nan(amplitude)) %>%
#   # filter outliers
#   # group_by(group, contrast) %>%
#   filter(!(abs(amplitude - mean(amplitude)) > 3*sd(amplitude))) %>%
#   ungroup() %>%
#   # Make ratio of lowest contrast
#   group_by(ID) %>%
#   mutate(amplitude = amplitude/amplitude[contrast==16]) %>%
#   ggplot(aes(x = contrast, y = amplitude, color = group, group = group)) +
#   stat_summary(fun.y = "mean", geom="line", position=position_dodge(width=3)) +
#   stat_summary(fun.data="mean_se", geom="pointrange", position=position_dodge(width=3))
# 
# data %>%
#   # Make ratio of lowest contrast
#   group_by(ID) %>%
#   mutate(amplitude = amplitude/amplitude[contrast==16]) %>%
#   filter(datatype=="maxelec" & !is.nan(amplitude)) %>%
#   # filter outliers
#   group_by(group, contrast) %>%
#   filter(!(abs(amplitude - mean(amplitude)) > 3*sd(amplitude))) %>%
#   # only pick highest contrast ratio right now
#   filter(contrast==100) %>%
#   ggplot(aes(x = group, y = amplitude, color = group, group = group)) +
#   geom_violin() +
#   stat_summary(fun.data="mean_se", geom="pointrange", position=position_dodge(width=3))