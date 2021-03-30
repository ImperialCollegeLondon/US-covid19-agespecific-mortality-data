
add_splines_stan_data = function(stan_data, spline_degree = 3)
{
  
  knots = c(stan_data$age[seq(1, length(stan_data$age), 12)], max(stan_data$age))

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

find_intervals = function(knots, degree){
  
  K = length(knots)
  
  intervals = vector(mode = 'double', length = 2*degree + K)
  
  # extreme
  intervals[1:degree] = min(knots)
  intervals[(degree+K+1):(2*degree+K)] = max(knots)
  
  # support of knots
  intervals[(degree+1):(degree+K)] = knots
  
  
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
