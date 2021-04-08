compare_CDC_JHU_error_plot = function(CDC_data, JHU_data, var.cum.deaths.CDC, outdir)
{
  # find errors 
  JHUData = select(as.data.table(JHUData), code, date, cumulative_deaths)
  CDCdata = CDC_data[, list(cumulative_deaths.CDC = sum(na.omit( get(var.cum.deaths.CDC) ))), by = c('code', 'date')]
  CDCdata = subset(CDCdata, cumulative_deaths.CDC > 0)
  tmp1 = merge(JHUData, CDCdata, by = c('code', 'date'))
  tmp1[, prop_diff := abs(cumulative_deaths - cumulative_deaths.CDC) / cumulative_deaths ]
  tmp1 = tmp1[, list(prop_diff = sum(prop_diff) / length(date)), by = c('code') ]
  
  # plot
  JHUData[, source := 'JHU']
  CDCdata[, source := 'CDC']
  setnames(CDCdata, 'cumulative_deaths.CDC', 'cumulative_deaths')
  
  tmp2 = rbind(JHUData, CDCdata)
  tmp2 = merge(tmp2, tmp1, by = 'code')
  tmp2[, code_2 := paste0(code, ', ', round(prop_diff*100, digits = 2), ' % error')]
  
  p = ggplot(tmp2, aes(x = date, y = cumulative_deaths, col = source)) + 
    geom_line() +
    facet_wrap(~code_2, nrow = length(unique(tmp1$code)), scale = 'free') + 
    theme_bw() + 
    scale_color_viridis_d(option = "B", direction = -1, end = 0.8) 
  ggsave(p, file = paste0(outdir, '-comparison_JHU_CDC.pdf'), w = 9, h = 110, limitsize = F)
}

make_adjacency_plot = function()
{
  n = 2; m = 3
  
  N = n * m
  A = matrix(nrow = N, ncol = N, 0)
  B = matrix(nrow = n, ncol = m, 1:(n*m), byrow = T)
  
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
  
  tmp = as.data.table( reshape2::melt(B) )
  tmp[, idx := paste0('(',Var1, ',', Var2,')')]
  ggplot(tmp, aes(x = Var2, y = Var1, label = idx)) +
    theme_minimal() +
    labs(y = 'rows', x = 'columns', title = 'Original matrix B') + 
    scale_y_reverse(breaks = 1:m)  +
    scale_x_continuous(breaks = 1:n) +
    geom_raster(aes(fill = value), fill = 'white') + 
    geom_rect(aes(ymin = Var1 - 0.5, ymax = Var1 + 0.5, xmin = Var2 - 0.5, xmax = Var2 + 0.5), colour = "grey50", fill = NA) +
    geom_text()  +
    theme(axis.text = element_blank(),
          plot.title = element_text(vjust = -2, hjust = 0.5), 
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank())
  ggsave(file = '~/Box\ Sync/2021/CDC/example_B.png', w = 3, h = 2)
  
  tmp1 = as.data.table( reshape2::melt(A) )
  ggplot(tmp1, aes(x = Var2, y = Var1)) + 
    geom_raster(aes(fill = as.factor(value))) + 
    scale_fill_manual(values = c('beige',"blue")) + 
    labs(x = '', y = '', fill = '', title = 'Adjacency matrix A') + 
    scale_y_reverse(expand = c(0,0), breaks = 1:(m*n), labels = sort(tmp$idx))  +
    scale_x_continuous(expand = c(0,0), breaks = 1:(m*n), labels = sort(tmp$idx))  +
    theme(plot.title = element_text( hjust = 0.5)) 
  ggsave(file = '~/Box\ Sync/2021/CDC/example_Adj.png', w = 4.5, h = 4)
  
}

plot_basis_functions = function()
{
  tmp = as.data.table( reshape2::melt(stan_data$BASIS) )
  setnames(tmp, c('Var1', 'Var2'), c('basis_idx', 'age'))
  
  ggplot(tmp, aes(x = age, y= value, col = as.factor(basis_idx))) + 
    geom_line() + 
    labs(x = 'Age', y = '', col = 'basis function index') + 
    theme_bw() +
    theme(legend.position='bottom')
  ggsave(file = '~/Box\ Sync/2021/CDC/basis_functions.png', w = 6, h = 5)
}
