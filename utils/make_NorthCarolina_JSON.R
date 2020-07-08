library(rjson)

#setwd("~/git/US-covid19-data-scraping")

NorthC <- read.csv("data/req/NorthCarolina_ICL_Death_DataReq.csv", stringsAsFactors=FALSE)

data <- NorthC[2:55,1:6]
colnames(data) <- c("Date", "18-24", "25-49","50-64","65-74","75+")
data$Date <- as.Date(data$Date, format="%d%b%Y")

for(x in c("18-24", "25-49","50-64","65-74","75+"))
{
    data[[x]] <- as.integer(data[[x]])
    data[[x]] <- cumsum(data[[x]])
}

data = data.table(data)
data = data[order(Date)]
data = subset(data, Date < as.Date("2020-05-13")) %>%
    mutate("0-17" = 0)

for(i in seq_len(nrow(data)))
{
    date <- as.character(data$Date[i])
    json_data <- rjson::toJSON( data[i, -1 ] )
    if(!file.exists(date))
    {
        dir.create(date)
    }
    outfile <- file.path('data',date,'NorthCarolina.json')
    write(json_data, file=outfile)
}

