# Visualization of age-specific COVID-19 mortality data in the United-States

## Overview
The data from different age stratifications were used to predict death counts in the common age bands across all locations using a latent Dirichlet-multinomial model.

The model and associated predictions have been used in:

- M Monod, A Blenkinsop, X Xi et al. [Report 32: Age groups that sustain resurging COVID-19 epidemics in the United States Imperial College London](https://www.imperial.ac.uk/mrc-global-infectious-disease-analysis/covid-19/covid-19-reports/) (version 2, 07-01-2021), doi: https://doi.org/10.25561/82551.


## Usage
### Dependencies
- R version >= 4.0.2
- R libraries:
```
rstan
data.table
ggplot2 
scales
gridExtra
tidyverse
reshape2
```

### Reproduce results of version 1.1.0
First, generate the predictions posterior samples run,
```bash
$ cd data_visualization/
$ Rscript scripts_v110/predict_deaths_common_age_run_stan.R
```
Second, produce the convergence diagnostics and summary tables of the posterior samples with,
```bash
$ Rscript scripts_v110/predict_deaths_common_age_make_table.R
$ Rscript scripts_v110/predict_deaths_common_age_make_figure.R
```
Finally, produce the postprocessing figures and tables with,
```bash
$ Rscript scripts_v110/make_summary_predict_deaths_ntl_age_strata.r
$ Rscript scripts_v110/make_summary_predict_deaths_reporting_age_strata.r
$ Rscript scripts_v110/make_summary_predict_deaths_state_age_strata.r
```
The figures are stored under 
```bash
figures/
```
and the tables under
```bash
tables/
```

### Note: Predictions used in version 1.1.0 of https://github.com/ImperialCollegeLondon/covid19model/covid19AgeModel
Table https://github.com/ImperialCollegeLondon/covid19model/covid19AgeModel/inst/data-v110/df_predict_reporting_age_strata_201126_cured.rds is generated in 
```bash
$ Rscript scripts_v110/make_summary_predict_deaths_reporting_age_strata.r
```

## Results
### Mortality Rate By Age
![ ](figures/MortalityRateByAge.png)

### Mortality Rate By Age - USA map
![ ](figures/heat_map_usa_MortalityRateByAge.png)

### Proportion of individuals aged 20-49 among COVID-19 cases 
<img src="figures/ProprotionCasesByAge_reporting_age_strata_2049.png" width="700">


### Proportion of COVID-19 attributable deaths By Age
<img src="figures/PropotionMonthlyDeathsByAge_reporting_age_strata.png" width="700">

