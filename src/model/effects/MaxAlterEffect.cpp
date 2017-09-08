/******************************************************************************
 * SIENA: Simulation Investigation for Empirical Network Analysis
 *
 * Web: http://www.stats.ox.ac.uk/~snijders/siena/
 *
 * File: MaxAlterEffect.cpp
 *
 * Description: This file contains the implementation of the
 * MaxAlterEffect class.
 *****************************************************************************/

#include <cmath>
#include "MaxAlterEffect.h"
#include "network/Network.h"
#include "network/IncidentTieIterator.h"
#include "model/variables/NetworkVariable.h"
#include "model/variables/BehaviorVariable.h"
namespace siena
{

/**
 * Constructor.
 */
MaxAlterEffect::MaxAlterEffect(
	const EffectInfo * pEffectInfo, bool minim) :
		NetworkDependentBehaviorEffect(pEffectInfo)
{
	this->lminim = minim;
	// Indicates whether it will be a minimum instead of a maximum
}


/**
 * Calculates the change in the statistic corresponding to this effect if
 * the given actor would change his behavior by the given amount.
 */
double MaxAlterEffect::calculateChangeContribution(int actor,
	int difference)
{
	double contribution = 0;
	const Network * pNetwork = this->pNetwork();

	if ((pNetwork->outDegree(actor) > 0) && (difference != 0))
	{
		if (lminim)
		{
			contribution = 1000;
		}
		else
		{
			contribution = -1000;
		}
		for (IncidentTieIterator iter = pNetwork->outTies(actor);
			iter.valid();
			iter.next())
		{
			if (lminim)
			{
				if (this->centeredValue(iter.actor()) < contribution)
				{
					contribution = this->centeredValue(iter.actor()) ;
				}
			}
			else
			{
				if (this->centeredValue(iter.actor())  > contribution)
				{
					contribution = this->centeredValue(iter.actor()) ;
				}
			}
		}
	contribution *= difference;
	}
	return  contribution;
}


/**
 * Returns the statistic corresponding to the given ego with respect to the
 * given values of the behavior variable.
 */
double MaxAlterEffect::egoStatistic(int i, double * currentValues)
{
	double statistic = 0;
	const Network * pNetwork = this->pNetwork();

	if (pNetwork->outDegree(i) > 0)
	{
		for (IncidentTieIterator iter = pNetwork->outTies(i);
			iter.valid();
			iter.next())
		{
			if (lminim)
			{
				statistic = 1000;
			}
			else
			{
				statistic = -1000;
			}
			for (IncidentTieIterator iter = pNetwork->outTies(i);
				iter.valid();
				iter.next())
			{
				if (lminim)
				{
					if (currentValues[iter.actor()] < statistic)
					{
						statistic = currentValues[iter.actor()];
					}
				}
				else
				{
					if (currentValues[iter.actor()] > statistic)
					{
						statistic = currentValues[iter.actor()];
					}
				}
			}
		}
		statistic *= currentValues[i];
	}

	return statistic;
}

}
