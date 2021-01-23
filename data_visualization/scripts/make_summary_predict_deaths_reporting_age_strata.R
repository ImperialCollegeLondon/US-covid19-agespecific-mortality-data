library(data.table)

indir = "~/git/US-covid19-data-scraping" # path directory to the repository

set.seed(33121122)
run_index = round(runif(1,0, 10000))
run_tag = paste0("201023o_", run_index)

lastDate = "2020-12-10"
path.to.demographics.data = file.path(indir, "data_visualization", "data", "us_population_withnyc.rds")
path.to.jhu.data = file.path(indir, "data", "official", "jhu_death_data_padded_201207.rds")
path.to.nyc.data = file.path(indir, "data", "official", "NYC_deaths_201207.csv")
path.to.deathByAge.data = file.path(indir, "data", "processed", lastDate, "DeathsByAge_US.csv")
path.to.predict_deaths_reporting_age_strata = file.path(indir, "data_visualization", "results_predict_deaths_common_age_strata", run_tag, "table", "df_predict_reporting_age_strata.rds")

outtab.dir = file.path(indir, "data_visualization", "tables")
outfig.dir = file.path(indir, "data_visualization", "figures")

dir.create(outtab.dir, showWarnings = FALSE)
dir.create(outfig.dir, showWarnings = FALSE)

source(file.path(indir, "utils", "summary.functions.r"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-summary_functions.r"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-plot_functions.r"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-table_functions.r"))


#
# Read data
# read death by age	
deathByAge = as.data.table( read.csv( path.to.deathByAge.data ) )
set(deathByAge, NULL, 'date', deathByAge[,as.Date(date)])

# read demographics by age
pop_count = as.data.table( read_pop_count_by_age_us(path.to.demographics.data) )
setnames(pop_count, "state", "loc_label")

# read predicted death by reporting age groups 
death.predict = as.data.table( readRDS( path.to.predict_deaths_reporting_age_strata ) )
set(death.predict, NULL, 'date', death.predict[,as.Date(date)])
death.predict[, code := as.character(code)]
setnames(death.predict, 'age_cat', "age")

# find observation days
death.predict[, month := format(date, "%m")]
dates_data = unique(select(deathByAge, code, date))
dates_data[, month := format(date, "%m")]
death.predict = merge(select(death.predict, -date), dates_data, by = c("code", "month"),  allow.cartesian=TRUE)

# create loc division map
loc_div = data.table(code = c(c("CT", "ME", "MA", "NH", "RI", "VT"), c("NJ", "NY", "PA", "NYC"), c("IL", "IN", "MI", "OH", "WI"), c("IA", "KS", "MN", "MO", "NE", "ND", "SD"),
                              c("DE", "DC", "FL", "GA", "MD", "NC", "SC", "VA", "WV"), c("AL", "KY", "MS", "TN", "AR", "LA", "OK", "TX"),c("AZ", "CO", "ID", "MT", "NV", "NM", "UT", "WY"),
                              c("AK", "CA", "HI", "OR", "WA")),
                     division = c(rep("New England", 6), rep("Middle Atlantic", 4), rep("East North Central", 5), rep("West North Central", 7), 
                                  rep("South Atlantic", 9), rep("South Central", 8), rep("Mountain", 8), rep("Pacific", 5)))

#
# Find associated pop count
death_summary = find_pop_count(death.predict, pop_count)

#
# Add the US census division 
death_summary = merge(death_summary, loc_div, by = "code")

# Summary for the last month
last_month = as.Date('2020-12-01')
death_summary_last_month = subset(death_summary, date == last_month)


#
# Plot
death_summary_plot = subset(death_summary, age_index != 0) 

# crude estimate of the proportion of cases by age
p_proportion_monthly_cases = plot_crude_proportion_monthly_cases_by_age(death_summary_plot, 1)
ggsave(p_proportion_monthly_cases, file = file.path(outfig.dir, paste0("ProprotionCasesByAge_reporting_age_strata_nosmoothing", ".png")), w = 21/1.5, h=29/1.5)

p_proportion_monthly_cases = plot_crude_proportion_monthly_cases_by_age(death_summary_plot, 30)
ggsave(p_proportion_monthly_cases, file = file.path(outfig.dir, paste0("ProprotionCasesByAge_reporting_age_strata_30BRM", ".png")),w = 21/1.5, h=29/1.5)

p_proportion_monthly_cases = plot_crude_proportion_monthly_cases_by_age(death_summary_plot, 45)
ggsave(p_proportion_monthly_cases, file = file.path(outfig.dir, paste0("ProprotionCasesByAge_reporting_age_strata_45BRM", ".png")), w = 21/1.5, h=29/1.5)


# crude estimate of the proportion of cases for a specific age band

p_proportion_monthly_cases_2034 = plot_crude_proportion_monthly_cases_by_age_withCI(copy(death_summary), "20-34")
ggsave(p_proportion_monthly_cases_2034, file = file.path(outfig.dir, paste0("ProprotionCasesByAge_reporting_age_strata_2034", ".png")), w = 21/1.5, h=29/1.5)

p_proportion_monthly_cases_3549 = plot_crude_proportion_monthly_cases_by_age_withCI(copy(death_summary), "35-49")
ggsave(p_proportion_monthly_cases_3549, file = file.path(outfig.dir, paste0("ProprotionCasesByAge_reporting_age_strata_3549", ".png")),  w = 21/1.5, h=29/1.5)

p_proportion_monthly_cases_2049 = plot_crude_proportion_monthly_cases_by_age_withCI(copy(death_summary), "20-49")
ggsave(p_proportion_monthly_cases_2049, file = file.path(outfig.dir, paste0("ProprotionCasesByAge_reporting_age_strata_2049", ".png")),  w = 21/1.5, h=29/1.5)


# proportion of cum deaths by age groups over time
p_proportion_monthly_death = plot_proportion_monthly_death_by_age(death_summary_plot, 1, T)
ggsave(p_proportion_monthly_death, file = file.path(outfig.dir, paste0("PropotionMonthlyDeathsByAge_reporting_age_strata", ".png")),  w = 21/1.5, h=29/1.5)

#
# save for paper
# truncate if it does not fit to JHU
death_summary_truncated = keep_days_match_JHU(death_summary)
saveRDS(death_summary_truncated, file = "~/git/R0t/covid19AgeModel/inst/data/df_predict_reporting_age_strata_210103_cured.rds")


