## /*****************************************************************************
##	* SIENA: Simulation Investigation for Empirical Network Analysis
##	*
##	* Web: http://www.stats.ox.ac.uk/~snijders/siena
##	*
##	* File: sienaGOF.r
##	*
##	* Description: This file contains the code to assess goodness of fit:
##	* the main function sienaGOF, the plot method,
##	* and auxiliary statistics and extractor functions.
##	* Written by Josh Lospinoso, modifications by Tom Snijders.
##	*
##	****************************************************************************/

##@sienaGOF siena07 Does test for goodness of fit
sienaGOF <- function(
		sienaFitObject,	auxiliaryFunction,
		period=NULL, verbose=FALSE, join=TRUE, twoTailed=FALSE,
		cluster=NULL, robust=FALSE,
		groupName="Data1", varName, ...)
	{
	## require(MASS)
	## require(Matrix)
	##	Check input
	if (sienaFitObject$maxlike)
	{
		stop(
	"sienaGOF can only operate on results from Method of Moments estimation.")
	}
	if (! sienaFitObject$returnDeps)
	{
		stop("You must instruct siena07 to return the simulated networks")
	}
	if (!is.null(sienaFitObject$sf2.byIterations))
	{
		if (!sienaFitObject$sf2.byIterations)
    	{
        	stop("sienaGOF needs sf2 by iterations")
    	}
	}
	iterations <- length(sienaFitObject$sims)
	if (iterations < 1)
	{
		stop("You need at least one iteration.")
	}
	if (missing(varName))
	{
		stop("You need to supply the parameter <<varName>>.")
	}
	if (missing(auxiliaryFunction))
	{
		stop("You need to supply the parameter <<auxiliaryFunction>>.")
	}
	groups <- length(sienaFitObject$f$groupNames)
	if (verbose)
	{
		if (groups <= 1)
		{
			cat("Detected", iterations, "iterations and", groups, "group.\n")
		}
		else
		{
			cat("Detected", iterations, "iterations and", groups, "groups.\n")
		}
	}

	if (is.null(period) )
	{
		period <- 1:(attr(sienaFitObject$f[[1]]$depvars[[1]], "netdims")[3] - 1)
	}

	 obsStatsByPeriod <- lapply(period, function (j) {
						matrix(
						auxiliaryFunction(NULL,
								sienaFitObject$f,
				sienaFitObject$sims, j, groupName, varName, ...)
						, nrow=1)
				})
	if (join)
	{
		obsStats <- Reduce("+", obsStatsByPeriod)
		obsStats <- list(Joint=obsStats)
	}
	else
	{
		obsStats <- obsStatsByPeriod
		names(obsStats) <- paste("Period", period)
	}
	plotKey <- names(auxiliaryFunction(NULL, sienaFitObject$f,
				sienaFitObject$sims, 1, groupName, varName, ...))
	class(obsStats) <- "observedAuxiliaryStatistics"
	attr(obsStats,"auxiliaryStatisticName") <-
			deparse(substitute(auxiliaryFunction))
	attr(obsStats,"joint") <- join
	
	##	Calculate the simulated auxiliary statistics
	if (verbose)
	{
		if (length(period) <= 1)
		{
			cat("Calculating auxiliary statistics for period", period, ".\n")
		}
		else
		{
			cat("Calculating auxiliary statistics for periods", period, ".\n")
		}
	}
	if (!is.null(cluster)) 
	{
		ttcSimulation <- system.time(simStatsByPeriod <- 
			lapply(period, function (j) {
					simStatsByPeriod <- parSapply(cluster, 1:iterations,
						function (i){auxiliaryFunction(i, sienaFitObject$f,
										sienaFitObject$sims, j, groupName, varName, ...)})
			simStatsByPeriod <- matrix(simStatsByPeriod, ncol=iterations)
			dimnames(simStatsByPeriod)[[2]] <-	1:iterations
			t(simStatsByPeriod)
			}))
	}
	else
	{
		ttcSimulation <- system.time( simStatsByPeriod <- lapply(period,
					function (j) {
						if (verbose)
						{
							cat("  Period ", j, "\n")
							flush.console()
						}
						simStatsByPeriod <- sapply(1:iterations, function (i)
						{
							if (verbose && (i %% 100 == 0) )
								{
								cat("  > Completed ", i,
										" calculations\n")
								flush.console()
								}
								auxiliaryFunction(i,
										sienaFitObject$f,
										sienaFitObject$sims, j, groupName, varName, ...)
						})
					simStatsByPeriod <-
							matrix(simStatsByPeriod, ncol=iterations)
					dimnames(simStatsByPeriod)[[2]] <-	1:iterations
					t(simStatsByPeriod)
					})
	  )
	}
	
	## Aggregate by period if necessary to produce simStats
	if (join)
	{
		simStats <- Reduce("+", simStatsByPeriod)
		simStats <- list(Joint=simStats)
	}
	else
	{
		simStats <- simStatsByPeriod
		names(simStats) <- paste("Period",period)
	}
	class(simStats) <- "simulatedAuxiliaryStatistics"
	attr(simStats,"auxiliaryStatisticName") <-
			deparse(substitute(auxiliaryFunction))
	attr(simStats,"joint") <- join
	attr(simStats,"time") <- ttcSimulation

	applyTest <-  function (observed, simulated)
	{
		if (class(simulated) != "matrix")
		{
			stop("Invalid input.")
		}
		if (class(observed) != "matrix")
		{
			observed <- matrix(observed,nrow=1)
		}
		if (class(observed) != "matrix")
		{
			stop("Observation must be a matrix.")
		}
		if (ncol(observed) != ncol(simulated))
		{
			stop("Dimensionality of function parameters do not match.")
		}
		observations <- nrow(observed)
	#	simulations<-nrow(simulated)
		variates<-ncol(simulated)
		if (robust) {
			a <- cov.rob(simulated)$cov
		}
		else
		{
			a <- cov(simulated)
		}
		ainv <- ginv(a)
		arank <- rankMatrix(a)
		expectation <- colMeans(simulated);
		centeredSimulations <- scale(simulated, scale=FALSE)
		if (variates==1)
		{
			centeredSimulations <- t(centeredSimulations)
		}
		mhd <- function(x)
		{
			x %*% ainv %*% x
		}
		simTestStat <- apply(centeredSimulations, 1, mhd)
		centeredObservations <- observed - expectation
		obsTestStat <- apply(centeredObservations, 1, mhd)
		if (twoTailed)
		{
			p <- sapply(1:observations, function (i)
						1 - abs(1 - 2 * sum(obsTestStat[i] <=
						simTestStat)/length(simTestStat)) )
		}
		else
		{
			p <- sapply(1:observations, function (i)
				sum(obsTestStat[i] <= simTestStat) /length(simTestStat))
		}

		ret <- list( p = p,
				SimulatedTestStat=simTestStat,
				ObservedTestStat=obsTestStat,
				TwoTailed=twoTailed,
				Simulations=simulated,
				Observations=observed,
				InvCovSimStats=a,
				Rank=arank)
		class(ret) <- "sienaGofTest"
		attr(ret,"sienaFitName") <- deparse(substitute(sienaFitObject))
		attr(ret,"auxiliaryStatisticName") <-
				attr(obsStats,"auxiliaryStatisticName")
		attr(ret, "key") <- plotKey
		ret
	}

	res <- lapply(1:length(simStats),
					function (i) {
				 applyTest(obsStats[[i]], simStats[[i]]) })
	mhdTemplate <- rep(0, sum(sienaFitObject$test))
	names(mhdTemplate) <- rep(0, sum(sienaFitObject$test))

	JoinedOneStepMHD_old <- mhdTemplate
	OneStepMHD_old <- lapply(period, function(i) (mhdTemplate))
	JoinedOneStepMHD <- mhdTemplate
	OneStepMHD <- lapply(period, function(i) (mhdTemplate))

	obsMhd <- NULL

	ExpStat <-
		lapply(period, function(i) {colMeans(simStatsByPeriod[[i]])})
	simStatsByPeriod_tilde <-
		lapply(period, function(i) {
			t(apply(simStatsByPeriod[[i]],1, function(x){x - ExpStat[[i]]}))})

	OneStepSpecs <- matrix(0, ncol=sum(sienaFitObject$test),
			nrow=length(sienaFitObject$theta))
	if (robust) {
		covInvByPeriod <- lapply(period, function(i) ginv(
							cov.rob(simStatsByPeriod[[i]]) ))
	}
	else
	{
		covInvByPeriod <- lapply(period, function(i) ginv(
							cov(simStatsByPeriod[[i]]) ))
	}

	obsMhd <- sapply(period, function (i) {
				 (obsStatsByPeriod[[i]] - ExpStat[[i]])	 %*%
						covInvByPeriod[[i]] %*%
						t(obsStatsByPeriod[[i]] - ExpStat[[i]] )
			})

	if (sum(sienaFitObject$test) > 0) {
		effectsObject <- sienaFitObject$requestedEffects
		nSims <- sienaFitObject$Phase3nits
		for (i in period) {
			names(OneStepMHD_old[[i]]) <-
					effectsObject$effectName[sienaFitObject$test]
			names(OneStepMHD[[i]]) <-
					effectsObject$effectName[sienaFitObject$test]
		}
		names(JoinedOneStepMHD_old) <-
					effectsObject$effectName[sienaFitObject$test]
		names(JoinedOneStepMHD) <-
				effectsObject$effectName[sienaFitObject$test]

		rownames(OneStepSpecs) <- effectsObject$effectName
		colnames(OneStepSpecs) <- effectsObject$effectName[sienaFitObject$test]
		counterTestEffects <- 0
		for(index in which(sienaFitObject$test)) {
			if (verbose) {
				cat("Estimating test statistic for model including ",
						effectsObject$effectName[index], "\n")
			}
			counterTestEffects <- counterTestEffects + 1
			effectsToInclude <- !sienaFitObject$test
			effectsToInclude[index] <- TRUE
			theta0 <- sienaFitObject$theta
			names(theta0) <- effectsObject$effectName
			theta0 <- theta0[effectsToInclude]
			obsSuffStats <-
					t(sienaFitObject$targets2[effectsToInclude, , drop=FALSE])
			G <- sienaFitObject$sf2[, , effectsToInclude, drop=FALSE] -
					rep(obsSuffStats, each=nSims)
			sigma <- cov(apply(G, c(1, 3), sum))
			SF <- sienaFitObject$ssc[ , , effectsToInclude, drop=FALSE]
			dimnames(SF)[[3]] <- effectsObject$effectName[effectsToInclude]
			dimnames(G) <- dimnames(SF)
			if (!(sienaFitObject$maxlike || sienaFitObject$FinDiff.method))
			{
				D <- derivativeFromScoresAndDeviations(SF, G, , , , TRUE, )
			}
			else
			{
				DF <- sienaFitObject$
						sdf2[ , , effectsToInclude, effectsToInclude,
						drop=FALSE]
				D <- t(apply(DF, c(3, 4), mean))
			}
			fra <- apply(G, 3, sum) / nSims
			doTests <- rep(FALSE, sum(effectsToInclude))
			names(doTests) <- effectsObject$effectName[effectsToInclude]
			doTests[effectsObject$effectName[index]] <- TRUE
			redundant <- rep(FALSE, length(doTests))
			mmThetaDelta <- as.numeric(ScoreTest(length(doTests), D,
							sigma, fra, doTests, redundant,
							maxlike=sienaFitObject$maxlike)$oneStep )

      # \mu'_\theta(X)
			JacobianExpStat_old <- lapply(period, function (i) {
				t(SF[,i,]) %*% simStatsByPeriod[[i]]/ nSims	 })
			JacobianExpStat <- lapply(period, function (i) {
				t(SF[,i,]) %*% simStatsByPeriod_tilde[[i]]/ nSims })

      # List structure: Period, effect index
      thetaIndices <- 1:sum(effectsToInclude)
	  # \Gamma_i(\theta)  i=period, j=parameter, k=replication
			ExpStatCovar_old <- lapply(period, function (i) {
            lapply(thetaIndices, function(j){
              Reduce("+", lapply(1:nSims,function(k){
                simStatsByPeriod[[i]][k,] %*% t(simStatsByPeriod[[i]][k,]) * SF[k,i,j]
              })) / nSims
				- JacobianExpStat[[i]][j,] %*%
			t(ExpStat[[i]]) - ExpStat[[i]] %*% t(JacobianExpStat[[i]][j,])
            })
        })
			ExpStatCovar <- lapply(period, function (i) {
				lapply(thetaIndices, function(j){
				Reduce("+", lapply(1:nSims,function(k){
			simStatsByPeriod_tilde[[i]][k,] %*%
				t(simStatsByPeriod_tilde[[i]][k,]) * SF[k,i,j] })) / nSims})})

      # \Xi_i(\theta)
			JacobianCovar_old <- lapply(period, function (i) {
				lapply(thetaIndices, function(j){
					-1 * covInvByPeriod[[i]] %*% ExpStatCovar_old[[i]][[j]] %*%
						covInvByPeriod[[i]] })
			})
      JacobianCovar <- lapply(period, function (i) {
        lapply(thetaIndices, function(j){
					-1 * covInvByPeriod[[i]] %*% ExpStatCovar[[i]][[j]] %*%
						covInvByPeriod[[i]] })
        })

			Gradient_old <- lapply(period, function(i) {
				sapply(thetaIndices, function(j){
					( obsStatsByPeriod[[i]] - ExpStat[[i]] ) %*%
						JacobianCovar_old[[i]][[j]] %*%
					t( obsStatsByPeriod[[i]] - ExpStat[[i]] )
					})
				-2 * JacobianExpStat_old[[i]] %*% covInvByPeriod[[i]] %*%
					t( obsStatsByPeriod[[i]] - ExpStat[[i]] )
				})
			Gradient <- lapply(period, function(i) {
          sapply(thetaIndices, function(j){
          ( obsStatsByPeriod[[i]] - ExpStat[[i]] ) %*%
            JacobianCovar[[i]][[j]] %*%
          t( obsStatsByPeriod[[i]] - ExpStat[[i]] )
          })
				-2 * JacobianExpStat[[i]] %*% covInvByPeriod[[i]] %*%
            t( obsStatsByPeriod[[i]] - ExpStat[[i]] )
					})

			OneStepSpecs[effectsToInclude,counterTestEffects] <-
								theta0 + mmThetaDelta

			for (i in 1:length(obsMhd)) {
				OneStepMHD_old[[i]][counterTestEffects] <-
					as.numeric(obsMhd[i] + mmThetaDelta %*% Gradient_old[[i]] )
      }
			for (i in 1:length(obsMhd)) {
				OneStepMHD[[i]][counterTestEffects] <-
					as.numeric(obsMhd[i] + mmThetaDelta %*% Gradient[[i]] )
		}
			JoinedOneStepMHD_old[counterTestEffects] <-
						Reduce("+",OneStepMHD_old)[counterTestEffects]
			JoinedOneStepMHD[counterTestEffects] <-
						Reduce("+",OneStepMHD)[counterTestEffects]
		} # end 'for index'
	}

	names(res) <- names(obsStats)
	class(res) <- "sienaGOF"
	attr(res, "scoreTest") <- (sum(sienaFitObject$test) > 0)
	attr(res, "originalMahalanobisDistances") <- obsMhd
	attr(res, "oneStepMahalanobisDistances") <- OneStepMHD
	attr(res, "joinedOneStepMahalanobisDistances") <-
			JoinedOneStepMHD
	attr(res, "oneStepMahalanobisDistances_old") <- OneStepMHD_old
	attr(res, "joinedOneStepMahalanobisDistances_old") <-
			JoinedOneStepMHD_old
	attr(res, "oneStepSpecs") <- OneStepSpecs
	attr(res,"auxiliaryStatisticName") <-
			attr(obsStats,"auxiliaryStatisticName")
	attr(res, "simTime") <- attr(simStats,"time")
	attr(res, "twoTailed") <- twoTailed
	attr(res, "joined") <- join
	res
}

