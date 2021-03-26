functions {
  
	//GP covariance function
	vector gp(vector[] x, real sdgp, real lscale, vector zgp) { 
		matrix[size(x), size(x)] cov;
		cov = cov_exp_quad(x, sdgp, lscale) + diag_matrix(rep_vector(1e-10, size(x)));

		return cholesky_decompose(cov) * zgp;
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
  vector[A] age; // age continuous
  int deaths[B,W]; // cumulative deaths in age band b at time n
  int age_from_state_age_strata[B]; // age from of age band b
  int age_to_state_age_strata[B];// age to of age band b
  int min_count_censored[B,W]; // range of the censored data
  int max_count_censored[B,W]; // range of the censored data
  
  //splines
  int num_basis;
  matrix[num_basis, A] BASIS; 
}

parameters {
  row_vector[num_basis] a_raw[W]; 
  real a0; 
  real aw[W]; 
  real<lower=0> tau[W]; 
  vector<lower=0>[W] nu;
  real<lower=0> lambda[W];
  real<lower=0> sd_aw;
  

}

transformed parameters {
  vector<lower=0>[W] theta = nu ./ (1 + nu);
  matrix[A,W] phi;
  matrix[A,W] alpha;
  matrix[B,W] alpha_reduced;
  
  for(w in 1:W)
  {
    row_vector[num_basis] a; 
    a = a_raw[w]*tau[w];
    
    phi[:,w] = softmax( (a0 + aw[w])*age + to_vector(a*BASIS) ); 

    alpha[:,w] = phi[:,w] * lambda[w] / nu[w];
    
    for(b in 1:B){
      alpha_reduced[b,w] = sum(alpha[age_from_state_age_strata[b]:age_to_state_age_strata[b], w]);
    }
  }

}

model {
  nu ~ exponential(1);
  a0 ~ normal(0, 5); 
  aw ~ normal(0, sd_aw); 
  tau ~ cauchy(0, 1);
  sd_aw ~ cauchy(0, 1);

  for(w in 1:W){
    a_raw[w] ~ normal(0, 1); 
    lambda[w] ~ exponential(1.0 / sum(deaths[idx_non_missing[1:N_idx_non_missing[w],w],w]));
    
    target += neg_binomial_lpmf(deaths[idx_non_missing[1:N_idx_non_missing[w],w],w] | alpha_reduced[idx_non_missing[1:N_idx_non_missing[w],w], w] , theta[w] );
  
    if(N_idx_missing[w] > 0){
      
      for(n in 1:N_idx_missing[w])
        for(i in min_count_censored[idx_missing[n,w],w]:max_count_censored[idx_missing[n,w],w])
          target += neg_binomial_lpmf( i | alpha_reduced[idx_missing[n,w], w] , theta[w] ) ;
      }
        
          
    }

  }

generated quantities {
  real log_lik[W];
  // int deaths_predict[A,W];
  // int deaths_predict_state_age_strata_non_missing[B,W] = rep_array(0, B, W);
  int deaths_predict_state_age_strata[B,W];

  for(w in 1:W){
    log_lik[w] = neg_binomial_lpmf(deaths[idx_non_missing[1:N_idx_non_missing[w],w],w] | alpha_reduced[idx_non_missing[1:N_idx_non_missing[w],w], w] , theta[w] );
    
    if(N_idx_missing[w] > 0){
      
      for(n in 1:N_idx_missing[w])
        for(i in min_count_censored[idx_missing[n,w],w]:max_count_censored[idx_missing[n,w],w])
          log_lik[w] += neg_binomial_lpmf( i | alpha_reduced[idx_missing[n,w], w] , theta[w] ) ;
    }

    
    // deaths_predict[:,w] = neg_binomial_rng(alpha[:,w], theta[w]);
    // deaths_predict_state_age_strata_non_missing[idx_non_missing[1:N_idx_non_missing[w],w],w] = neg_binomial_rng(alpha_reduced[idx_non_missing[1:N_idx_non_missing[w],w], w], theta[w]);
    deaths_predict_state_age_strata[:,w] = neg_binomial_rng(alpha_reduced[:,w], theta[w]);
  }

}


