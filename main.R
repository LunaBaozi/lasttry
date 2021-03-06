starting <- function(res,data, permute, graph){
  
  object <- lapply(res, function(x) order_res(data, x))
  
  gh <- list()
  gh$graph <- graph
  result <- mclapply(object, function(x) sourceSet(gh, x$all, x$classes, seed = 1234,
                                                   permute = permute, shrink = TRUE),mc.cores = number_cores)
  

  info_all <- lapply(result, function(x) infoSource(x, map.name.variable = nodes(gh$graph)))
  
  primaryset <- lapply(result, function(x) list(x$graph$primarySet))
  
  return(list(result = result, info_all = info_all, primary = primaryset))
  
}

right_case <- function(result,sumup,i){
  ## Checks if primary set is full
  if (all(c('A','B','C','D','E') %in% result$graph$primarySet)){
    sumup[i, 12] <- 1
  }
  
  ## Checks if primary set is correctly (A, B)
  if (all(c('A','B') %in% result$graph$primarySet) & all(c('C','D','E') %notin% result$graph$primarySet)){
    sumup[i, 6] <- 1
  }
  
  ## Checks if primary set contains other nodes than (A, B)
  if (all(c('A','B') %in% result$graph$primarySet) & any(c('C','D','E') %in% result$graph$primarySet)& !(all(c('A','B','C','D','E') %in% result$graph$primarySet))){
    sumup[i, 7] <- 1
  }
  
  
  ## Checks if there is A, not B, and others
  if (('A' %in% result$graph$primarySet & 'B' %notin% result$graph$primarySet) & any(c('C','D','E') %in% result$graph$primarySet)){
    sumup[i, 8] <- 1
  }
  
  
  ## Checks if there is not A, yes B and others
  if (('A' %notin% result$graph$primarySet & 'B' %in% result$graph$primarySet) & any(c('C','D','E') %in% result$graph$primarySet)){
    sumup[i, 9] <- 1
  }
  
  ## Checks if there is not A, nor B but others
  if (all(c('A','B') %notin% result$graph$primarySet) & any(c('C','D','E') %in% result$graph$primarySet)& !(length(result$graph$primarySet) == 1)){
    sumup[i, 10] <- 1
  }
  
  
  ## Checks if primary set is empty
  if (all(c('A','B','C','D','E') %notin% result$graph$primarySet)){
    sumup[i, 11] <- 1
  }
  
  
  ## Checks if primary set is single
  if (length(result$graph$primarySet) == 1){
    sumup[i, 13] <- 1
  }
  
  sumup
}


summarize <- function(values, sumup,i){
  
  sumup <- lapply(1:length(sumup), function(x){
    sumup[[x]][i,1:5] <- values$info_all[[x]]$variable[1:5,8];
    sumup[[x]]
  })
  
  sumup <- lapply(1:length(sumup), function(x){sumup <- right_case(values$result[[x]],sumup[[x]],i);
  sumup
  })
  
  
}


main <- function(n_simulation,n,p,lambda_true, lambda_noise, number_cores,
                 equal = FALSE, permute = TRUE, which_graph = 1, mu ,mu.noise, theta, model = "nb"){
  
  transformation <- list(fit_raw, fit_sqrt, fit_log,
                         fit_negative_anscombe,
                         fit_negative_dev,
                         fit_pois_dev,
                         # fit_negative_pearson, 
                         fit_pois_pearson,
                         fit_pois_anscombe,
                         fit_negative_RQR, 
                         fit_pois_RQR)
  names <- list("RAW", "SQRT", "LOG",
                "NB_ANSC",
                "NB_DEV",
                "POIS_DEV",
                # "NB_PEAR",
                "POIS_PEAR",
                "POIS_ANSC",
                "NB_RQR",
                "POIS_RQR")
  
  sumup <- lapply(1:length(transformation), function(x) matrix(0, n_simulation, 13))
  
  sumup <- lapply(sumup, function(x) {
    colnames(x) <- c('A', 'B', 'C', 'D', 'E',
                     'AB', 'AB+', 'A+', 'B+', 'O', 'E', 'F',
                     'S');
    x
  })
  
  primary <- list()
  
  for (i in 1:n_simulation){
    
    start <- Sys.time()
    
    set.seed(i)
    
    graphs <- graph_generation(equal = equal) 
    
    if(model=="pois"){
    data <- sim_data_p(graphs$W1,graphs$W2,n=n,p=p, lambda_true,lambda_noise)
    } else {data <- sim_data_nb(graphs$W1,graphs$W2,n=n,p=p, mu ,mu.noise, theta)}
    
    res <- lapply(transformation, function(x) x(data))
    
    if(which_graph == 1){
      graph <- graphs$W1
    } else {
      graph <- graphs$W2
    }
    
    graph  <- as(graph, 'graphNEL')
    
    values <- starting(res, data, permute = permute, graph = graph)
    
    
    primary <- append(primary,list(values$primary))
    
    sumup <- summarize(values, sumup,i)
    
    finish <- Sys.time()
    
    message("Iteration number ", i)
    message("Time consumption ",finish-start)
   
  }
  
  ## Create a new matrix to store the mean values of the scores
  ## and the count of occurrences of each class
  
  newmatrix <- lapply(1:length(transformation), function(x) matrix(0, nrow=1, ncol=13))
  newmatrix <- lapply(1:length(transformation), function(x){newmatrix[[x]][,1:5] <- apply(sumup[[x]][,1:5],2,mean);newmatrix[[x]]})
  newmatrix <- lapply(1:length(transformation), function(x){newmatrix[[x]][,6:13] <- apply(sumup[[x]][,6:13],2,function(x) sum(x==1));newmatrix[[x]]})
  

  percent <- lapply(1:length(transformation), function(x) matrix(0, nrow=1, ncol=13))
  percent <- lapply(1:length(transformation), function(x){percent[[x]][1:5] <- apply(sumup[[x]][,1:5],2,mean);percent[[x]]})
  percent <- lapply(1:length(transformation), function(x){percent[[x]][6:13] <- apply(sumup[[x]][,6:13],2,function(x) sum(x==1)/n_simulation);percent[[x]]})
  

  endtable_counts <- matrix(unlist(newmatrix),nrow=length(transformation),byrow=T)
  
  endtable_percent <- matrix(unlist(percent),nrow=length(transformation),byrow=T)
  
  

  names(sumup) <- names
  
  colnames <- c('A', 'B', 'C', 'D', 'E',
                'AB', 'AB+', 'A+', 'B+', 'O', 'E', 'F',
                'S')

  

  
  colnames(endtable_counts) <- colnames(endtable_percent) <- colnames
  
  rownames(endtable_counts) <- rownames(endtable_percent) <- names
  
  return(list(table_fin = endtable_counts, perc_fin = endtable_percent, primary = primary, sum_table = sumup))
}
