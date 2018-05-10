#!/bin/bash

####Global Variables###
NAMESPACE=cyberark-conjur-enterprise
APP_NAMESPACE=k8s-app
ADMIN_PASSWORD=Cyberark1
CONJUR_ACCOUNT=cyberark

MASTER_SERVICE_NAME=conjur-master
STANDBY_SERVICE_NAME=conjur-standby
FOLLOWER_SERVICE_NAME=conjur-follower
AUTHNK8S_SERVICE_NAME=conjur-authnk8s

MASTER_URL=$MASTER_SERVICE_NAME.$NAMESPACE.svc.cluster.local
STANDBY_URL=$STANDBY_SERVICE_NAME.$NAMESPACE.svc.cluster.local
FOLLOWER_URL=$FOLLOWER_SERVICE_NAME.$NAMESPACE.svc.cluster.local
AUTHNK8S_URL=$AUTHNK8S_SERVICE_NAME.$NAMESPACE.svc.cluster.local

get_master_pod_name(){
	local master_pod_name=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=master --no-headers | awk '{print $1;}')
	echo "$master_pod_name"
}

get_master_container_name(){
	local master_pod_name=$(get_master_pod_name)
	local master_container_name=$(kubectl -n $NAMESPACE get pods $master_pod_name -o jsonpath='{.spec.containers[*].name}')
	echo "$master_container_name"
}

master_config()
{
	printf "\nConfiguring Master Instance.\n"
	local master_pod_name=$(get_master_pod_name)
	local master_container_name=$(get_master_container_name)
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name -i -t -- evoke configure master -h $MASTER_URL -p $ADMIN_PASSWORD $CONJUR_ACCOUNT &> /dev/null
	printf "Master instance has been configured.\n"
}

standby_config()
{
	printf "\nGetting Standby pod names.\n"
	local standby_pod_names=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=standby --no-headers | awk '{print $1;}')
	printf "Generating standby SEED package.\n"
	local master_pod_name=$(get_master_pod_name)
	local master_container_name=$(get_master_container_name)
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name -- evoke ca issue --force $STANDBY_URL &> /dev/null
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name evoke seed standby $STANDBY_URL $MASTER_URL > standby.tar

	for pod in $standby_pod_names; do
		printf "Working on Pod:$pod.\n"
		printf "Finding Containers within Pod: $pod\n"
		local standby_container_name=$(kubectl -n $NAMESPACE get pods $pod -o jsonpath='{.spec.containers[*].name}')
		for container in $standby_container_name; do
			printf "Working on container: $container in pod: $pod\n"
			printf "Copying seed package into container: $container\n"
			kubectl cp standby.tar $NAMESPACE/$pod:/standby.tar -c $container
			printf "Unpacking and importing standby seed package.\n"
			kubectl -n $NAMESPACE exec $pod -c $container evoke unpack seed /standby.tar &> /dev/null
			printf "Configuring standby server.\n"
			kubectl -n $NAMESPACE exec $pod -c $container evoke configure standby &> /dev/null
			printf "Standby server configured!\n"
		done
	done
	rm standby.tar
}

follower_config()
{
	printf "\nGetting Follwer pod names.\n"
	local follower_pod_names=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=follower --no-headers | awk '{print $1;}')
	printf "Generating follower SEED package.\n"
	local master_pod_name=$(get_master_pod_name)
	local master_container_name=$(get_master_container_name)
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name -- evoke ca issue --force $FOLLOWER_URL &> /dev/null
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name evoke seed follower $FOLLOWER_URL $MASTER_URL > follower.tar
	
	for pod in $follower_pod_names; do
		printf "Working on Pod:$pod.\n"
		printf "Finding Containers within Pod: $pod\n"		
		local follower_container_name=$(kubectl -n $NAMESPACE get pods $pod -o jsonpath='{.spec.containers[*].name}')
		for container in $follower_container_name; do
			printf "Working on container: $container in pod: $pod\n"
			printf "Copying seed package into container: $container\n"
			kubectl cp follower.tar $NAMESPACE/$pod:/follower.tar -c $container
			printf "Unpacking and importing follower seed package.\n"
			kubectl -n $NAMESPACE exec $pod -c $container evoke unpack seed /follower.tar &> /dev/null
			printf "Configuring follower server.\n"
			kubectl -n $NAMESPACE exec $pod -c $container evoke configure follower &> /dev/null
			printf "Follower server configured!\n"		
		done
	done
	rm follower.tar
}

authnk8s_config()
{
	printf "\nGetting Authnk8s pod names.\n"
	local authnk8s_pod_names=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=authnk8s --no-headers | awk '{print $1;}')
	printf "Generating authnk8s SEED package.\n"
	local master_pod_name=$(get_master_pod_name)
	local master_container_name=$(get_master_container_name)
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name -- evoke ca issue --force $AUTHNK8S_URL &> /dev/null
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name evoke seed follower $AUTHNK8S_URL $MASTER_URL > authnk8s.tar
	
	for pod in $authnk8s_pod_names; do
		printf "Working on Pod:$pod\n"
		printf "Finding Containers within Pod: $pod\n"		
		local authnk8s_container_name=$(kubectl -n $NAMESPACE get pods $pod -o jsonpath='{.spec.containers[*].name}')
		for container in $authnk8s_container_name; do
			printf "Working on container: $container in pod: $pod\n"
			printf "Copying seed package into container: $container\n"
			kubectl cp authnk8s.tar $NAMESPACE/$pod:/authnk8s.tar -c $container
			printf "Unpacking and importing authnk8s seed package.\n"
			kubectl -n $NAMESPACE exec $pod -c $container evoke unpack seed /authnk8s.tar &> /dev/null
			printf "Configuring authnk8s server.\n"
			kubectl -n $NAMESPACE exec $pod -c $container evoke configure follower &> /dev/null
			printf "Authnk8s server configured!\n"		
		done
	done
	rm authnk8s.tar
}

