#!/bin/bash

set -euo pipefail -o errexit -o nounset

>&2 echo ". Getting account alias and environment name"
source_account=$(aws sts get-caller-identity | jq -r .Arn | cut -d ':' -f5)
account_alias=$(aws iam list-account-aliases --output text --query 'AccountAliases[0]')
env=$([[ "$account_alias" == "idseq-dev" ]] && echo "staging" || echo "prod" )
>&2 echo ". Detecting deployed docker image for [$env] environment in [$account_alias] account"
source_repository_address="${source_account}.dkr.ecr.us-west-2.amazonaws.com"
deployed_image=sha-$(aws ssm get-parameter --name "/idseq-${env}-web/GIT_RELEASE_SHA" --with-decryption --query 'Parameter.Value' --output text)
source_image_name="idseq-web:${deployed_image}"
image_path="${source_repository_address}/${source_image_name}"
>&2 echo ". ECR login"
$(aws ecr get-login --no-include-email --region us-west-2)

>&2 echo ". Fetching docker image $image_path"
docker pull "$image_path"

declare -a commands
if [[ $# -gt 1 ]]; then
    commands=( ${@} )
else
    commands=( rails c )
fi
        
docker run --rm -v /mnt/logs:/app/log -v /mnt:/mnt \
           -e AWS_DEFAULT_AZ -e AWS_DEFAULT_REGION \
           -e ENVIRONMENT="$env" -e RAILS_ENV="$env" \
           -it "$image_path" \
           ${commands[@]}