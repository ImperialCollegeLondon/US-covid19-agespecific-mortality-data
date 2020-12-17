library(data.table)

indir = "~/git/US-covid19-data-scraping" # path directory to the repository

last_Date = "2020-11-27"
path.to.jhu.data = file.path(indir, "data", "official", "jhu_death_data_padded_201207.rds")
path.to.nyc.data = file.path(indir, "data", "official", "NYC_deaths_201207.csv")
path.to.deathByAge.data = file.path(indir, "data", "processed", last_Date, "DeathsByAge_US.csv")
path.to.demographics.data = file.path(indir, "data_visualization", "data", "us_population_withnyc.rds")
outtab.dir = file.path(indir, "data_visualization", "tables")
outfig.dir = file.path(indir, "data_visualization", "figures")

source(file.path(indir, "utils", "summary.functions.R"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-summary_functions.r"))
source(file.path(indir, "data_visualization", "functions", "data-visualization-plot_functions.r"))

#
# Read data
# read demographics by age to get location label
pop_count = as.data.table( read_pop_count_by_age_us(path.to.demographics.data) )
setnames(pop_count, "state", "loc_label")
pop_info = unique(select(pop_count, code, loc_label))

# read death by age	
deathByAge = as.data.table( read.csv( path.to.deathByAge.data ) )
set(deathByAge, NULL, 'date', deathByAge[,as.Date(date)])
deathByAge = merge(deathByAge, pop_info, by = c("code"))

# read overall death from JHU and NYC
death_data = as.data.table( readRDS( path.to.jhu.data ) )
tmp = as.data.table( read.csv( path.to.nyc.data ) )
setnames(tmp, c("date_of_interest","DEATH_COUNT"), c("date", "daily_deaths"))
tmp[, date := as.Date(date, format = "%m/%d/%Y")]
tmp[, code := "NYC"]
death_data = rbind(select(death_data, code, date, daily_deaths), select(tmp, code, date, daily_deaths))
death_data = merge(death_data, pop_info, by = c("code"))

#
# Make summaries
data_summary = summarise_DeathByAge(deathByAge, pop_info)

#
# Make reporting statistics on the data format
data_statistics = find_reporting_data_format_statistics(deathByAge, last_Date, death_data)


#
# Make reporting statistics on the data
last_month = as.Date("2020-11-01")
tmp = subset(deathByAge, date == last_month)
CumDeath_statistics = find_reporting_mortality_counts_statistics(copy(tmp), copy(pop_count))
CumDeath_statistics = c(list(format(last_month, "%B %d, %Y")), CumDeath_statistics)

#
# Plot
# observation days
tmp = subset(data_summary, n_days != "-")
tmp[, n_days := as.numeric(n_days)]
p_heat_map_usa_n_days = plot_heat_map_usa(tmp, "n_days", "Number of \nobservationed days")

# cumulative deaths over time
selected_states = c ("CA", "ID", "FL", "UT")
p_cum_deaths_by_age = plot_cum_deaths_by_age(deathByAge, selected_states)

# comparison to JHU data and NYC data
p_comparison_overall = plot_death_by_age_vs_deaths_overall(deathByAge, death_data)
p_comparison_overall_difference = plot_death_by_age_vs_deaths_overall_difference(deathByAge, death_data)


#
# Save
saveRDS(list(data_summary, data_statistics, CumDeath_statistics), file = file.path(outtab.dir, paste0("DeathsByAge_summary.rds")), version = 2)
ggsave(p_heat_map_usa_n_days, file = file.path(outfig.dir, paste0("heat_map_usa_", "NumberObservedDays", ".png")), w = 9, h = 5)
ggsave(p_cum_deaths_by_age, file = file.path(outfig.dir, paste0("CumDeathsByAgeData.png")), w = 11, h = 8)
ggsave(p_comparison_overall, file = file.path(outfig.dir, paste0("CumDeathsData_ComparisonUnstratified.png")), w = 8, h = 10)
ggsave(p_comparison_overall_difference, file = file.path(outfig.dir, paste0("CumDeathsData_ComparisonUnstratified_diff.png")), w = 8, h = 10)

