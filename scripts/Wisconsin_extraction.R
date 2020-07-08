cat("\n### Running Wisconsin ###\n")

# read csv
file = './data/Wisconsin.csv'
df = read.csv(file)

# select columns and create new column names
col = c()
newcol = c()
for (start_age in seq(0,80,by=10)){
  col_name = paste('DTHS',start_age, start_age+9, sep = '_')
  newcol_name = paste(start_age, '-', start_age+9, ' years', sep = '')
  col = c(col, col_name)
  newcol = c(newcol, newcol_name)
}
col = c('LoadDttm',col, 'DTHS_90')
newcol = c('Date', newcol, '90+ years')

df = df[df$GEOID == 55,col]
df[is.na(df)] = 0
colnames(df) = newcol

# deal with dates
df$Date <- as.Date(as.character(df$Date))
date <- format(df$Date[nrow(df)], "%Y-%m-%d")

if(!file.exists(file.path('./data',date,'wisconsin.csv'))){
  outfile <- file.path('./data',date,'wisconsin.csv')
  write.csv(df, file=outfile)
  cat('\n------ Processed Wisconsin', date, '------\n')
}else{
  cat('Report for Wisconsin', date, 'is already exist')
}


