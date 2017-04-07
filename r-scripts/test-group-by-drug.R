library(ez)

outcomes %>%
  filter(!is.na(value) & !is.nan(value)) %>%
  filter(type=="maxamp" & evalmethod=='occipital', drug!='cbdv') %>%
  # Make a ratio
  group_by(id) %>% mutate(ratio = (value - value[contrast==16])*10E12) %>% ungroup() %>%
  group_by(group) %>% filter(!(ratio > quantile(ratio, probs=0.25) + 1.5*IQR(ratio))) %>% ungroup() %>%
  filter(contrast==100) %>%
  mutate(contrast = as.factor(contrast)) %>%
  ezANOVA(ratio, id, between=.(group, drug))


  # ggplot(aes(x = contrast, y = ratio, color = group, group = group, fill = group)) +
  # facet_grid(. ~ drug) + stat_summary(fun.data="mean_se", geom="pointrange", position=position_dodge(width=1))
  # geom_boxplot()
  # stat_summary(fun.data="mean_se", geom="pointrange", position=position_dodge(width=1))
  # 
  # group_by(group) %>% filter(!(abs(value - mean(value)) > 2*sd(value))) %>% ungroup() %>%
  # group_by(interaction(contrast, group)) %>% filter(!(abs(ratio - mean(ratio)) > 2*sd(ratio))) %>% ungroup() %>%
  # aov(ratio ~ drug*contrast + Error(id), data=.)
