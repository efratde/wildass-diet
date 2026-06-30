suppressPackageStartupMessages({ library(shiny); library(bslib); library(leaflet)
                                 library(plotly); library(ggplot2); library(dplyr) })

#' Pure: diet sample map (genus-level points) on the Phase-1 hillshade base.
build_diet_map <- function(shared, color_by = "Shannon") {
  d <- dplyr::filter(shared$diet$shannon, level == "Genus")
  pal <- leaflet::colorNumeric("viridis", d$Shannon)
  build_base_map(shared) |>
    leaflet::addCircleMarkers(lng = d$lon, lat = d$lat, radius = 4, stroke = FALSE,
      fillOpacity = 0.85, color = pal(d$Shannon),
      label = paste0(d$Sample_Id, " — ", d$Sex, " ", d$Season, " — Shannon ", round(d$Shannon, 2)),
      group = "Diet samples") |>
    leaflet::addLegend("bottomleft", pal = pal, values = d$Shannon, title = "Shannon")
}

diet_ui <- function(id) {
  ns <- NS(id)
  navset_card_tab(
    nav_panel("Shannon diversity",
      layout_sidebar(sidebar = sidebar(
        radioButtons(ns("level"), "Taxonomic level", c("Genus","ESV"), "Genus")),
        plotlyOutput(ns("shannon"), height = 460))),
    nav_panel("RFO rankings",
      layout_sidebar(sidebar = sidebar(
        selectInput(ns("ss"), "Sex × season",
          c("male_spring","female_spring","female_summer","male_summer")),
        sliderInput(ns("topn"), "Top N genera", 5, 30, 15)),
        plotlyOutput(ns("rfo"), height = 560))),
    nav_panel("Genus composition",
      layout_sidebar(sidebar = sidebar(
        selectInput(ns("csex"), "Sex", c("F","M")),
        selectInput(ns("cseason"), "Season", c("Spring","Summer"))),
        plotlyOutput(ns("comp"), height = 520))),
    nav_panel("Trait proportions", plotlyOutput(ns("traits"), height = 520)),
    nav_panel("Beta distance-decay",
      layout_sidebar(sidebar = sidebar(
        selectInput(ns("bcomp"), "Component",
          c("beta_total","beta_replacement","beta_richness")),
        selectInput(ns("bgroup"), "Color by", c("sex_combo","season_combo"))),
        plotlyOutput(ns("beta"), height = 520))),
    nav_panel("Sample map", leafletOutput(ns("map"), height = 560)),
    nav_panel("Interactive genera explorer",
      div(class = "text-muted small p-1",
        "Shrutarshi's interactive diet explorer — genus pies (colour by 10 traits), set-overlap UpSet, area-proportional Euler, and a searchable genus table. Fully offline (libraries bundled locally)."),
      tags$iframe(src = "diet/index.html", style = "width:100%; height:1500px; border:none;")))
}

diet_server <- function(id, shared) {
  moduleServer(id, function(input, output, session) {
    d <- shared$diet
    output$shannon <- renderPlotly({
      df <- dplyr::filter(d$shannon, level == (input$level %||% "Genus")) |>
        dplyr::mutate(grp = paste(Sex, Season))
      p <- ggplot(df, aes(grp, Shannon, fill = grp)) +
        geom_boxplot(outlier.size = 0.6) + labs(x = NULL, fill = NULL) +
        theme_minimal(base_size = 12) + theme(axis.text.x = element_text(angle = 20, hjust = 1))
      ggplotly(p)
    })
    output$rfo <- renderPlotly({
      df <- d$rfo |> dplyr::filter(sex_season == (input$ss %||% "male_spring")) |>
        dplyr::slice_max(rfo, n = input$topn %||% 15) |>
        dplyr::mutate(lab = paste0(genus, " (", Hebrew_Genus_Names, ")"),
                      lab = factor(lab, levels = lab[order(rfo)]))
      p <- ggplot(df, aes(rfo, lab, fill = life_form)) + geom_col() +
        labs(x = "RFO", y = NULL) + theme_minimal(base_size = 9)
      ggplotly(p)
    })
    output$comp <- renderPlotly({
      df <- d$composition |>
        dplyr::filter(Sex == (input$csex %||% "F"), Season == (input$cseason %||% "Spring")) |>
        dplyr::slice_max(mean_rel_abund, n = 15)
      other <- 1 - sum(df$mean_rel_abund)
      df <- dplyr::bind_rows(df, tibble::tibble(Sex = df$Sex[1], Season = df$Season[1],
        Genus = "Other", mean_rel_abund = max(other, 0)))
      p <- ggplot(df, aes(reorder(Genus, mean_rel_abund), mean_rel_abund)) +
        geom_col(fill = "#2c7fb8") + coord_flip() + labs(x = NULL, y = "mean relative abundance") +
        theme_minimal(base_size = 10)
      ggplotly(p)
    })
    output$traits <- renderPlotly({
      p <- ggplot(d$traits, aes(Sex_X_Season, Trait, fill = Mean)) + geom_tile() +
        scale_fill_viridis_c() + theme_minimal(base_size = 8) +
        theme(axis.text.x = element_text(angle = 20, hjust = 1))
      ggplotly(p)
    })
    output$beta <- renderPlotly({
      comp <- input$bcomp %||% "beta_total"; grp <- input$bgroup %||% "sex_combo"
      p <- ggplot(d$beta, aes(physical_distance, .data[[comp]], color = .data[[grp]])) +
        geom_point(alpha = 0.25, size = 0.6) +
        geom_smooth(method = "lm", se = FALSE) +
        labs(x = "physical distance (m)", y = comp, color = NULL) + theme_minimal(base_size = 11)
      ggplotly(p)
    })
    output$map <- renderLeaflet(build_diet_map(shared))
  })
}
