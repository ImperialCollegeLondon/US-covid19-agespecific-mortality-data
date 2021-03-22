functions{
  real dirichlet_multinomial_lpmf(int[] y, int n, vector alpha) {

   real l_gamma_alpha = lgamma(sum(alpha));
   real l_fact_n = lgamma(n + 1);
   real l_famm_alpha_n = lgamma(n + sum(alpha));
   real sum_x_alpha = sum( lgamma( to_vector(y) + alpha) - (lgamma(to_vector(y) + 1) + lgamma(alpha)) );

   return l_gamma_alpha + l_fact_n - l_famm_alpha_n + sum_x_alpha;
  }
}

data{
  int<lower=0> A; // continuous age
  int<lower=0> B; // original age bands
  int<lower=0> B_non_missing; // original age bands with non missing deaths
  int<lower=0> C; // four age bands
  vector[A] age; // age continuous
  vector[A] age2; // age continuous
  int total_deaths; // total unstratified deaths from JHU
  int deaths[B_non_missing]; // cumulative deaths in age band b at time n
  int age_from_state_age_strata[B]; // age from of age band b
  int age_to_state_age_strata[B];// age to of age band b
  int age_from_ntl_age_strata[C]; // age from of age band c
  int age_to_ntl_age_strata[C]; // age to of age band c
  int<lower=0,upper=B> idx_non_missing[B_non_missing]; // indices non-missing deaths
  int<lower=0,upper=B> idx_missing[B-B_non_missing]; // indices non-missing deaths
  int range_censored[2]; // range of the censored data
}

parameters {
  real beta[4];
  real<lower=0> nu;
  real<lower=0> lambda;
}

transformed parameters {
  real<lower=0> theta = nu / (1 + nu);
  vector[A] phi = softmax( beta[1] + beta[2] * age + beta[3] * log(age) + beta[4] * age2 ); 
  vector[A] alpha = phi * lambda / nu;
  vector<lower=0>[B] alpha_reduced;
  for(b in 1:B){
    alpha_reduced[b] = sum(alpha[age_from_state_age_strata[b]:age_to_state_age_strata[b] ]);
  }
}

model {
  beta ~ normal(0,1);
  lambda ~ exponential(1.0 / sum(deaths));
  nu ~ exponential(1);
    
  {
    real lpmf = neg_binomial_lpmf(deaths | alpha_reduced[idx_non_missing] , theta );
    
    for(i in range_censored[1]:range_censored[2])
        lpmf += neg_binomial_lpmf(i| alpha_reduced[idx_missing] , theta ) ;

    target += lpmf;
  }

}


generated quantities {
  int deaths_predict[A];
  int deaths_predict_state_age_strata_non_missing[B_non_missing];
  int deaths_predict_state_age_strata[B];
  int deaths_predict_ntl_age_strata[C];
  vector<lower=0>[C] alpha_ntl_age_strata;

  for(c in 1:C){
    alpha_ntl_age_strata[c] = sum(alpha[age_from_ntl_age_strata[c]:age_to_ntl_age_strata[c]]);
  }

  deaths_predict = neg_binomial_rng(alpha, theta);
  deaths_predict_state_age_strata_non_missing = neg_binomial_rng(alpha_reduced[idx_non_missing] , theta);
  deaths_predict_state_age_strata = neg_binomial_rng(alpha_reduced  , theta);
  deaths_predict_ntl_age_strata = neg_binomial_rng(alpha_ntl_age_strata , theta);
}