##@print.sienaGOF siena07 Print method for sienaGOF
print.sienaGOF <- function (x, ...) {
	## require(Matrix)
	levls <- 1:length(x)
	pVals <- sapply(levls, function(i) x[[i]]$p)
	titleStr <- "Monte Carlo Mahalanobis distance test p-value: "

	if (! attr(x,"joined"))
	{
		cat("Siena Goodness of Fit (",
			attr(x,"auxiliaryStatisticName"),"),", length(levls)," periods\n=====\n")
		cat(" >",titleStr, "\n")
		for (i in 1:length(pVals))
		{
			cat(names(x)[i], ": ", round(pVals[i],3), "\n")
		}
		for (i in 1:length(pVals))
		{
			if (x[[i]]$Rank < dim(x[[i]]$Observations)[2])
			{
				cat(" * Note for", names(x)[i],
					": Only", x[[i]]$Rank, "statistics are",
					"necessary in the auxiliary function.\n")
			}
		}
	}
	else
	{
		cat("Siena Goodness of Fit (",
			attr(x,"auxiliaryStatisticName"),"), all periods\n=====\n")
		cat(titleStr, round(pVals[1],3), "\n")
		if (x[[1]]$Rank < dim(x[[1]]$Observations)[2])
			{
				cat("**Note: Only", x[[1]]$Rank, "statistics are",
				"necessary in the auxiliary function.\n")
			}
	}

	if ( attr(x, "twoTailed") )
	{
		cat("-----\nTwo tailed test used.")
	}
	else
	{
		cat("-----\nOne tailed test used ",
		"(i.e. estimated probability of greater distance than observation).\n")
	}
	originalMhd <- attr(x, "originalMahalanobisDistances")
	if (attr(x, "joined")) {
		cat("-----\nCalculated joint MHD = (",
				round(sum(originalMhd),2),") for current model.\n")
	}
	else
	{
		for (j in 1:length(originalMhd)) {
			cat("-----\nCalculated period ", j, " MHD = (",
					round(originalMhd[j],2),") for current model.\n")
		}
	}
	invisible(x)
}

