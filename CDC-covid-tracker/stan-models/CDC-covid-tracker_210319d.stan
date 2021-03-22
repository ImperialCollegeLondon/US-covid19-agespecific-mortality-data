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
  int<lower=0> W; // number of weeks
  int<lower=0> A; // continuous age
  int<lower=0> B; // original age bands
  int<lower=0,upper=B> N_idx_non_missing[W];
  int<lower=0,upper=B> N_idx_missing[W];
  int<lower=-1,upper=B> idx_non_missing[B,W]; // indices non-missing deaths
  int<lower=-1,upper=B> idx_missing[B,W]; // indices missing deaths
  real age[A]; // age continuous
  int deaths[B,W]; // cumulative deaths in age band b at time n
  int age_from_state_age_strata[B]; // age from of age band b
  int age_to_state_age_strata[B];// age to of age band b
  int range_censored[2]; // range of the censored data
}


parameters {
  real<lower=0> rho[W];
  real<lower=0> sigma[W];
  vector[A] eta[W];
  vector<lower=0>[W] nu;
  real<lower=0> lambda[W];
}

transformed parameters {
  vector<lower=0>[W] theta = nu ./ (1 + nu);
  matrix[A,W] phi;
  matrix[A,W] alpha;
  matrix[B,W] alpha_reduced;
  
  for(w in 1:W)
  {
    matrix[A, A] K = cov_exp_quad(age, sigma[w], rho[w]) + diag_matrix(rep_vector(1e-10, A));
    matrix[A, A] L_K = cholesky_decompose(K);
    phi[:,w] = softmax( L_K * eta[w] );

    alpha[:,w] = phi[:,w] * lambda[w] / nu[w];
    
    for(b in 1:B){
      alpha_reduced[b,w] = sum(alpha[age_from_state_age_strata[b]:age_to_state_age_strata[b], w]);
    }
  }

}

model {
  nu ~ exponential(1);
  rho ~ inv_gamma(5, 5);
  sigma ~ std_normal();
  
  for(w in 1:W){
    eta[w] ~ std_normal();
    lambda[w] ~ exponential(1.0 / sum(deaths[idx_non_missing[1:N_idx_non_missing[w],w],w]));
    
    target += neg_binomial_lpmf(deaths[idx_non_missing[1:N_idx_non_missing[w],w],w] | alpha_reduced[idx_non_missing[1:N_idx_non_missing[w],w], w] , theta[w] );
  
    for(i in range_censored[1]:range_censored[2])
     target += neg_binomial_lpmf(i| alpha_reduced[idx_missing[1:N_idx_missing[w],w], w] , theta[w] ) ;
  }


}

generated quantities {
  int deaths_predict[A,W];
  int deaths_predict_state_age_strata_non_missing[B,W] = rep_array(0, B, W);
  int deaths_predict_state_age_strata[B,W];

  for(w in 1:W){
    deaths_predict[:,w] = neg_binomial_rng(alpha[:,w], theta[w]);
    deaths_predict_state_age_strata_non_missing[idx_non_missing[1:N_idx_non_missing[w],w],w] = neg_binomial_rng(alpha_reduced[idx_non_missing[1:N_idx_non_missing[w],w], w], theta[w]);
    deaths_predict_state_age_strata[:,w] = neg_binomial_rng(alpha_reduced[:,w], theta[w]);
  }

}



