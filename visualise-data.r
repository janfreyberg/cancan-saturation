library(ggplot2)

data %>%
  ggplot(aes(x = contrast, y = amplitude, color = group, group = group)) +
  stat_summary(fun.y = "mean", geom="line") +
  stat_summary(fun.data="mean_se", geom="pointrange")


