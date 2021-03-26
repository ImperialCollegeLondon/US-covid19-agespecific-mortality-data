#!/bin/sh
#PBS -l walltime=30:59:00
#PBS -l select=1:ncpus=50:ompthreads=1:mem=100gb
#PBS -j oe
#PBS -q pqcovid19c
module load anaconda3/personal

CWD="~/git/US-covid19-agespecific-mortality-data/CDC-covid-tracker/results/"
INDIR="~/git/US-covid19-agespecific-mortality-data/"
STAN_MODEL="210319d"
JOBID=$$

echo {1..50} | tr ' ' '\n' | xargs -P 50 -n 1 -I {} Rscript ~/git/US-covid19-agespecific-mortality-data/CDC-covid-tracker/scripts/CDC-covid-tracker_run_stan_hpc.R -indir $INDIR -outdir $CWD -location.index {} -stan_model $STAN_MODEL -JOBID $JOBID

echo {1..50} | tr ' ' '\n' | xargs -P 50 -n 1 -I {} Rscript ~/git/US-covid19-agespecific-mortality-data/CDC-covid-tracker/scripts/CDC-covid-tracker_postprocessing.R -indir $INDIR -outdir $CWD -location.index {} -stan_model $STAN_MODEL -JOBID $JOBID

