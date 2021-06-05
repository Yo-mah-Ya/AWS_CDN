#!/usr/bin/env bash

ROUTE53_DOMAIN_NAME="*** Your Domain Here like example.com ***"

# 1. Create ACM & Route 53 Host zone
ACM_PROFILE="ACM"
ACM_STACK_NAME="ACM"

your_profile_region=$(aws configure get region --profile ${ACM_PROFILE})
if [ "${your_profile_region}" != "us-east-1" ] ; then
    echo "You can create AWS Certificate Manager for CloudFront just only in us-east-1"
    echo "Your profile ${ACM_PROFILE} specifies ${your_profile_region}"
    exit 1
fi
aws cloudformation deploy \
    --template-file ACM.yml \
    --stack-name ${ACM_STACK_NAME} \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
        Route53DomainName=${ROUTE53_DOMAIN_NAME} \
    --profile ${ACM_PROFILE}

if [ $? -ne 0 ] ; then
    echo "Failed to deploy ${ACM_STACK_NAME}"
    exit 255
fi

# 2. Check Route 53 Host Zone ID & AWS Certificate Manager ARN
StackResources=$(aws cloudformation describe-stack-resources --stack-name ${ACM_STACK_NAME} --profile ${ACM_PROFILE} | jq .StackResources)
length=$(echo ${StackResources} | jq length)

Route53HostedZoneID=""
ACMforCloudFrontARN=""
for i in $(seq 0 $((${length} - 1))) ; do
    resource=$(echo ${StackResources} | jq .[$i])
    LogicalResourceId=$(echo ${resource} | jq -r .LogicalResourceId)

    if [ "${LogicalResourceId}" = "Route53HostedZone" ] ; then
        Route53HostedZoneID=$(echo ${resource} | jq -r .PhysicalResourceId)
        tput setaf 6 && echo "Route 53 Host Zone ID       : ${Route53HostedZoneID}" && tput sgr0
    elif [ "${LogicalResourceId}" = "CertificateManager" ] ; then
        ACMforCloudFrontARN=$(echo ${resource} | jq -r .PhysicalResourceId)
        tput setaf 6 && echo "AWS Certificate Manager ARN : ${ACMforCloudFrontARN}" && tput sgr0
    fi
done

if [ "${Route53HostedZoneID}" = "" ] ; then
    echo "Not Found Route 53 Host Zone ID"
fi
if [ "${ACMforCloudFrontARN}" = "" ] ; then
    echo "Not Found AWS Certificate Manager ARN"
fi
if [ "${Route53HostedZoneID}" = "" -o "${ACMforCloudFrontARN}" = "" ] ; then
    exit 255
fi

# 3. Deploy CloudFront & S3

DEFAULT_PROFILE="default"
CDN_STACK_NAME="CDN"

aws cloudformation deploy \
    --template-file template.yml \
    --stack-name ${CDN_STACK_NAME} \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameter-overrides \
        Route53DomainName=${ROUTE53_DOMAIN_NAME} \
        Route53HostedZoneID=${Route53HostedZoneID} \
        ACMforCloudFrontARN=${ACMforCloudFrontARN} \
    --profile ${DEFAULT_PROFILE}
