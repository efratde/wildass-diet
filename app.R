suppressPackageStartupMessages({
  library(shiny); library(bslib); library(leaflet)
  library(plotly); library(ggplot2); library(dplyr); library(DT)
})

`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0) a else b

# ---- load diet artifacts ------------------------------------------------
load_diet <- function(dir = "artifacts") {
  rc <- function(f) read.csv(file.path(dir, f), stringsAsFactors = FALSE,
                              check.names = FALSE, fileEncoding = "UTF-8-BOM")
  list(
    shannon     = rc("diet_shannon_by_sample.csv"),
    glmm        = rc("diet_glmm_coefficients.csv"),
    rfo         = rc("diet_rfo_rankings.csv"),
    traits      = rc("diet_trait_proportions_long.csv"),
    composition = rc("diet_genus_composition.csv"),
    beta        = rc("diet_beta_distance_decay.csv"))
}

d <- load_diet()

# ---- build_base_map without hillshade -----------------------------------
build_diet_map <- function(d) {
  df <- dplyr::filter(d$shannon, level == "Genus")
  pal <- leaflet::colorNumeric("viridis", df$Shannon)
  leaflet(options = leafletOptions(zoomControl = TRUE)) |>
    addProviderTiles("Esri.WorldImagery", group = "Satellite") |>
    addProviderTiles("OpenStreetMap", group = "OSM") |>
    addCircleMarkers(lng = df$lon, lat = df$lat, radius = 5, stroke = FALSE,
      fillOpacity = 0.85, color = pal(df$Shannon),
      label = paste0(df$Sample_Id, " — ", df$Sex, " ", df$Season,
                     " — Shannon ", round(df$Shannon, 2)),
      group = "Diet samples") |>
    addLegend("bottomleft", pal = pal, values = df$Shannon, title = "Shannon H'") |>
    addLayersControl(baseGroups = c("Satellite", "OSM"),
                     options = layersControlOptions(collapsed = TRUE))
}

# ---- UI -----------------------------------------------------------------
ui <- page_navbar(
  title = "Negev Wild-Ass — Diet",
  theme = bs_theme(bootswatch = "flatly", font_scale = 0.95),
  navbar_options = navbar_options(bg = "#1f3548"),
  nav_panel("About",
    div(class = "container mt-4", style = "max-width:720px",
      tags$h3("Negev Wild-Ass Diet Dashboard"),
      tags$p("The African wild ass (", tags$em("Equus africanus"), ") was reintroduced to Israel's
             Negev desert in 1982. This dashboard explores the diet of the herd,
             characterised via fecal metabarcoding (DNA extracted from dung samples)."),
      tags$p("Samples were collected across sexes and seasons in the northern Negev.
             Each sample yields a genus-level dietary profile. The analyses below
             characterise dietary diversity, genus-level composition, trait proportions,
             and spatial patterns of diet variation."),
      tags$ul(
        tags$li(tags$b("Shannon diversity"), " — alpha-diversity of the diet per sample, by sex × season"),
        tags$li(tags$b("RFO rankings"), " — relative frequency of occurrence for each dietary genus"),
        tags$li(tags$b("Genus composition"), " — mean relative abundance by sex × season"),
        tags$li(tags$b("Trait proportions"), " — plant life-form breakdown across sex × season"),
        tags$li(tags$b("Beta distance-decay"), " — dietary dissimilarity as a function of geographic distance"),
        tags$li(tags$b("Sample map"), " — sample locations coloured by Shannon diversity"),
        tags$li(tags$b("Interactive explorer"), " — genus-level pie charts, UpSet set-overlap, Euler diagrams")
      )
    )
  ),
  nav_panel("Shannon diversity",
    layout_sidebar(
      sidebar = sidebar(
        radioButtons("level", "Taxonomic level", c("Genus", "ESV"), "Genus")),
      plotlyOutput("shannon", height = 460))
  ),
  nav_panel("RFO rankings",
    layout_sidebar(
      sidebar = sidebar(
        selectInput("ss", "Sex × season",
          c("male_spring", "female_spring", "female_summer", "male_summer")),
        sliderInput("topn", "Top N genera", 5, 30, 15)),
      plotlyOutput("rfo", height = 560))
  ),
  nav_panel("Genus composition",
    layout_sidebar(
      sidebar = sidebar(
        selectInput("csex", "Sex", c("F", "M")),
        selectInput("cseason", "Season", c("Spring", "Summer"))),
      plotlyOutput("comp", height = 520))
  ),
  nav_panel("Trait proportions", plotlyOutput("traits", height = 520)),
  nav_panel("Beta distance-decay",
    layout_sidebar(
      sidebar = sidebar(
        selectInput("bcomp", "Component",
          c("beta_total", "beta_replacement", "beta_richness")),
        selectInput("bgroup", "Color by", c("sex_combo", "season_combo"))),
      plotlyOutput("beta", height = 520))
  ),
  nav_panel("Sample map", leafletOutput("map", height = 600)),
  nav_panel("Interactive explorer",
    div(class = "text-muted small p-2",
      "Genus-level pie charts (colour by 10 plant traits), set-overlap UpSet plot,
      area-proportional Euler diagram, and searchable genus table."),
    tags$iframe(src = "diet/index.html", style = "width:100%; height:1500px; border:none;")
  )
)

# ---- server -------------------------------------------------------------
server <- function(input, output, session) {

  output$shannon <- renderPlotly({
    df <- dplyr::filter(d$shannon, level == (input$level %||% "Genus")) |>
      dplyr::mutate(grp = paste(Sex, Season))
    p <- ggplot(df, aes(grp, Shannon, fill = grp)) +
      geom_boxplot(outlier.size = 0.6) +
      labs(x = NULL, y = "Shannon H'", fill = NULL,
           title = "Dietary alpha-diversity by sex × season") +
      theme_minimal(base_size = 13) +
      theme(axis.text.x = element_text(angle = 20, hjust = 1), legend.position = "none")
    ggplotly(p)
  })

  output$rfo <- renderPlotly({
    df <- d$rfo |>
      dplyr::filter(sex_season == (input$ss %||% "male_spring")) |>
      dplyr::slice_max(rfo, n = input$topn %||% 15) |>
      dplyr::mutate(lab = paste0(genus, " (", Hebrew_Genus_Names, ")"),
                    lab = factor(lab, levels = lab[order(rfo)]))
    p <- ggplot(df, aes(rfo, lab, fill = life_form)) +
      geom_col() +
      labs(x = "Relative frequency of occurrence (RFO)", y = NULL, fill = "Life form") +
      theme_minimal(base_size = 10)
    ggplotly(p)
  })

  output$comp <- renderPlotly({
    df <- d$composition |>
      dplyr::filter(Sex == (input$csex %||% "F"),
                    Season == (input$cseason %||% "Spring")) |>
      dplyr::slice_max(mean_rel_abund, n = 15)
    other <- 1 - sum(df$mean_rel_abund)
    df <- dplyr::bind_rows(df, tibble::tibble(
      Sex = df$Sex[1], Season = df$Season[1],
      Genus = "Other", mean_rel_abund = max(other, 0)))
    p <- ggplot(df, aes(reorder(Genus, mean_rel_abund), mean_rel_abund)) +
      geom_col(fill = "#2c7fb8") + coord_flip() +
      labs(x = NULL, y = "Mean relative abundance",
           title = paste("Dietary composition —", input$csex, input$cseason)) +
      theme_minimal(base_size = 10)
    ggplotly(p)
  })

  output$traits <- renderPlotly({
    p <- ggplot(d$traits, aes(Sex_X_Season, Trait, fill = Mean)) +
      geom_tile() +
      scale_fill_viridis_c(name = "Mean proportion") +
      labs(x = NULL, y = NULL, title = "Plant trait proportions in diet by sex × season") +
      theme_minimal(base_size = 9) +
      theme(axis.text.x = element_text(angle = 20, hjust = 1))
    ggplotly(p)
  })

  output$beta <- renderPlotly({
    comp <- input$bcomp %||% "beta_total"
    grp  <- input$bgroup %||% "sex_combo"
    p <- ggplot(d$beta, aes(physical_distance, .data[[comp]], color = .data[[grp]])) +
      geom_point(alpha = 0.25, size = 0.6) +
      geom_smooth(method = "lm", se = FALSE) +
      labs(x = "Physical distance (m)", y = comp, color = NULL,
           title = "Dietary beta-diversity vs geographic distance") +
      theme_minimal(base_size = 11)
    ggplotly(p)
  })

  output$map <- renderLeaflet(build_diet_map(d))
}

shinyApp(ui, server)
