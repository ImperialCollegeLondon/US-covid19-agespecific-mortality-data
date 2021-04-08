
prepare_stan_data = function(deathByAge, loc_name){
  
  tmp = subset(deathByAge, loc_label == loc_name)
  tmp = tmp[order(date, age_from)]
  Code <<- unique(tmp$code)
  stopifnot(all(tmp$age_from <= tmp$age_to))
  
  # create map of original age groups 
  df_state_age_strata <<- unique(select(tmp, age_from, age_to, age))
  df_state_age_strata[, age_index := 1:nrow(df_state_age_strata)]
  df_state_age_strata[, age_from_index := which(df_age_continuous$age_from == age_from), by = "age"]
  df_state_age_strata[, age_to_index := which(df_age_continuous$age_to == age_to), by = "age"]
  
  # number of age groups 
  B = nrow(df_state_age_strata)
  
  # select number of weeks: at least one positive deaths
  tmp1 = tmp[, list(n_deaths = sum(na.omit(COVID.19.Deaths))), by = 'date']
  dates = subset(tmp1, n_deaths >0)$date
  tmp = subset(tmp, date %in% dates)
  tmp <<- tmp
  
  # map week index
  W = length(unique(tmp$date))
  df_week <<- data.table(week_index = 1:W, date = unique(tmp$date))
  
  # create map of original age groups without NA 
  N_idx_non_missing = vector(mode = 'integer', length = W)
  N_idx_missing = vector(mode = 'integer', length = W)
  idx_non_missing = matrix(nrow = B, ncol = W, 0)
  idx_missing = matrix(nrow = B, ncol = W, 0)
  min_count_censored = matrix(nrow = B, ncol = W, -1)
  max_count_censored = matrix(nrow = B, ncol = W, -1)
  deaths = matrix(nrow = B, ncol = W, 0)
  
  
  for(w in 1:W){
    
    Week = sort(unique(tmp$date))[w]
    
    tmp1 = subset(tmp, date == Week & !is.na( COVID.19.Deaths ))
    df_non_missing = unique(select(tmp1, age_from, age_to, age))
    
    tmp1 = subset(tmp, date == Week & is.na( COVID.19.Deaths ))
    df_missing = unique(select(tmp1, age_from, age_to, age, min_COVID.19.Deaths, max_COVID.19.Deaths))
    
    # number of non missing and missing age category 
    N_idx_non_missing[w] = nrow(df_non_missing)
    N_idx_missing[w] = nrow(df_missing)
    
    # index missing and non missing
    .idx_non_missing = which(df_state_age_strata$age %in% df_non_missing$age)
    .idx_missing = which(df_state_age_strata$age %in% df_missing$age)
    idx_non_missing[,w] = c(.idx_non_missing, rep(-1, B - length(.idx_non_missing)))
    idx_missing[,w] = c(.idx_missing, rep(-1, B - length(.idx_missing)))
    
    # min and max of missing data
    min_count_censored[.idx_missing,w] = df_missing$min_COVID.19.Deaths
    max_count_censored[.idx_missing,w] = df_missing$max_COVID.19.Deaths
    
    # deaths
    tmp1 = copy(tmp)
    tmp1[is.na(COVID.19.Deaths), COVID.19.Deaths := -1]
    deaths = reshape2::dcast(tmp1, age ~ date, value.var = 'COVID.19.Deaths')[,-1]
  }
  
  # create stan data list
  stan_data <- list()
  
  # age bands
  stan_data = c(stan_data, 
                list(W = W,
                     A = nrow(df_age_continuous),
                     age = df_age_continuous$age,
                     age2 = (df_age_continuous$age)^2,
                     B = B, 
                     age_from_state_age_strata = df_state_age_strata$age_from_index,
                     age_to_state_age_strata = df_state_age_strata$age_to_index,
                     N_idx_non_missing = N_idx_non_missing,
                     N_idx_missing = N_idx_missing,
                     idx_non_missing = idx_non_missing,
                     idx_missing = idx_missing,
                     min_count_censored = min_count_censored,
                     max_count_censored = max_count_censored,
                     deaths = deaths
                ))
  
  # stan_data$age = stan_data$age / sd(stan_data$age)
  # stan_data$age2 = stan_data$age2 / sd(stan_data$age2)
  
  return(stan_data)
}


add_splines_stan_data = function(stan_data, spline_degree = 3, n_knots = 8)
{
  
  knots = stan_data$age[seq(1, length(stan_data$age), length.out = n_knots)]

  stan_data$num_basis = length(knots) + spline_degree - 1

  stan_data$BASIS = bsplines(stan_data$age, knots, spline_degree)
  
  stopifnot(all( apply(stan_data$BASIS, 1, sum) > 0  ))
  # B <- t(splines::bs(age, knots=age, degree=spline_degree, intercept = T)) 
  return(stan_data)
}


bspline = function(x, k, degree, intervals){
  
  if(degree == 1){
    return(x >= intervals[k] & x < intervals[k+1])
  }
  
  w1 = 0; w2 = 0
  
  if(intervals[k] != intervals[k+degree-1])
    w1 = (x - intervals[k]) / (intervals[k+degree-1] - intervals[k])
  if(intervals[k+1] != intervals[k+degree])
    w2 = 1 - (x - intervals[k+1]) / (intervals[k+degree] - intervals[k+1])
  
  spline = w1 * bspline(x, k, degree - 1, intervals) +
    w2 * bspline(x, k+1, degree - 1, intervals)
  
  return(spline)
}

find_intervals = function(knots, degree, repeating = T){
  
  K = length(knots)
  
  intervals = vector(mode = 'double', length = 2*degree + K)
  
  # support of knots
  intervals[(degree+1):(degree+K)] = knots
  
  # extreme
  if(repeating)
  {
    intervals[1:degree] = min(knots)
    intervals[(degree+K+1):(2*degree+K)] = max(knots)
  } else {
    gamma = 0.1
    intervals[1:degree] = min(knots) - gamma*degree:1
    intervals[(degree+K+1):(2*degree+K)] = max(knots) + gamma*1:degree
  }

  return(intervals)
}

bsplines = function(data, knots, degree)
{
  K = length(knots)
  num_basis = K + degree - 1
  
  intervals = find_intervals(knots, degree)
  
  m = matrix(nrow = num_basis, ncol = length(data), 0)
  
  for(k in 1:num_basis)
  {
    m[k,] = bspline(data, k, degree + 1, intervals) 
  }
  
  m[num_basis,length(data)] = 1
  
  return(m)
}


add_adjacency_matrix_stan_data = function(stan_data){
  
  n = stan_data$W; m = stan_data$num_basis
  N = n * m
  A = matrix(nrow = N, ncol = N, 0)
  
  for(i in 1:n){
    
    for(j in 1:m){
      
      #cat('\n Processing ', i, j)
      idx_row = m*(i-1) + j
      
      if(i - 1 > 0){
        idx_col = m*(i-2) + j
        A[idx_row,idx_col] = 1 
      }
      
      if(i + 1 <= n){
        idx_col = m*i + j
        A[idx_row,idx_col] = 1 
      }
      
      if(j - 1 > 0){
        idx_col = m*(i-1) + j - 1
        A[idx_row,idx_col] = 1 
      }
      
      if(j + 1 <= m){
        idx_col = m*(i-1) + j +1
        A[idx_row,idx_col] = 1 
      }
      
    }
  }
  
  stan_data$N = N
  stan_data$Adj = A
  stan_data$Adj_n = sum(A) / 2
  
  return(stan_data)
}