##@summary.sienaGOF siena07 Summary method for sienaGOF
summary.sienaGOF <- function(object, ...) {
	x <- object
	print(x)
	if (attr(x, "scoreTest")) {
		oneStepSpecs <- attr(x, "oneStepSpecs")
		oneStepMhd <- attr(x, "oneStepMahalanobisDistances")
		joinedOneStepMhd <- attr(x, "joinedOneStepMahalanobisDistances")
		cat("\nOne-step estimates and predicted Mahalanobis distances")
		cat(" for modified models.\n")
		if (attr(x, "joined")) {
			for (i in 1:ncol(oneStepSpecs)) {
				a <- cbind(oneStepSpecs[,i, drop=FALSE] )
				b <- matrix( c(joinedOneStepMhd[i] ), ncol=1)
				rownames(b) <- c("MHD")
				a <- rbind(a, b)
				a <- round(a, 3)
				cat("\n**Model including", colnames(a)[1], "\n")
				colnames(a) <- "one-step"
				print(a)
			}
		}
		else
		{
			for (j in 1:length(oneStepMhd)) {
				for (i in 1:ncol(oneStepSpecs)) {
					a <- cbind( oneStepSpecs[,i, drop=FALSE] )
					b <- matrix( c(oneStepMhd[[j]][i], ncol=1) )
					rownames(b) <- c("MHD")
					a <- rbind(a, b)
					a <- round(a, 3)
					cat("\n**Model including", colnames(a)[1], "\n")
					colnames(a) <- c("one-step")
					print(a)
				}
			}
		}
		cat("\n-----")
	}
	cat("\nComputation time for auxiliary statistic calculations on simulations: ",
			attr(x, "simTime")["elapsed"] , "seconds.\n")
	invisible(x)
}

