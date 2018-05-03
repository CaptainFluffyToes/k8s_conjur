#! /bin/sh -e

####Variables###
NAMESPACE=cyberark-conjur-enterprise
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


function main(){
	printf "\n----\n"
	printf "\nSetting up Conjur Master\n"
	master_config
	printf "\nSetting up Conjur Standby Instances\n"
	standby_config
	printf "\nSetting up Conjur Follower Instances\n"
	follower_config
	printf "\nSetting up Conjur Authnk8s Instances\n"
	authnk8s_config
}

function master_config(){
	local master_pod_name=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=master --no-headers | awk '{print $1;}')
	local master_container_name=master
	
	printf "Configuring Master Instance.\n\n"
	sleep 5
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name -i -t -- evoke configure master -h $MASTER_SERVICE_NAME -p $ADMIN_PASSWORD $CONJUR_ACCOUNT
	printf "\n\nMaster instance has been configured."
}

function standby_config(){
	local standby_pod_names=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=standby --no-headers | awk '{print $1;}')
	local standby_container_name=standby
	local master_pod_name=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=master --no-headers | awk '{print $1;}')
	local master_container_name=master

	printf "\nGenerating standby SEED package.\n"
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name -i -t evoke ca issue $STANDBY_URL
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name -i -t evoke seed standby $STANDBY_URL $MASTER_URL > standby.tar

	for pod in $standby_pod_names; do
		printf "\nWorking on Pod:$pod.\n"
		kubectl cp standby.tar $NAMESPACE/$pod:/standby.tar -c $standby_container_name
		printf "\n\nUnpacking and importing standby seed package.\n\n"
		kubectl -n $NAMESPACE exec $pod -c $standby_container_name evoke unpack seed /standby.tar
		kubectl -n $NAMESPACE exec $pod -c $standby_container_name evoke configure standby
	done
	
	rm standby.tar
}

function follower_config(){
	local follower_pod_names=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=follower --no-headers | awk '{print $1;}')
	local follower_container_name=follower
	local master_pod_name=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=master --no-headers | awk '{print $1;}')
	local master_container_name=master

	printf "\nGenerating follower SEED package.\n"
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name -i -t evoke ca issue $FOLLOWER_URL
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name -i -t evoke seed follower $FOLLOWER_URL $MASTER_URL > follower.tar
	
	for pod in $follower_pod_names; do
		printf "\nWorking on Pod:$pod.\n"
		kubectl cp follower.tar $NAMESPACE/$pod:/follower.tar -c $follower_container_name
		printf "\n\nUnpacking and importing follower seed package.\n\n"
		kubectl -n $NAMESPACE exec $pod -c $follower_container_name evoke unpack seed /follower.tar
		kubectl -n $NAMESPACE exec $pod -c $follower_container_name evoke configure follower
	done
	
	rm follower.tar
}

function authnk8s_config(){
	local authnk8s_pod_names=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=authnk8s --no-headers | awk '{print $1;}')
	local authnk8s_container_name=authnk8s
	local master_pod_name=$(kubectl get pods -n $NAMESPACE -l app=conjur-node,role=master --no-headers | awk '{print $1;}')
	local master_container_name=master
	
	printf "\nGenerating authnk8s SEED package.\n"
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name -i -t evoke ca issue $AUTHNK8S_URL
	kubectl -n $NAMESPACE exec $master_pod_name -c $master_container_name -i -t evoke seed follower $AUTHNK8S_URL $MASTER_URL > authnk8s.tar
	
	for pod in $authnk8s_pod_names; do
		printf "\nWorking on Pod:$pod\n"
		kubectl cp authnk8s.tar $NAMESPACE/$pod:/authnk8s.tar -c $follower_container_name
		printf "\n\nUnpacking and importing authnk8s seed package.\n\n"
		kubectl -n $NAMESPACE exec $pod -c $follower_container_name evoke unpack seed /authnk8s.tar
		kubectl -n $NAMESPACE exec $pod -c $follower_container_name evoke configure follower
	done
	
	rm authnk8s.tar
}

main