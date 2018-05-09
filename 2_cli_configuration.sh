#!/bin/bash

source utils.sh

main (){
	printf "\n----"
	printf "\nSetting up Conjur CLI."
	cli_config
	printf "\nLoading Policies!"
	policy_load
}

main