##@plot.sienaGOF siena07 Plot method for sienaGOF
plot.sienaGOF <- function (x, center=FALSE, scale=FALSE, violin=TRUE,
		key=NULL, perc=.05, period=1, ...)
{
	## require(lattice)
	args <- list(...)
	if (is.null(args$main))
	{
		main=paste("Goodness of Fit of",
				attr(x,"auxiliaryStatisticName"))
		if (!attr(x,"joined"))
		{
			main = paste(main, "Period", period)
		}
	}
	else
	{
		main=args$main
	}

	if (attr(x,"joined"))
	{
		x <- x[[1]]
	}
	else
	{
		x <- x[[period]]
	}
	sims <- x$Simulations
	obs <- x$Observations
	itns <- nrow(sims)
#	vars <- ncol(sims)
	## Need to check for useless statistics here:
	n.obs <- nrow(obs)

	screen <- sapply(1:ncol(obs),function(i){
						(sum(is.nan(rbind(sims,obs)[,i])) == 0) }) &
				(diag(var(rbind(sims,obs)))!=0)

	if (any((diag(var(rbind(sims,obs)))==0)))
	{	cat("Note: some statistics are not plotted because their variance is 0.\n")
		cat("This holds for the statistic")
		if (sum(diag(var(rbind(sims,obs)))==0) > 1){cat("s")}
		cat(": ")
		cat(paste(attr(x,"key")[which(diag(var(rbind(sims,obs)))==0)], sep=", "))
		cat(".\n")
	}

	sims <- sims[,screen, drop=FALSE]
	obs <- obs[,screen, drop=FALSE]
	obsLabels <- round(x$Observations[,screen, drop=FALSE],3)

	sims.min <- apply(sims, 2, min)
	sims.max <- apply(sims, 2, max)
	sims.min <- pmin(sims.min, obs)
	sims.max <- pmax(sims.max, obs)

	if (center)
	{
		sims.median <- apply(sims, 2, median)
		sims <- sapply(1:ncol(sims), function(i)
					(sims[,i] - sims.median[i]) )
		obs <- matrix(sapply(1:ncol(sims), function(i)
							(obs[,i] - sims.median[i])), nrow=n.obs )
		sims.min <- sims.min - sims.median
		sims.max <- sims.max - sims.median
	}
	if (scale)
	{
		sims.range <- sims.max - sims.min + 1e-6
		sims <- sapply(1:ncol(sims), function(i) sims[,i]/(sims.range[i]))
		obs <- matrix(sapply(1:ncol(sims), function(i) obs[,i]/(sims.range[i]))
				, nrow=n.obs )
		sims.min <- sims.min/sims.range
		sims.max <- sims.max/sims.range
	}

	ymin <- 1.05*min(sims.min) - 0.05*max(sims.max)
	ymax <- -0.05*min(sims.min) + 1.05*max(sims.max)

	if (is.null(args$ylab))
	{
		ylabel = "Statistic"
		if (center && scale) {
			ylabel = "Statistic (centered and scaled)"
		}
		else if (scale)
		{
			ylabel = "Statistic (scaled)"
		}
		else if (center)
		{
			ylabel = "Statistic (center)"
		}
		else
		{
			ylabel = "Statistic"
		}
	}
	else
	{
		ylabel = args$ylab
	}

	if (is.null(args$xlab))
	{
		xlabel = paste( paste("p:", round(x$p, 3),
						collapse = " "), collapse = "\n")
	}
	else
	{
		xlabel = args$xlab
	}

	xAxis <- (1:sum(screen))

	if (is.null(key))
	{
		if (is.null(attr(x, "key")))
		{
			key=xAxis
		}
		else
		{
			key <- attr(x,"key")[screen]
		}
	}
	else
	{
		key <- key[screen] ## added 1.1-244
		if (length(key) != ncol(obs))
		{
			stop("Key length does not match the number of variates.")
		}
	}

	br <- trellis.par.get("box.rectangle")
	br$col <- 1
	trellis.par.set("box.rectangle", br)
	bu <- trellis.par.get("box.umbrella")
	bu$col <- 1
	trellis.par.set("box.umbrella", bu)
	plot.symbol <- trellis.par.get("plot.symbol")
	plot.symbol$col <- "black"
	plot.symbol$pch <- 4
	plot.symbol$cex <- 1
	trellis.par.set("plot.symbol", plot.symbol)

	panelFunction <- function(..., x=x, y=y, box.ratio){
		ind.lower <- max( round(itns * perc/2), 1)
		ind.upper <- round(itns * (1-perc/2))
		yperc.lower <- sapply(1:ncol(sims), function(i)
					sort(sims[,i])[ind.lower]  )
		yperc.upper <- sapply(1:ncol(sims), function(i)
					sort(sims[,i])[ind.upper]  )
		if (violin) {
			panel.violin(x, y, box.ratio=box.ratio, col = "transparent",
					bw="nrd", ...)
		}
		panel.bwplot(x, y, box.ratio=.1, fill = "gray", ...)
		panel.xyplot(xAxis, yperc.lower, lty=3, col = "gray", lwd=3, type="l",
				...)
		panel.xyplot(xAxis, yperc.upper, lty=3, col = "gray", lwd=3, type="l",
				...)
		for(i in 1:nrow(obs))
		{
			panel.xyplot(xAxis, obs[i,],  col="red", type="l", lwd=1, ...)
			panel.xyplot(xAxis, obs[i,],  col="red", type="p", lwd=3, pch=19,
					...)
			panel.text(xAxis, obs[i,], labels=obsLabels[i,], pos=4)
		}
	}
	bwplot(as.numeric(sims)~rep(xAxis, each=itns), horizontal=FALSE,
			panel = panelFunction, xlab=xlabel, ylab=ylabel, ylim=c(ymin,ymax),
			scales=list(x=list(labels=key), y=list(draw=FALSE)),
			main=main)

}

