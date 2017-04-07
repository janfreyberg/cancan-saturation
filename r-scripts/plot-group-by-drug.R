library(ggplot2)

outcomes %>%
  filter(!is.na(value) & !is.nan(value)) %>%
  filter(type=="maxamp" & evalmethod=='occipital', drug!='cbdv') %>%
  # Make a ratio
  group_by(id) %>% mutate(ratio = (value - value[contrast==16])*10E12) %>% ungroup() %>%
  group_by(group) %>% filter(!(ratio > quantile(ratio, probs=0.25) + 1.5*IQR(ratio))) %>% ungroup() %>%
  filter(contrast==100) %>%
  # make plot
  ggplot(aes(x = contrast, y = ratio, color = group, group = group, fill = group)) +
  facet_grid(. ~ drug) +
  # geom_boxplot()
  # stat_summary(fun.y = "mean", geom="line", position=position_dodge(width=1))
  stat_summary(fun.data="mean_se", geom="pointrange", position=position_dodge(width=1))
