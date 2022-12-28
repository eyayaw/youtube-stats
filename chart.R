# most interesting video stats:
## make a plot that shows the 10 most popular videos in terms of
## views, likes, comments, and duration

lookup = data.frame(
  var = c("viewCount", "likeCount", "commentCount", "duration_minute"),
  label = c("Most viewed", "Most liked", "Most commented", "Longest (minutes)")
  #label = c("Views", "Likes", "Comments", "Duration (minutes)")
)

ch_data_long = channel_data |>
  melt(
    measure.vars = lookup$var,
    id.vars = c("videoId", "videoPublishedAt", "stitle", "duration"),
    value.name = "count", variable.name = "stat_name"
  ) |>
  DT(order(-count), head(.SD, 10), stat_name) |>
  transform(label = paste0(stitle, "\n[", sprintf("https://youtu.be/%s", videoId), ": ", videoPublishedAt, "]"))

ch_data_long |>
  split(by = "stat_name") |>
  lapply(\(d) {
    ggplot(d, aes(count, reorder(label, count), fill = stat_name)) +
      geom_col(fill = "#f68060", alpha = 0.6, width = 0.5) +
      geom_text(aes(label = prettyNum(count, ",")), hjust = -0.05) +
      scale_x_continuous(
        labels = scales::label_number(scale = 1 / 1000, suffix = "k"),
        expand = expansion(c(0, .125))
      ) +
      labs(
        title = lookup$label[match(d$stat_name[[1]], lookup$var)],
        x = NULL, y = NULL
      ) +
      theme_minimal() +
      theme(
        legend.position = "none",
        axis.text.y = element_text(family = "abyssinica sil"),
        plot.margin = margin(),
        plot.title = element_text(face = "bold", hjust = 0.5)
      )
  }) -> p


panel =
  # wrap_plots(p, nrow = 2, ncol = 2, byrow = FALSE)
  with(p, (viewCount + likeCount) / (commentCount + duration_minute)) +
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
