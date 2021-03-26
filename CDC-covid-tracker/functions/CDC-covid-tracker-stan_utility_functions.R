
add_splines_stan_data = function(stan_data, spline_degree = 3)
{
  
  library(splines)
  
  age = stan_data$age
  stan_data$BASIS <- t(bs(age, knots=age, degree=spline_degree, intercept = TRUE)) # creating the B-splines
  stan_data$num_basis <- nrow(B)
  
  return(stan_data)
}

