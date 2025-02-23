#!/bin/bash

CLIENT=$1
ENVIRONMENT=$2
PREVIOUS_VERSION=$(aws ssm get-parameter --name "/mautic/${CLIENT}/${ENVIRONMENT}/last_stable_version")

./scripts/manage-versions.sh deploy $CLIENT $ENVIRONMENT $PREVIOUS_VERSION 