##@descriptives.sienaGOF siena07 Gives numerical values in the plot.
descriptives.sienaGOF <- function (x, center=FALSE, scale=FALSE,
			perc=.05, key=NULL, period=1, showAll=FALSE)
{
# adapted excerpt from plot.sienaGOF
	if (attr(x,"joined"))
	{
		x <- x[[1]]
	}
	else
	{
		x <- x[[period]]
	}

	sims <- x$Simulations
	obs <- x$Observations
	itns <- nrow(sims)

	screen <- sapply(1:ncol(obs),function(i){
						(sum(is.nan(rbind(sims,obs)[,i])) == 0) })
	if (!showAll)
	{
		screen <- screen & (diag(var(rbind(sims,obs)))!=0)
	}
	sims <- sims[,screen, drop=FALSE]
	obs <- obs[,screen, drop=FALSE]
	## Need to check for useless statistics here:
	n.obs <- nrow(obs)

	if (is.null(key))
	{
		if (is.null(attr(x, "key")))
		{
			key=(1:sum(screen))
		}
		else
		{
			key <- attr(x,"key")[screen]
		}
	}
	else
	{
		if (length(key) != ncol(obs))
		{
			stop("Key length does not match the number of variates.")
		}
		key <- key[screen]
	}

	sims.themin <- apply(sims, 2, min)
	sims.themax <- apply(sims, 2, max)
	sims.mean <- apply(sims, 2, mean)
	sims.min <- pmin(sims.themin, obs)
	sims.max <- pmax(sims.themax, obs)

	if (center)
	{
		sims.median <- apply(sims, 2, median)
		sims <- sapply(1:ncol(sims), function(i)
					(sims[,i] - sims.median[i]) )
		obs <- matrix(sapply(1:ncol(sims), function(i)
							(obs[,i] - sims.median[i])), nrow=n.obs )
		sims.mean <- sims.mean - sims.median
		sims.min <- sims.min - sims.median
		sims.max <- sims.max - sims.median
	}

	if (scale)
	{
		sims.range <- sims.max - sims.min + 1e-6
		sims <- sapply(1:ncol(sims), function(i) sims[,i]/(sims.range[i]))
		obs <- matrix(sapply(1:ncol(sims), function(i) obs[,i]/(sims.range[i]))
				, nrow=n.obs )
		sims.mean <- sims.mean/sims.range
		sims.min <- sims.min/sims.range
		sims.max <- sims.max/sims.range
	}

	screen <- sapply(1:ncol(obs),function(i){
						(sum(is.nan(rbind(sims,obs)[,i])) == 0) })
	if (!showAll)
	{
		screen <- screen & (diag(var(rbind(sims,obs)))!=0)
	}
	sims <- sims[,screen, drop=FALSE]
	obs <- obs[,screen, drop=FALSE]
	sims.themin <- sims.themin[screen, drop=FALSE]
	sims.themax <- sims.themax[screen, drop=FALSE]

	ind.lower = max( round(itns * perc/2), 1)
	ind.upper = round(itns * (1-perc/2))
	ind.median = round(itns * 0.5)
	yperc.mid = sapply(1:ncol(sims), function(i)
				sort(sims[,i])[ind.median])
	yperc.lower = sapply(1:ncol(sims), function(i)
				sort(sims[,i])[ind.lower]  )
	yperc.upper = sapply(1:ncol(sims), function(i)
				sort(sims[,i])[ind.upper]  )
	violins <- matrix(NA, 7, ncol(sims))
	violins[1,] <- sims.themax
	violins[2,] <- yperc.upper
	violins[3,] <- sims.mean
	violins[4,] <- yperc.mid
	violins[5,] <- yperc.lower
	violins[6,] <- sims.themin
	violins[7,] <- obs
	rownames(violins) <- c('max', 'perc.upper', 'mean',
							'median', 'perc.lower', 'min', 'obs')
	colnames(violins) <- key
	violins
}

