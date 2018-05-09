#!/bin/bash

###calling various functions from separate files
source utils.sh

main()
{
	printf "\n----"
	printf "\nCreating cluster."
	cluster_create
	printf "\nSleeping for 120 seconds.\n"
	sleep 120
	printf "\nSetting up Conjur Master."
	master_config
	printf "\nSetting up Conjur Standby Instances."
	standby_config
	printf "\nSetting up Conjur Follower Instances."
	follower_config
	printf "\nConjur Cluster has finished!\n"
	printf "\n----\n"
}

main