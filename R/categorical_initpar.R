#'Initializing score object
#'
#'This function returns an object of class scoreparameters containing the data and parameters needed for calculation of the BDe/BGe score, or a user defined score.
#' @param data the data matrix with n columns (the number of variables) and a number of rows equal to the number of observations
#' @param scoretype the score to be used to assess the DAG structure:
#'  "bge" for Gaussian data, "bde" for binary data,
#'  "bdecat" for categorical data,
#'  "usr" for a user defined score; when "usr" score is chosen, one must define a function (which evaluates the log score of a node given its parents) in the following format: usrDAGcorescore(j,parentnodes,n,param), where 'j' is node to be scores, 'parentnodes' are the parents of this node, 'n' number of nodes in the netwrok and 'param' is an object of class 'scoreparameters'
#' @param bgepar a list which contains parameters for BGe score:
#' \itemize{
#' \item am (optional) a positive numerical value, 1 by default
#' \item aw (optional) a positive numerical value should be more than \code{n+1}, \code{n+am+1} by default
#' }
#' @param bdepar a list which contains parameters for BDe score for binary data:
#' \itemize{
#' \item chi (optional) a positive number of prior pseudo counts used by the BDe score, 0.5 by default
#' \item edgepf (optional) a positive numerical value providing the edge penalization factor to be combined with the BDe score, 2 by default
#' }
#' @param bdecatpar a list which contains parameters for BDe score for categorical data:
#' \itemize{
#' \item chi (optional) a positive number of prior pseudo counts used by the BDe score, 0.5 by default
#' \item edgepf (optional) a positive numerical value providing the edge penalization factor to be combined with the BDe score, 2 by default
#' }
#' @param dbnpar which type of score to use for the slices
#' \itemize{
#' \item samestruct logical, when TRUE the structure of the first time slice is assumed to be the same as internal structure of all other time slices
#' \item slices integer representing the number of time slices in a DBN
#' \item b the number of static variables; all static variables have to be in the first b columns of the data;  for DBNs static variables have the same meaning as bgnodes for usual Bayesian networks; for DBNs parameters parameter \code{bgnodes} is ignored
#' }
#' @param usrpar a list which contains parameters for the user defined score
#' \itemize{
#' \item pctesttype (optional) conditional independence test ("bde","bge","bdecat")
#' }
#'@param DBN logical, when TRUE the score is initialized for a dynamic Baysian network; FALSE by default
#'@param weightvector (optional) a numerical vector of positive values representing the weight of each observation; should be NULL(default) for non-weighted data
#'@param bgnodes (optional) a numerical vector which contains numbers of columns in the data defining background nodes, background nodes are nodes which have no parents but can be parents of other nodes in the network; in case of DBNs bgnodes represent static variables and defined via element b of the parameters dbnpar
#'@param edgepmat (optional) a matrix of positive numerical values providing the per edge penalization factor to be added to the score, NULL by default
#'@param nodeslabels (optional) a vector of characters which denote the names of nodes in the Bayesian network; by default column names of the data will be taken
#'@return an object of class \code{scoreparameters}, which includes all necessary information for calculating the BDe/BGe score
#'@examples
#' myDAG<-pcalg::randomDAG(20, prob=0.15, lB = 0.4, uB = 2)
#' myData<-pcalg::rmvDAG(200, myDAG)
#' myScore<-scoreparameters("bge", myData)
#'@export
#'
#' @importFrom stats cov cov.wt
# a constructor function for the "scoreparameters" class
scoreparameters <- function(scoretype=c("bge","bde","bdecat","usr"), data,
                          bgepar=list(am=1, aw=NULL),
                          bdepar=list(chi=0.5, edgepf=2),
                          bdecatpar=list(chi=0.5, edgepf=2, bdecatCvec=NULL),
                          dbnpar=list(samestruct=TRUE, slices=2, b=0),
                          usrpar=list(pctesttype=c("bge","bde","bdecat")),
                          DBN=FALSE,
                          weightvector=NULL,
                          bgnodes=NULL,
                          edgepmat=NULL, nodeslabels=NULL) {

  if(DBN) {
    if(is.null(dbnpar$b)) bgnodes<-NULL else if(dbnpar$b>0) bgnodes<-c(1:dbnpar$b) else bgnodes<-NULL
  }

  # make sure it is in the right format
  data <- as.data.frame(data)

  bgn<-length(bgnodes)

  if(DBN) n<-(ncol(data)-bgn)/dbnpar$slices+bgn else n<-ncol(data)

  nsmall<-n-bgn #number of nodes in the network excluding background nodes
  if (!(scoretype%in%c("bge", "bde", "bdecat","usr"))) { #add mixed later
    stop("Scoretype should be bge (for continuous data), bde (for binary data) bdecat (for categorical data) or usr (for user defined)")
  }

  if(!DBN) {
   if (anyNA(data)) {
    stop("Dataset contains missing data")
   }
  if (ncol(data)!=nsmall+bgn) {
    stop("n and the number of columns in the data do not match")
  }
  } else {
    if(is.null(dbnpar$stationary)) dbnpar$stationary<-TRUE
    if(dbnpar$stationary) {
    if (ncol(data)!=nsmall*dbnpar$slices+bgn) {
      stop("n, bgn and the number of columns in the data do not match")
    }
    }
  }

  if (!is.null(weightvector)) {
    if (length(weightvector)!=nrow(data)) {
      stop("Length of the weightvector does not match the number of rows (observations) in data")
    }
  }

  if (scoretype=="bde") {
    if (!all(sapply(data,function(x)x%in%c(0,1,NA)))) {
      stop("Dataset contains non-binary values")
    }
  }

  if (scoretype=="bdecat") { # convert factors to levels
    indx <- sapply(data, is.factor)
    data[indx] <- lapply(data[indx], function(x) as.numeric(x)-1)

    if (is.null(bdecatpar$bdecatCvec)) {
      if (!all(unlist(lapply(data, function(x) setequal(unique(x),c(0:max(x))))))) {
        stop("Some variable levels are not present in the data")
      }
    }
  }

  if (is.null(nodeslabels)) {
    if(!DBN){
    if(all(is.character(colnames(data)))){
      nodeslabels<-colnames(data)
    } else {
      nodeslabels<-sapply(c(1:n), function(x)paste("v",x,sep=""))
    }
    } else {
      if(dbnpar$stationary) {
      if(all(is.character(colnames(data)))){
        nodeslabels<-colnames(data)
      } else {
        if(!is.null(bgnodes)) {
          staticnames<-sapply(c(1:bgn), function(x)paste("s",x,sep=""))
          dynamicnames<-rep(sapply(c(1:nsmall), function(x)paste("v",x,sep="")),dbnpar$slices)
          for(i in 2:dbnpar$slices) {
            dynamicnames[1:nsmall+(i-1)*nsmall]<-paste(dynamicnames[1:nsmall+(i-1)*nsmall],".",i,sep="")
          }
          nodeslabels<-c(staticnames,dynamicnames)
        } else {
        nodeslabels<-rep(sapply(c(1:n), function(x)paste("v",x,sep="")),dbnpar$slices)
        for(i in 2:dbnpar$slices) {
          nodeslabels[1:nsmall+(i-1)*nsmall]<-paste(nodeslabels[1:nsmall+(i-1)*nsmall],".",i,sep="")
        }
        }
      }
      }
    }
  }
  MDAG<-FALSE
  multwv<-NULL
  colnames(data)<-nodeslabels

  initparam<-list()
  initparam$labels<-nodeslabels
  initparam$type<-scoretype
  initparam$DBN<-DBN
  initparam$MDAG<-MDAG
  initparam$weightvector<-weightvector
  initparam$data<-data

  if(DBN) {
    initparam$bgnodes<-c(1:n+nsmall)
    if(bgn>0) {
      initparam$static<-c(1:bgn)
    }
    initparam$mainnodes<-c(1:nsmall+bgn)
  } else {
    initparam$bgnodes<-bgnodes
    initparam$static<-bgnodes
    if(!is.null(bgnodes)) {
    initparam$mainnodes<-c(1:n)[-bgnodes]
    } else initparam$mainnodes<-c(1:n)
  }
  initparam$bgn<-bgn
  initparam$n<-n
  initparam$nsmall<-nsmall
  if(DBN) {
    if(dbnpar$stationary) {
    initparam$labels.short<-initparam$labels[1:(n+nsmall)]
    } else {
      nodeslabels<-colnames(data[[1]])
      initparam$labels<-nodeslabels
      initparam$labels.short<-colnames(data[[1]])
  }} else {
    initparam$labels.short<-initparam$labels
  }


  if (is.null(edgepmat)) {
    initparam$logedgepmat <- NULL
  } else {
    if(all(edgepmat>0)) {
    initparam$logedgepmat <- log(edgepmat)
    } else stop("all entries of edgepmat matrix must be bigger than 0! 1 corresponds to no penalization")
  }
  if(DBN) {

    if(!dbnpar$stationary) {

      initparam$split=FALSE

      initparam$stationary<-FALSE
      initparam$slices<-2

      initparam$intstr<-list()
      initparam$trans<-list()

      initparam$usrinitstr<-list()
      initparam$usrintstr<-list()
      initparam$usrtrans<-list()

      initparam$usrinitstr$rows<-c(1:n)
      initparam$usrinitstr$cols<-c(1:nsmall+bgn)
      if(bgn==0) initparam$usrintstr$rows<-c(1:nsmall+n) else initparam$usrintstr$rows<-c(1:bgn,1:nsmall+n)
      initparam$usrintstr$cols<-c(1:nsmall+n)
      initparam$usrtrans$rows<-c(1:nsmall+bgn)
      initparam$usrtrans$cols<-c(1:nsmall+n)

      if(bgn!=0) {
        initparam$intstr$rows<-c(1:bgn+nsmall,1:nsmall)
      } else {
        initparam$intstr$rows<-c(1:nsmall)
      }
      initparam$intstr$cols<-c(1:nsmall)
      initparam$trans$rows<-c(1:nsmall+n)
      initparam$trans$cols<-c(1:nsmall)

      initparam$paramsets<-list()

      for(i in 1:length(data)) {
        datalocal<-data[[i]]
        datalocal <- datalocal[,c(1:nsmall+nsmall+bgn,1:bgn,1:nsmall+bgn)]
        initparam$paramsets[[i]]<-scoreparameters(scoretype=scoretype,
                                                 datalocal, weightvector=NULL,
                                                 bgnodes=initparam$bgnodes,
                                                 bgepar=bgepar, bdepar=bdepar, bdecatpar=bdecatpar, dbnpar=dbnpar,
                                                 edgepmat=edgepmat, DBN=FALSE)
      }


    } else {

    initparam$stationary<-TRUE
    initparam$slices<-dbnpar$slices

    if (!is.null(dbnpar$samestruct)) {
      initparam$split<-!dbnpar$samestruct
    } else {
      initparam$split<-FALSE
    }

    # other slices we layer the data,
    datalocal <- data[,1:(2*nsmall+bgn)]
    collabels<-colnames(datalocal)
      if (bgn>0){
        bgdata<-data[,bgnodes]
         if(dbnpar$slices > 2){ # layer on later time slices
            for(jj in 1:(dbnpar$slices-2)){
              datatobind<-cbind(bgdata,data[,nsmall*jj+1:(2*nsmall)+bgn])
              colnames(datatobind)<-collabels
              datalocal <- rbind(datalocal,datatobind)
            }
         }
        newbgnodes<-bgnodes+nsmall #since we change data columns bgnodes change indices
    } else {
      if(dbnpar$slices > 2){ # layer on later time slices
        for(jj in 1:(dbnpar$slices-2)){
          datatobind<-data[,n*jj+1:(2*n)]
          colnames(datatobind)<-collabels
          datalocal <- rbind(datalocal,datatobind)
        }
      }
      newbgnodes<-bgnodes
    }

    # and have earlier times on the right hand side! (bgnodes if present go between two time slices)
    if(bgn>0) {
    datalocal <- datalocal[,c(1:nsmall+nsmall+bgn,1:bgn,1:nsmall+bgn)]
    } else {
      datalocal <- datalocal[,c(1:n+n,1:n)]
    }

    #define column and row ranges in a compact adjacency matrix

    initparam$intstr<-list()
    initparam$trans<-list()

    initparam$usrinitstr<-list()
    initparam$usrintstr<-list()
    initparam$usrtrans<-list()

    initparam$usrinitstr$rows<-c(1:n)
    initparam$usrinitstr$cols<-c(1:nsmall+bgn)
    if(bgn==0) initparam$usrintstr$rows<-c(1:nsmall+n) else initparam$usrintstr$rows<-c(1:bgn,1:nsmall+n)
    initparam$usrintstr$cols<-c(1:nsmall+n)
    initparam$usrtrans$rows<-c(1:nsmall+bgn)
    initparam$usrtrans$cols<-c(1:nsmall+n)


    if(bgn!=0) {
    initparam$intstr$rows<-c(1:bgn+nsmall,1:nsmall)
    } else {
    initparam$intstr$rows<-c(1:nsmall)
    }
    initparam$intstr$cols<-c(1:nsmall)
    initparam$trans$rows<-c(1:nsmall+n)
    initparam$trans$cols<-c(1:nsmall)


    if(!is.null(weightvector)) {
      weightvector.other<-rep(weightvector,dbnpar$slices-1)
    } else {
      weightvector.other<-weightvector
    }

    #removing rows containing missing data
    lNA<-0
    if (anyNA(datalocal)) {
      NArows<-which(apply(datalocal,1,anyNA)==TRUE)
      lNA<-length(NArows)
      datalocal<-datalocal[-NArows,]
      if(!is.null(weightvector)) {
        weightvector.other<-weightvector.other[-NArows]
      }
    }

    initparam$otherslices <- scoreparameters(scoretype=scoretype,
                                             datalocal, weightvector=weightvector.other,
                                             bgnodes=initparam$bgnodes,
                                             bgepar=bgepar, bdepar=bdepar, bdecatpar=bdecatpar, dbnpar=dbnpar,
                                             edgepmat=edgepmat, DBN=FALSE)

    # first slice we just take the first block
    bdecatpar$edgepf <- 1 # we don't want any additional edge penalisation
    bdepar$edgepf <- 1
    if(bgn==0) {
      datalocal <- data[,c(1:nsmall)]
    } else {
      datalocal <- data[,c(1:nsmall+bgn,1:bgn)] #move static variables to the right hand side
    }

    #removing rows containing missing data
    if (anyNA(datalocal)) {
      NArows<-which(apply(datalocal,1,anyNA)==TRUE)
      lNA<-lNA+length(NArows)
      datalocal<-datalocal[-NArows,]
      if(!is.null(weightvector)) {
        weightvector<-weightvector[-NArows]
      }
    }
    if(lNA>0) {
      cat(paste(lNA, "rows were removed due to missing data"),"\n")
    }

    initparam$firstslice <- scoreparameters(scoretype=scoretype,
                                            datalocal, weightvector=weightvector, bgnodes=newbgnodes,
                                            bgepar=bgepar, bdepar=bdepar, bdecatpar=bdecatpar, dbnpar=dbnpar,
                                            edgepmat=edgepmat, DBN=FALSE)
  }
  } else if(scoretype=="bge") {
    if (is.null(weightvector)) {
      N<-nrow(data)
      covmat<-cov(data)*(N-1)
      means<-colMeans(data)
    } else {
      N<-sum(weightvector)
      forcov<-cov.wt(data,wt=weightvector,cor=TRUE,method="ML")
      covmat<-forcov$cov*N
      means<-forcov$center
    }
    if (is.null(bgepar$aw)) {
      bgepar$aw<-n+bgepar$am+1
    }

    initparam$am <- bgepar$am # store parameters
    initparam$aw <- bgepar$aw

    initparam$N <- N # store effective sample size
    #initparam$covmat <- (N-1)*covmat
    initparam$means <- means # store means

    mu0<-numeric(n)
    T0scale <- bgepar$am*(bgepar$aw-n-1)/(bgepar$am+1) # This follows from equations (19) and (20) of [GH2002]
    T0<-diag(T0scale,n,n)
    initparam$TN <- T0 + covmat + ((bgepar$am*N)/(bgepar$am+N))* (mu0 - means)%*%t(mu0 - means)
    initparam$awpN<-bgepar$aw+N
    constscorefact<- -(N/2)*log(pi) + (1/2)*log(bgepar$am/(bgepar$am+N))

    initparam$muN <- (N*means + bgepar$am*mu0)/(N + bgepar$am) # posterior mean mean
    initparam$SigmaN <- initparam$TN/(initparam$awpN-n-1) # posterior mode covariance matrix

    initparam$scoreconstvec<-numeric(n)
    for (j in (1:n)) {# j represents the number of parents plus 1
      awp<-bgepar$aw-n+j
      initparam$scoreconstvec[j]<-constscorefact - lgamma(awp/2) + lgamma((awp+N)/2) + ((awp+j-1)/2)*log(T0scale)
    }
  } else if (scoretype=="bde") {
    if(is.null(bdepar$chi)) {bdepar$chi<-0.5}
    if(is.null(bdepar$edgepf)) {bdepar$edgepf<- 2}
    if (is.null(weightvector)) {
      initparam$N<-nrow(data)
      initparam$d1<-data
      initparam$d0<-(1-data)
    } else {
      initparam$N<-sum(weightvector)
      initparam$d1<-data*weightvector
      initparam$d0<-(1-data)*weightvector
    }
    maxparents<-n-1
    initparam$scoreconstvec<-rep(0,maxparents+1)
    initparam$chi<-bdepar$chi #1
    initparam$pf<-bdepar$edgepf
    for(i in 0:maxparents){ # constant part of the score depending only on the hyperparameters
      noparams<-2^i
      initparam$scoreconstvec[i+1]<-noparams*lgamma(initparam$chi/noparams)-2*noparams*lgamma(initparam$chi/(2*noparams))-i*log(initparam$pf) #
    }
  } else if (scoretype=="bdecat") {
    bdecatpar <- bdepar
    if(is.null(bdecatpar$chi)) {bdecatpar$chi<-0.5}
    if(is.null(bdecatpar$edgepf)) {bdecatpar$edgepf<-2}
    maxparents<-n-1
    initparam$chi<-bdecatpar$chi
    initparam$pf<-bdecatpar$edgepf
    initparam$scoreconstvec <- -c(0:maxparents)*log(initparam$pf) # just edge penalisation here
    if (is.null(bdecatpar$bdecatCvec)) {
      initparam$Cvec <- apply(initparam$data,2,max)+1 # number of levels of each variable
    } else {
      initparam$Cvec <- bdecatpar$bdecatCvec
    }

  # } else if (scoretype=="usr"){
  #   if(is.null(usrpar$pctesttype)){usrpar$pctesttype <- "usr"}
  #   initparam$pctesttype <- usrpar$pctesttype
  #   initparam <- usrscoreparameters(initparam, usrpar)
  }
  attr(initparam, "class") <- "scoreparameters"
  return(initparam)

  # #this if for future models
  # if(!is.null(multwv)) {
  #   initparam$paramsets<-list()
  #   for(i in 1:length(multwv)) {
  #    # initparam$paramsets[[i]]<-scoreparameters(scoretype=scoretype,
  #   #                                            data, weightvector=multwv[[i]],
  #   #                                            bgnodes=initparam$bgnodes,
  #   #                                            bgepar=bgepar, bdepar=bdepar, bdecatpar=bdecatpar, dbnpar=dbnpar,
  #   #                                            edgepmat=edgepmat, DBN=FALSE,MDAG=FALSE,multwv=NULL)
  #   }
  # }

}

#Add later
#@param mixedpar a list which contains parameters for the BGe and BDe score for mixed data:
#\itemize{
#\item nbin a positive integer number of binary nodes in the network (the binary nodes are always assumed in first nbin columns of the data)
# }
# else if (scoretype=="mixed") {
#   initparam$nbin<-mixedpar$nbin
#   initparam$binpar<-scoreparameters("bde", data[,1:mixedpar$nbin], bdepar=bdepar,
#                                     nodeslabels=nodeslabels[1:mixedpar$nbin],weightvector=weightvector)
#   initparam$gausspar<-scoreparameters("bge",data,bgnodes = c(1:mixedpar$nbin), bgepar=bgepar,
#                                       nodeslabels = nodeslabels, weightvector=weightvector)
# }
