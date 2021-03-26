library(rstan)
library(data.table)

indir = "~/git/US-covid19-agespecific-mortality-data" # path to the repo
outdir = file.path(indir, 'CDC-covid-tracker', "results")
stan_model = "210319d3"
JOBID = 782737

args_line <-  as.list(commandArgs(trailingOnly=TRUE))
if(length(args_line) > 0)
{
  stopifnot(args_line[[1]]=='-indir')
  stopifnot(args_line[[3]]=='-outdir')
  stopifnot(args_line[[5]]=='-stan_model')
  stopifnot(args_line[[7]]=='-JOBID')
  indir <- args_line[[2]]
  outdir <- args_line[[4]]
  stan_model <- args_line[[6]]
  JOBID <- args_line[[8]]
}

# set directories
run_tag = paste0(stan_model, "-", JOBID)
outdir.table = file.path(outdir, run_tag, "table")
outdir.report = file.path(indir, 'CDC-covid-tracker', 'reports')
dir.report = file.path(indir, 'CDC-covid-tracker', 'scripts', 'CDC-covid-tracker_report.Rmd')

# find states
files = list.files(path = outdir.table, pattern = 'predictive')
locs = unique(gsub("predictive_checks_table_(.+).rds", "\\1", files))

##	make report
cat(paste("\n ----------- create report ----------- \n"))


rmarkdown::render( dir.report, 
                   output_file= outdir.report, 
                   params = list(
                     stanModelFile = stan_model,
                     job_dir= file.path(outdir, run_tag),
                     states = locs,
                     JOBID= JOBID
                   ))