##@changeToStructural sienaGOF Utility to change
# values in X to structural values in S
# X must have values 0, 1.
# NA values in X will be 0 in the result.
changeToStructural <- function(X, S) {
	if (any(S >= 10, na.rm=TRUE))
		{
			S[is.na(S)] <- 0
			S0 <- Matrix(S==10)
			S1 <- Matrix(S==11)
# the 1* turns the logical into numeric
			X <- 1*((X - S0 + S1)>=1)
		}
	X[is.na(X)] <- 0
	drop0(X)
}

##@changeToNewStructural sienaGOF Utility to change
# values in X to structural values in SAfter
# for tie variables that have no structural values in SBefore.
# X must have values 0, 1.
# NA values in X or SBefore or SAfter will be 0 in the result.
changeToNewStructural <- function(X, SBefore, SAfter) {
		SB <- Matrix(SBefore>=10)
		SA <- Matrix(SAfter>=10)
		if (any(SA>SB, na.rm=TRUE))
		{
			S0 <- (SA>SB)*Matrix(SAfter==10)
			S1 <- (SA>SB)*Matrix(SAfter==11)
# the 1* turns the logical into numeric
			X <- 1*((X - S0 + S1)>=1)
		}
	X[is.na(X)] <- 0
	drop0(X)
}

