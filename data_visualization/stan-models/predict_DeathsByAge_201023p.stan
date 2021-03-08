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
  int<lower=0> C; // four age bands
  int<lower=0> D; // reporting age bands
  vector[A] age; // age continuous
  vector[A] age2; // age continuous
  int deaths[B]; // cumulative deaths in age band b at time n
  int age_from_state_age_strata[B]; // age from of age band b
  int age_to_state_age_strata[B];// age to of age band b
  int age_from_ntl_age_strata[C]; // age from of age band c
  int age_to_ntl_age_strata[C]; // age to of age band c
  int age_from_reporting_age_strata[D]; // age from of age band d
  int age_to_reporting_age_strata[D]; // age to of age band d
}

parameters {
  real beta[4];
  real<lower=0> v_inflation;
}

transformed parameters {
  simplex[A] phi_mean = softmax( beta[1] + beta[2] * age + beta[3] * log(age) + beta[4] * age2 ); 
  real<lower=0> kappa = (sum(deaths) - v_inflation - 1)/v_inflation;
  vector[A] alpha = kappa * phi_mean;
  vector[B] alpha_reduced;
  for(b in 1:B){
    alpha_reduced[b] = sum(alpha[age_from_state_age_strata[b]:age_to_state_age_strata[b]]);
  }
}
model {
  beta ~ normal(0,1);
  v_inflation ~ exponential(1);
  target += dirichlet_multinomial_lpmf(deaths | sum(deaths), alpha_reduced);
}

generated quantities {
  int deaths_predict[A];
  int deaths_predict_ntl_age_strata[C];
  int deaths_predict_reporting_age_strata[D];
  simplex[A] pi_predict;
  simplex[C] pi_predict_ntl_age_strata;
  simplex[D] pi_predict_reporting_age_strata;
      
  pi_predict = dirichlet_rng(alpha);
  for(c in 1:C){
    pi_predict_ntl_age_strata[c] = sum(pi_predict[age_from_ntl_age_strata[c]:age_to_ntl_age_strata[c]]);
  }
  for(d in 1:D){
    pi_predict_reporting_age_strata[d] = sum(pi_predict[age_from_reporting_age_strata[d]:age_to_reporting_age_strata[d]]);
  }
  
  deaths_predict = multinomial_rng(pi_predict, sum(deaths));
  deaths_predict_ntl_age_strata = multinomial_rng(pi_predict_ntl_age_strata, sum(deaths));
  deaths_predict_reporting_age_strata = multinomial_rng(pi_predict_reporting_age_strata, sum(deaths));
}

