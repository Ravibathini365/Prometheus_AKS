#! /bin/bash

#Login to Artifactory
if docker login vscojfrogrhel.vsazure.com/infra-images -u admin -p 'P1(kl3s4u'
then
    echo "Login to Artifactory (vscojfrogrhel.vsazure.com) is Successful"
else
   echo "Login to Artifactory (vscojfrogrhel.vsazure.com) is Failed, please check with Infra team"
   exit 1
fi

#Getting the list of docker images in jenkins machine
echo "fetching the list of docker images in jenkins machine"
docker images -a

#Removing all the images in jenkins machine
echo "Removing all the images from jenkins machine"
docker rmi $(docker images -q) -f > /dev/null 2>&1

#Pulling the RHEL base image from our artifactory
docker pull vscojfrogrhel.vsazure.com/rhel-ubi-images/ubi8:latest
if [ `echo $?` == 0 ]
then
    echo "Able to pull the RHEL base image from Artifactory"
else
    echo "Unable to pull the RHEL base image from Artifactory, please check with Infra team"
    exit 1
fi

#Prometheus package check
ls -l prometheus-2.32.1.linux-amd64.tar.gz
if [ `echo $?` == 0 ]
then
    echo "Prometheus tar file is already available"
else
    wget https://vscojfrog.vsazure.com/artifactory/oc-infra-local/prometheus-2.32.1.linux-amd64.tar.gz > /dev/null 2>&1
    if [ `echo $?` == 0 ]
    then
        echo "Able to pull the Prometheus package from Artifactory"
    else
        echo "Unable to pull the Prometheus package from Artifactory, please check with Infra team"
        exit 1
    fi
fi

#Untar the Prometheus package
echo "Untaring the Prometheus package"
tar -xvf prometheus-2.32.1.linux-amd64.tar.gz

#Building prometheus image in jenkins machine
docker build -t prometheus .
docker images | grep -w prometheus
if [ `echo $?` == 0 ]
then
    echo "prometheus image successfully created"
else
    echo "Unable to build the prometheus image - please check the Docker file and centos image"
    exit 1
fi

#Tagging and pushing the docker image
docker tag prometheus vscojfrogrhel.vsazure.com/infra-images/prometheus
docker push vscojfrogrhel.vsazure.com/infra-images/prometheus

#Connect to AKS-cluster
az aks get-credentials --name vs-etocore-aks-infra --resource-group vs-etocore-eastus2-rg 

#Check for the old running pods
kubectl get pods -o wide -n monitoring | grep prometheus| grep -v 'alert-manager'
if [ `echo $?` == 0 ]
then 
    echo "Deleting the old pods"
    kubectl scale --replicas=0 deployment/prometheus -n monitoring
    sleep 25
fi


#Deleting the script fle from jenkins machine
rm -f prometheus-deploy.sh
rm -f prometheus-2.32.1.linux-amd64.tar.gz
rm -f telnet-0.17-76.el8.x86_64.rpm
rm -f iputils-20180629-7.el8.x86_64.rpm
rm -f tcpdump-4.9.3-1.el8.x86_64.rpm

#Deploying the new pods from new docker image
kubectl scale --replicas=1 deployment/prometheus -n monitoring
kubectl apply -f prometheus-aks-deploy.yaml; sleep 25
kubectl get pods -n monitoring | grep -v alert | grep -v 'msteams'| grep prometheus | grep -v Running| tr -s ' ' | cut -d ' ' -f1 > .tmppods
if [ -s .tmppods ]
then
     for container in `cat .tmppods`
     do
       kubectl delete pod $container -n monitoring --grace-period=0 --force
     done
     echo "Pods are not coming UP Healthy, please check the config file"
     exit 1
fi