##@sparseMatrixExtraction sienaGOF Extracts simulated networks
# This function returns the simulated network as a dgCMatrix;
# this is the "standard" class for sparse numeric matrices
# in the Matrix package. See the help file for "dgCMatrix-class".
# Ties for ordered pairs with a missing value for wave=period or period+1
# are zeroed;
# note that this also is done in RSiena for calculation of target statistics.
# To obtain equality between observed and simulated tie values
# in the case of structurally determined values, the following is done.
# The difficulty lies in the possibility
# that there is change in structural values.
# The reasoning is as follows:
# structural values affect the following period.
# Therefore the simulated values at the end of the period
# should be compared with an observation containing the structural values
# present at the beginning of the period.
# This implies that observations (wave=period+1) should be modified to contain
# the structural values of the preceding observation (wave=period).
# But if there are any tie variables with
# structural values for wave=period+1 and free values for wave=period,
# then there is no valid reference value for the simulations in this period,
# and the simulated tie values should be set to
# the observed (structural) values for wave=period+1.
# Concluding:
# For ties that have a structurally determined value at wave=period,
# this value is used for the observation at the end of the period.
# For ties that have a structurally determined value at the end of the period
# and a free value at the start,
# the structurally determined value at wave=period+1 is used
# for the simulations at the end of the period.
# TODO: Calculate the matrix of structurals and of missings outside
# of this procedure, doing it only once. Perhaps in sienaGOF.
sparseMatrixExtraction <-
	function(i, obsData, sims, period, groupName, varName){
	# require(Matrix)
	isBipartite <- "bipartite" == attr(obsData[[groupName]]$depvars[[varName]], "type")
	dimsOfDepVar<- attr(obsData[[groupName]]$depvars[[varName]], "netdims")
	if (attr(obsData[[groupName]]$depvars[[varName]], "sparse"))
	{
		missings <-
			(is.na(obsData[[groupName]]$depvars[[varName]][[period]]) |
			is.na(obsData[[groupName]]$depvars[[varName]][[period+1]]))*1
	}
	else
	{
		missings <- Matrix(
			(is.na(obsData[[groupName]]$depvars[[varName]][,,period]) |
			is.na(obsData[[groupName]]$depvars[[varName]][,,period+1]))*1)
	}
	if (is.null(i))
	{
		# sienaGOF wants the observation;
		# transform structurally fixed values into regular values
		# by "modulo 10" (%%10) operation
		# If preceding observation contains structural values
		# use these to replace the observations at period+1.
		if (attr(obsData[[groupName]]$depvars[[varName]], "sparse"))
		{
			returnValue <- drop0(Matrix(
				obsData[[groupName]]$depvars[[varName]][[period+1]] %% 10))
			returnValue[is.na(returnValue)] <- 0
			returnValue <- changeToStructural(returnValue,
				Matrix(obsData[[groupName]]$depvars[[varName]][[period]]))
		}
		else # not sparse
		{
			returnValue <-
			 Matrix(obsData[[groupName]]$depvars[[varName]][,,period+1] %% 10)
			returnValue[is.na(returnValue)] <- 0
			returnValue <- changeToStructural(returnValue,
				Matrix(obsData[[groupName]]$depvars[[varName]][,,period]))
		}
		if(!isBipartite) diag(returnValue) <- 0 # not guaranteed by data input
	}
	else
	{
		# sienaGOF wants the i-th simulation:
		returnValue <- sparseMatrix(
				sims[[i]][[groupName]][[varName]][[period]][,1],
				sims[[i]][[groupName]][[varName]][[period]][,2],
				x=sims[[i]][[groupName]][[varName]][[period]][,3],
				dims=dimsOfDepVar[1:2] )
		# If observation at end of period contains structural values
		# use these to replace the simulations.
		if (attr(obsData[[groupName]]$depvars[[varName]], "sparse"))
		{
			returnValue <- changeToNewStructural(returnValue,
				Matrix(obsData[[groupName]]$depvars[[varName]][[period]]),
				Matrix(obsData[[groupName]]$depvars[[varName]][[period+1]]))
		}
		else # not sparse
		{
			returnValue <- changeToNewStructural(returnValue,
				Matrix(obsData[[groupName]]$depvars[[varName]][,,period]),
				Matrix(obsData[[groupName]]$depvars[[varName]][,,period+1]))
		}
	}
	## Zero missings (the 1* turns the logical into numeric):
	1*drop0((returnValue - missings) > 0)
}

