sanity_check = function(data, data_processed, max_dates){
  tmp = subset(data, date == max_dates)
  tmp1 = subset(data_processed, date == max_dates)
  setnames(tmp1, "cum.deaths", "cum.deaths_est")
  
  tmp = merge(tmp, tmp1, by = c("code", "date", "age"))
  tmp[, is.equal := cum.deaths - cum.deaths_est < 1]
  if(all(tmp$is.equal)){
    print("SANITY CHECK PASSED")
  } else{
    stop()
  }
}
