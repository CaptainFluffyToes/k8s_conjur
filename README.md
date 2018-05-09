# CyberArk Conjur Enterprise Kubernetes Deployment
This will stand up a CyberArk Conjur Enterprise cluster in Kubernetes.  It can also expand the cluster to include Conjur integrated into kubernets for multi-factor verification of pod characteristics  

## Containers that comprise the cluster
* CyberArk Conjur Master
* CyberArk Conjur Follower(s)
* CyberArk Conjur Standby(s)
* CyberArk Conjur Authnk8sFollower(s)
* CyberArk Conjur CLI

## Requirements
* Kubernetes v1.8 or higher
* Machine with kubectl configured with administrative privileges to the Kubernetes environment
* Kuberentes secret created in the cyberark-conjur-enterprise namespace that can pull an image directly from Conjur private repository

## How to use

1. Clone Repo into machine with a configured kubectl
2. Create secret in namespace "cyberark-conjur-enterprise" that logs into the private conjur docker registry
3. Execute ./1_conjur_configuration.sh
4. Execute ./2_cli_configuration.sh
5. Execute ./3_authnk8s_configuration.sh (only if you want to test out the integration)

This will create a fully working cluster with a logged in and configured CLI pod.