##@networkExtraction sienaGOF Extracts simulated networks
# This function provides a standard way of extracting simulated and observed
# networks from the results of a siena07 run.
# It returns the network as an edge list of class "network"
# according to the <network> package (used for package sna).
# Ties for ordered pairs with a missing value for wave=period or period+1
# are zeroed;
# note that this also is done in RSiena for calculation of target statistics.
# Structural values are treated as in sparseMatrixExtraction.
networkExtraction <- function (i, obsData, sims, period, groupName, varName){
	## suppressPackageStartupMessages(require(network))
	dimsOfDepVar<- attr(obsData[[groupName]]$depvars[[varName]], "netdims")
	isbipartite <- (attr(obsData[[groupName]]$depvars[[varName]], "type")
						=="bipartite")
	# For bipartite networks in package <network>,
	# the number of nodes is equal to
	# the number of actors (rows) plus the number of events (columns)
	# with all actors preceding all events.
	# Therefore the bipartiteOffset will come in handy:
	bipartiteOffset <- ifelse (isbipartite, 1 + dimsOfDepVar[1], 1)

	# Initialize empty networks:
	if (isbipartite)
	{
		emptyNetwork <- network::network.initialize(dimsOfDepVar[1]+dimsOfDepVar[2],
											bipartite=dimsOfDepVar[1])
	}
	else
	{
		emptyNetwork <- network::network.initialize(dimsOfDepVar[1], bipartite=NULL)
	}
	# Use what was defined in the function above:
	matrixNetwork <- sparseMatrixExtraction(i, obsData, sims,
						period, groupName, varName)
	sparseMatrixNetwork <- as(matrixNetwork, "dgTMatrix")
# For dgTMatrix, slots i and j are the rows and columns,
# numbered from 0 to dimension - 1. Slot x are the values.
# Actors in class network are numbered starting from 1.
# Hence 1 must be added to missings@i and missings@j.
# sparseMatrixNetwork@x is a column of ones;
# the 1 in the 3d column of cbind below is redundant
# because of the default ignore.eval=TRUE in network.edgelist.
# But it is good to be explicit.
	if (sum(matrixNetwork) <= 0) # else network.edgelist() below will not work
	{
		returnValue <- emptyNetwork
	}
	else
	{
		returnValue <- network::network.edgelist(
					cbind(sparseMatrixNetwork@i + 1,
					sparseMatrixNetwork@j + bipartiteOffset, 1),
					emptyNetwork)
	}
	returnValue
}

##@behaviorExtraction sienaGOF Extracts simulated behavioral variables.
# This function provides a standard way of extracting simulated and observed
# dependent behavior variables from the results of a siena07 run.
# The result is an integer vector.
# Values for actors with a missing value for wave=period or period+1 are
# transformed to NA.
behaviorExtraction <- function (i, obsData, sims, period, groupName, varName) {
  missings <- is.na(obsData[[groupName]]$depvars[[varName]][,,period]) |
	is.na(obsData[[groupName]]$depvars[[varName]][,,period+1])
  if (is.null(i))
	{
		# sienaGOF wants the observation:
		original <- obsData[[groupName]]$depvars[[varName]][,,period+1]
		original[missings] <- NA
		returnValue <- original
	}
	else
	{
		#sienaGOF wants the i-th simulation:
		returnValue <- sims[[i]][[groupName]][[varName]][[period]]
		returnValue[missings] <- NA
	}
	returnValue
}

##@OutdegreeDistribution sienaGOF Calculates Outdegree distribution
OutdegreeDistribution <- function(i, obsData, sims, period, groupName, varName,
						levls=0:8, cumulative=TRUE) {
	x <- sparseMatrixExtraction(i, obsData, sims, period, groupName, varName)
	a <- apply(x, 1, sum)
	if (cumulative)
	{
		oddi <- sapply(levls, function(i){ sum(a<=i) })
	}
	else
	{
		oddi <- sapply(levls, function(i){ sum(a==i) })
	}
	names(oddi) <- as.character(levls)
	oddi
}

##@IndegreeDistribution sienaGOF Calculates Indegree distribution
IndegreeDistribution <- function (i, obsData, sims, period, groupName, varName,
						levls=0:8, cumulative=TRUE){
  x <- sparseMatrixExtraction(i, obsData, sims, period, groupName, varName)
  a <- apply(x, 2, sum)
  if (cumulative)
  {
	iddi <- sapply(levls, function(i){ sum(a<=i) })
  }
  else
  {
	iddi <- sapply(levls, function(i){ sum(a==i) })
  }
  names(iddi) <- as.character(levls)
  iddi
}

##@BehaviorDistribution sienaGOF Calculates behavior distribution
BehaviorDistribution <- function (i, obsData, sims, period, groupName, varName,
							levls=NULL, cumulative=TRUE){
	x <- behaviorExtraction(i, obsData, sims, period, groupName, varName)
	if (is.null(levls))
	{
		levls <- attr(obsData[[groupName]]$depvars[[varName]],"behRange")[1]:
					attr(obsData[[groupName]]$depvars[[varName]],"behRange")[2]
	}
	if (cumulative)
	{
		bdi <- sapply(levls, function(i){ sum(x<=i, na.rm=TRUE) })
	}
	else
	{
	bdi <- sapply(levls, function(i){ sum(x==i, na.rm=TRUE) })
	}
	names(bdi) <- as.character(levls)
	bdi
}