#! /bin/sh

namespace=conjur-ee

master_pod_name=
master_container_name=conjur-master
master_service_name=conjur-master.conjur-ee.svc.cluster.local

follower_pod_name=
follower_container_name=conjur-follower
follower_service_name=conjur-follower.conjur-ee.svc.cluster.local

kubectl --namespace=$namespace exec $master_pod_name -c $master_container_name -i -t -- evoke configure master -h $master_service_name -p Cyberark1 cyberark
kubectl --namespace=$namespace exec $master_pod_name -c $master_container_name evoke ca issue $follower_service_name
kubectl --namespace=$namespace exec $master_pod_name -c $master_container_name evoke seed follower $follower_service_name $master_service_name > follower.tar
kubectl cp follower.tar $namespace/$follower_pod_name:/follower.tar
kubectl --namespace=$namespace exec $follower_pod_name -c $follower_container_name evoke unpack seed /follower.tar
kubectl --namespace=$namespace exec $follower_pod_name -c $follower_container_name evoke configure follower
rm follower.tar