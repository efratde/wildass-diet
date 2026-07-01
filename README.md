# Negev Wild-Ass Diet Dashboard

> **Portfolio demonstration — synthetic data.** Every figure, table, and map point in this dashboard — dietary diversity, RFO rankings, genus composition, trait proportions, distance-decay, and the plotted sample coordinates — is invented to mirror the real metabarcoding pipeline's schema and represents no real animal, measurement, sequencing read, or sampling location. This is a portfolio piece, not a real dataset.


An interactive Shiny dashboard reconstructing the diet of the reintroduced wild-ass herd of Israel's Negev desert from **fecal DNA metabarcoding** (DNA extracted from dung). Across ~187 samples spanning both sexes and the spring/summer seasons, each dung sample yields a genus-level dietary profile; the app characterises dietary alpha-diversity, genus-level composition, plant life-form / trait use, the relative frequency of occurrence of each forage genus, and the spatial turnover of diet across the landscape. Built with `bslib` (navbar UI), `plotly` (interactive charts), and `leaflet` (sample map), it turns a multi-analysis metabarcoding pipeline into a browsable, reproducible exhibit.

## Live demo

**https://n248wr-efrat-dener.shinyapps.io/wildass-diet/**

![wildass-diet](https://raw.githubusercontent.com/efratde/efratde/main/assets/screenshots/wildass-diet.png)

## Features

The dashboard is organised as a top navbar with the following panels:

- **About** — study context and a guide to every analysis.
- **Shannon diversity** — dietary alpha-diversity (Shannon H') per sample, summarised by sex x season, with a Genus / ESV (exact sequence variant) taxonomic-level toggle.
- **RFO rankings** — relative frequency of occurrence (RFO) of each dietary genus, filterable by sex x season and top-N, coloured by plant life form (Hebrew and Latin genus names shown).
- **Genus composition** — mean relative abundance of the top forage genera for a chosen sex and season, with a pooled "Other" remainder.
- **Trait proportions** — heatmap of plant trait / life-form proportions in the diet across sex x season.
- **Beta distance-decay** — dietary dissimilarity (total, replacement, and richness-difference components) as a function of geographic distance between samples, coloured by sex or season pairing.
- **Sample map** — Leaflet map of sample locations on satellite / OSM basemaps, coloured by Shannon diversity.
- **Interactive explorer** — an embedded offline explorer: genus-level pie charts (colour by 10 plant traits), a set-overlap UpSet plot, an area-proportional Euler diagram, and a searchable genus table.

## Run locally

Requires R (>= 4.1) and the packages used by the app:

```r
install.packages(c("shiny", "bslib", "leaflet", "plotly",
                   "ggplot2", "dplyr", "DT", "tibble"))
```

Clone the repo and launch from the app directory:

```r
# from the repository root
shiny::runApp(".")
```

The app reads pre-computed summary tables from `artifacts/` at startup. If you have deploy credentials, it can be published with:

```r
rsconnect::deployApp(appName = "wildass-diet")
```

## Methods

Diet was reconstructed by **fecal DNA metabarcoding**: plant DNA recovered from dung samples is sequenced and assigned to exact sequence variants (ESVs) and then to plant genera. From those assignments the app derives:

- **Alpha-diversity** — Shannon H' per sample at Genus and ESV level, modelled by sex x season with generalized linear mixed models (GLMMs; marginal and conditional R² reported in the bundled coefficient table).
- **RFO** — relative frequency of occurrence of each genus within a sex x season group.
- **Composition** — mean relative read abundance per genus.
- **Trait proportions** — diet aggregated over plant functional traits / life forms.
- **Beta-diversity distance-decay** — pairwise dietary dissimilarity partitioned into total, replacement (turnover) and richness-difference components, regressed against physical distance between sample locations.

## Data

To keep this a fully public, self-contained demo, the repository ships **synthetic data — invented values, not the real study measurements**. The bundled `artifacts/` tables (Shannon diversity, RFO rankings, genus composition, trait proportions, beta distance-decay, and GLMM coefficients) are generated with the **same schema and column names** as the real metabarcoding outputs, so the app runs live as a complete simulation of the analysis. Importantly, the **sample locations drawn on the map are synthetic coordinates** — placeholder points, *not* the true sampling sites of this protected species. No real sequencing reads, measurements, GPS localities, or research findings are exposed; the genuine dataset is kept private and is not part of this repository.

## Citation & contact

Dr. Efrat Dener, Ben-Gurion University of the Negev.
ORCID: [0000-0001-5504-0358](https://orcid.org/0000-0001-5504-0358)

If you use this dashboard or its summaries, please cite the author and link to the live application above.
