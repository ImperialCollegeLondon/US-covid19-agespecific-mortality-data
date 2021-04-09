functions {
  /**
  * Return the log probability of a proper conditional autoregressive (CAR) prior 
  * with a sparse representation for the adjacency matrix
  *
  * @param phi Vector containing the parameters with a CAR prior
  * @param tau Precision parameter for the CAR prior (real)
  * @param alpha Dependence (usually spatial) parameter for the CAR prior (real)
  * @param W_sparse Sparse representation of adjacency matrix (int array)
  * @param n Length of phi (int)
  * @param W_n Number of adjacent pairs (int)
  * @param D_sparse Number of neighbors for each location (vector)
  * @param lambda Eigenvalues of D^{-1/2}*W*D^{-1/2} (vector)
  *
  * @return Log probability density of CAR prior up to additive constant
  */
  real sparse_car_lpdf(vector phi, real tau, real alpha, 
    int[,] W_sparse, vector D_sparse, vector lambda, int n, int W_n) {
      row_vector[n] phit_D; // phi' * D
      row_vector[n] phit_W; // phi' * W
      vector[n] ldet_terms;
    
      phit_D = (phi .* D_sparse)';
      phit_W = rep_row_vector(0, n);
      for (i in 1:W_n) {
        phit_W[W_sparse[i, 1]] = phit_W[W_sparse[i, 1]] + phi[W_sparse[i, 2]];
        phit_W[W_sparse[i, 2]] = phit_W[W_sparse[i, 2]] + phi[W_sparse[i, 1]];
      }
    
      for (i in 1:n) ldet_terms[i] = log1m(alpha * lambda[i]);
      return 0.5 * (n * log(tau)
                    + sum(ldet_terms)
                    - tau * (phit_D * phi - alpha * (phit_W * phi)));
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
  
  // ICAR model
  int N; // W * num_basis
  int<lower=0> N_edges;
  int<lower=1, upper=N> node1[N_edges];
  int<lower=1, upper=N> node2[N_edges];          // number of adjacent region pairs
}


parameters {
  vector[N] beta_raw; 
  real<lower = 0> tau;
  vector<lower=0>[W] nu;
  real<lower=0> lambda[W];
}

transformed parameters {
  vector<lower=0>[W] theta = nu ./ (1 + nu);
  matrix[A,W] phi;
  matrix[A,W] alpha;
  matrix[B,W] alpha_reduced;
  matrix[W,num_basis] beta = to_matrix(beta_raw, W, num_basis, 0); 

  for(w in 1:W)
  {
    
    phi[:,w] = softmax( to_vector(beta[w,:]*BASIS) ); 
    
    alpha[:,w] = phi[:,w] * lambda[w] / nu[w];
    
    for(b in 1:B){
      alpha_reduced[b,w] = sum(alpha[age_from_state_age_strata[b]:age_to_state_age_strata[b], w]);
    }
  }

}

model {
  nu ~ exponential(1);
  tau ~ gamma(2, 2);

  target += -0.5 * dot_self(beta_raw[node1] - beta_raw[node2]);
  // soft sum-to-zero constraint on phi)
  sum(beta_raw) ~ normal(0, 0.001 * N);  // equivalent to mean(phi) ~ normal(0,0.001)
  
  for(w in 1:W){

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


