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
run_tag = paste0(stan_model, "_", JOBID)

outdir.table = file.path(outdir, run_tag, "table")

files = list.files(path = outdir.table, pattern = 'predictive')
locs = unique(gsub("predictive_checks_table_(.+).rds", "\\1", files))


# save
predictive_checks_table = vector(mode = "list", length = length(locs))  
eff_sample_size_cum = vector(mode = "list", length = length(locs))  
Rhat_cum = vector(mode = "list", length =  length(locs))  
LOO = vector(mode = "list", length = length(locs))  
WAIC = vector(mode = "list", length = length(locs))  

for(j in seq_along(locs)){
  loc = locs[j]
  
  file = file.path(outdir.table, paste0('predictive_checks_table_', loc, '.rds'))
  predictive_checks_table[[j]] = readRDS(file)[[1]]
  
  file = file.path(outdir.table, paste0("eff_sample_size_cum_", loc, ".rds"))
  eff_sample_size_cum[[j]] = unlist(readRDS(file))
  eff_sample_size_cum[[j]] = data.table(variable = names(eff_sample_size_cum[[j]]), neff = eff_sample_size_cum[[j]], Code = loc)
  
  file = file.path(outdir.table, paste0("Rhat_cum_", loc, ".rds"))
  Rhat_cum[[j]] = unlist(readRDS(file))
  Rhat_cum[[j]] = data.table(variable = names(Rhat_cum[[j]]), Rhat = Rhat_cum[[j]], Code = loc)

  file = file.path(outdir.table, paste0("WAIC_", loc, ".rds"))
  WAIC[[j]] = as.data.table(readRDS(file)[[1]])
  WAIC[[j]]$Code = loc
  
  file = file.path(outdir.table, paste0("LOO_", loc, ".rds"))
  LOO[[j]] = as.data.table( readRDS(file)[[1]])
  LOO[[j]]$Code = loc
}


predictive_checks_table = do.call("rbind", predictive_checks_table)
saveRDS(predictive_checks_table, file = file.path(outdir.table, paste0("predictive_checks.rds")))

eff_sample_size_cum = do.call("rbind", eff_sample_size_cum)
saveRDS(eff_sample_size_cum, file = file.path(outdir.table, paste0("eff_sample_size.rds")))

Rhat_cum = do.call("rbind", Rhat_cum)
saveRDS(Rhat_cum, file = file.path(outdir.table, paste0("Rhat.rds")))

WAIC = do.call("rbind", WAIC)
saveRDS(WAIC, file = file.path(outdir.table, paste0("WAIC.rds")))

LOO = do.call("rbind", LOO)
saveRDS(LOO, file = file.path(outdir.table, paste0("LOO.rds")))
