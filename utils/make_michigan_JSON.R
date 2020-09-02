library(readr)
library(rjson)

#setwd("~/git/US-covid19-data-scraping")

# Requested data sent by Michigan DoH 
michigan_weekly <- read_csv("data/req/michigan weekly.csv")

# select columns of data that we are interested and rename the columns 
df <- michigan_weekly[2:15,1:10]
newcol <- c("Date","0-19 years", "20-29 years",
                  "30-39 years","40-49 years","50-59 years","60-69 years",
                  "70-79 years","80+ years","unknown")
colnames(df) <- newcol
df$Date <- as.Date(df$Date)
newcol <- newcol[!grepl('Date',newcol)]

for(x in newcol)
{
    df[[x]] <- cumsum(df[[x]])
}

df <- subset(df, Date<"2020-04-30")
colnames(df)[!grepl("Date|unknown", colnames(df))] = gsub("(.+) years", "\\1",colnames(df)[!grepl("Date|unknown", colnames(df))])

# convert to json format and save for every week of data
for (i in seq_len(nrow(df)))
{
    date <- as.character(df$Date[i])
    json_df <- rjson::toJSON(df[i,-1])
    if(!file.exists(file.path("data",date)))
    {
        dir.create(file.path("data",date))
    }
    outfile <- file.path('data',date,'michigan.json')
    write(json_df, file=outfile)
}

