#!/usr/bin/env bash

profile="default"
STACK_NAME="CDN"

aws cloudformation deploy \
    --template-file template.yml \
    --stack-name ${STACK_NAME} \
    --capabilities CAPABILITY_NAMED_IAM \
    --profile ${profile}