cli_config()
{
	printf "\nGetting CLI pod names."	
	local cli_pod_names=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=cli --no-headers | awk '{print $1;}')
	printf "\nGetting Certificate from Master."
	local master_pod_name=$(get_master_pod_name)
	local master_container_name=$(get_master_container_name)
	kubectl cp $NAMESPACE/$master_pod_name:/opt/conjur/etc/ssl/ca.pem -c $master_container_name conjur-$CONJUR_ACCOUNT.pem &> /dev/null

cat > "conjurrc" <<EOF
---
account: $CONJUR_ACCOUNT
plugins: []
appliance_url: https://$MASTER_URL/api
cert_file: "/root/conjur-$CONJUR_ACCOUNT.pem"
EOF

	for pod in $cli_pod_names; do
		printf "\nWorking on Pod:$pod\n"
		printf "Finding Containers within Pod: $pod\n"		
		local cli_container_name=$(kubectl -n $NAMESPACE get pods $pod -o jsonpath='{.spec.containers[*].name}')
		for container in $cli_container_name; do
			printf "Working on container: $container in pod: $pod\n"
			printf "Copying new certificate into container $container.\n"
			kubectl cp conjur-$CONJUR_ACCOUNT.pem $NAMESPACE/$pod:/root/conjur-$CONJUR_ACCOUNT.pem -c $container
			kubectl cp conjurrc $NAMESPACE/$pod:/root/.conjurrc -c $container
			kubectl -n $NAMESPACE exec $pod -c $container -i -t -- conjur authn login -u admin -p $ADMIN_PASSWORD
			printf "CLI configured!\n"		
		done
	done
	printf "Removing certificate.\n"
	rm -f conjur-$CONJUR_ACCOUNT.pem
	printf "Removing configuration file.\n"
	rm -f conjurrc
}

policy_load(){
	printf "\nGetting CLI pod names."
	local cli_pod_names=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=cli --no-headers | awk '{print $1;}')
	
	for pod in $cli_pod_names; do
		printf "\nWorking on Pod:$pod\n"
		printf "Finding Containers within Pod: $pod\n"		
		local cli_container_name=$(kubectl -n $NAMESPACE get pods $pod -o jsonpath='{.spec.containers[*].name}')
		for container in $cli_container_name; do
			printf "Working on container: $container in pod: $pod\n"
			printf "Copying policy directory into container.\n"
			kubectl cp policy $NAMESPACE/$pod:/root/policy -c $container
			printf "Loading policies.\n"
			kubectl -n $NAMESPACE exec $pod -c $container -i -t -- conjur policy load --as-group security_admin /root/policy/policy_lab.yaml
			printf "Policies Loaded\n"		
		done
	done
}

policy_load_authnk8s(){
	printf "\nGetting CLI pod names."
	local cli_pod_names=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=cli --no-headers | awk '{print $1;}')
	
	for pod in $cli_pod_names; do
		printf "\nWorking on Pod:$pod\n"
		printf "Finding Containers within Pod: $pod\n"		
		local cli_container_name=$(kubectl -n $NAMESPACE get pods $pod -o jsonpath='{.spec.containers[*].name}')
		for container in $cli_container_name; do
			printf "Working on container: $container in pod: $pod\n"
			printf "Copying authnk8s directory into container.\n"
			kubectl cp authnk8s $NAMESPACE/$pod:/root/authnk8s -c $container
			printf "Loading policy for authnk8s test app.\n"
			kubectl -n $NAMESPACE exec $pod -c $container -i -t -- conjur policy load --as-group security_admin /root/authnk8s/conjur.yml
			printf "Policies Loaded\n"
			printf "Setting variable value for test-app-db."
			kubectl -n $NAMESPACE exec $pod -c $container -i -t -- conjur variable values add test-app-db/password $(openssl rand -hex 12)
		done
	done
}

cluster_create(){
	printf "\nLoading manifest into cluster.\n"
	kubectl apply -f ./manifests/CyberarkConjurEnterprise.yaml
	printf "Loaded manifest into cluster.\n"
}

authnk8s_create(){
	printf "\nLoading manifest into cluster.\n"
	kubectl apply -f ./manifests/CyberarkConjurAuthnk8s.yaml
	printf "Loaded manifest into cluster."
}

authnk8s_app_create(){
	printf "\nLoading manifest into cluster for test app.\n"
	kubectl apply -f ./manifests/Authnk8sApp.yaml
	printf "Loaded manifest into cluster for test app."	
}

conjur_cert_authority(){
	local master_pod_name=$(get_master_pod_name)
	local master_container_name=$(get_master_container_name)
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name -- conjur-plugin-service authn-k8s rake ca:initialize["conjur/authn-k8s/prod"] &> /dev/null
}

ssl_configmap(){
	local authnk8s_pod_names=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=authnk8s --no-headers | awk '{print $1;}')
	local ssl_cert=$(kubectl -n $NAMESPACE exec $authnk8s_pod_names -- cat /opt/conjur/etc/ssl/conjur.pem)
	kubectl -n $APP_NAMESPACE delete --ignore-not-found=true configmap k8s-app-ssl
	kubectl -n $APP_NAMESPACE create configmap k8s-app-ssl --from-file=ssl-certificate=<(echo "$ssl_cert")
}