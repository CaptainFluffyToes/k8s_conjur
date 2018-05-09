#!/bin/bash

source utils.sh

main (){
	printf "\n----"
	printf "\nCreating authnk8s deployments."
	authnk8s_create
	printf "\n\nSleeping for 120 seconds."
	sleep 120
	printf "\nSetting up Conjur Authnk8s Instances."
	authnk8s_config
	printf "\nLoading policies"
	policy_load_authnk8s
	printf "\nCreating k8s-app namespace."
	kubectl create namespace k8s-app
	printf "\nCreating certificate authority."
	conjur_cert_authority
	printf "\nCreate and load configmap with conjur SSL."
	ssl_configmap
	printf "\nCreating authnk8s app deployments."
	authnk8s_app_create
	printf "\n----\n"
}

main