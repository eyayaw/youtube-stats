# most interesting video stats:
## make a plot that shows the 10 most popular videos in terms of
## views, likes, comments, and duration

lookup = data.frame(
  var = c("viewCount", "likeCount", "commentCount", "duration_minute"),
  label = c("Most viewed", "Most liked", "Most commented", "Longest (minutes)"),
  color = c("#8298f8", "#52b439", "#f68060", "#55bdb4")
)

ch_data_long = channel_data |>
  melt(measure.vars = lookup$var, value.name = "count", variable.name = "stat_name")

top_10_long = ch_data_long |>
  DT(order(-count), head(.SD, 10), stat_name) |> # keep top 10
  transform(label = paste0(
    stitle, "\n[", sprintf("https://youtu.be/%s", videoId), ": ", videoPublishedAt, "]"
  ))

top_10_long |>
  split(by = "stat_name") |>
  lapply(\(d) {
    ggplot(d, aes(count, reorder(label, count))) +
      geom_col(
        fill = lookup$color[match(d$stat_name[[1]], lookup$var)], alpha = 0.6, width = 0.5
        ) +
      geom_text(aes(label = prettyNum(count, ",")), hjust = -0.05) +
      scale_x_continuous(
        labels = scales::label_number(scale = 1 / 1000, suffix = "k"),
        expand = expansion(c(0, .15))
      ) +
      labs(
        title = lookup$label[match(d$stat_name[[1]], lookup$var)],
        x = NULL, y = NULL
      ) +
      theme_minimal() +
      theme(
        legend.position = "none",
        axis.text.y = element_text(family = "abyssinica sil"),
        plot.margin = margin(1, 1, 1, 1, unit = "mm"),
        plot.title = element_text(face = "bold", hjust = 0.5)
      )
  }) -> p


# wrap_plots(p, nrow = 2, ncol = 2, byrow = FALSE)
panel = with(p, (viewCount + likeCount) / (commentCount + duration_minute)) +
  plot_annotation(
    title = sprintf("%s's Most Popular Videos", channel_info$snippet$title),
    subtitle = sprintf("Data access date: %s", atime),
    caption = caption_text,
    theme = list(
      plot.title = element_text(face = "bold"),
      plot.subtitle = element_text(face = "italic"),
      plot.caption = element_markdown(face = "italic", lineheight = 1.2),
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      panel.background = element_rect(fill = "gray97", color = NA)
    )
  )

print(panel)

ggsave(sprintf("%s/channel-plot_%s_%s.png", ch_title, ch_title, atime),
  panel, width = fig_width, height = fig_height, dpi = 320
)
