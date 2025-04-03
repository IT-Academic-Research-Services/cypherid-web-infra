# This script is sourced by GitHub Actions.

set -a
AWS_DEFAULT_REGION=us-west-2
AWS_DEFAULT_OUTPUT=json
TERRAFORM_VERSION=1.11.3
TF_CLI_ARGS_apply="--auto-approve"
set +a

curl -OLs https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
sudo unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin