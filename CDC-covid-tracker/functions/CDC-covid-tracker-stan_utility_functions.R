
add_splines_stan_data = function(stan_data, spline_degree = 3)
{
  
  stan_data$num_basis = length(stan_data$age) + spline_degree - 1

  m = bsplines(stan_data$age, spline_degree)
  # the two extremes sum to 0
  m = m[-c(1, nrow(m)),]
  stan_data$BASIS = m
  
  # B <- t(splines::bs(age, knots=age, degree=spline_degree, intercept = T)) 
  return(stan_data)
}


bsplines = function(knots, degree)
{
  K = length(knots)
  num_basis = K + degree + 1
  
  intervals = find_intervals(knots, degree)
  
  m = matrix(nrow = num_basis, ncol = K, 0)
  
  for(x in 1:K)
  {
    for(k in 1:num_basis)
    {
      m[k,x] = abs( bspline(knots[x], k, degree, intervals) )
    }
  }
  
  return(m)
}

bspline = function(x, k, degree, intervals){
  
  if(degree == 0 ){
    if(x >= intervals[k] & x < intervals[k+1]){
      return(1) 
    } else{
      return(0)
    }
  }
  
  spline = (x - intervals[k]) / (intervals[k+degree] - intervals[k]) * bspline(x, k, degree - 1, intervals)
  spline = spline - (intervals[k + degree + 1] - x) / (intervals[k + degree + 1] - intervals[k + 1]) * bspline(x, k+1, degree - 1, intervals)

  # spline = find_weight(x, k, degree-1,intervals) * bspline(x, k, degree - 1, intervals)
  # spline = spline + (1 - find_weight(x, k+1, degree-1,intervals) ) * bspline(x, k+1, degree - 1, intervals)

  return(spline)
}

find_weight = function(x, k, degree,intervals){
  return( (x - intervals[k]) / (intervals[k + degree] - intervals[k]) )
}

find_intervals = function(knots, degree){
  
  gamma = 0.01
  K = length(knots)
  
  intervals = vector(mode = 'double', length = 2*degree + K + 2)
  
  # support of knots
  intervals[(degree+2):(degree+K+1)] = knots
  
  # extremes
  intervals[1:(degree+1)] = min(knots) - gamma*1:(degree+1)
  intervals[(degree+K+2):(2*degree+K+2)] =  max(knots) + gamma*1:(degree+1)
  
  return(intervals)
}

bsplines = function(knots, degree)
{
  K = length(knots)
  num_basis = K + degree + 1
  
  intervals = find_intervals(knots, degree)
  
  m = matrix(nrow = num_basis, ncol = K, 0)
  
  for(x in 1:K)
  {
    for(k in 1:num_basis)
    {
      m[k,x] = abs( bspline(knots[x], k, degree, intervals) )
    }
  }
  
  return(m)
}

