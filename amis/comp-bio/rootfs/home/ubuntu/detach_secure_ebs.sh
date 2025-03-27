#!/bin/bash
set -euo pipefail -o errexit -o nounset

>&2 echo ". detecting instance owner"
token=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export instance_id=$(curl -H "X-aws-ec2-metadata-token: $token" -s http://169.254.169.254/latest/meta-data/instance-id)
export instance_owner=$(aws ec2 describe-tags \
                 --filters "Name=resource-id,Values=$instance_id" 'Name=key,Values=LaunchedBy' \
                 --query 'Tags[].Value' --output text)

>&2 echo ". detecting volume id for owner $instance_owner"
export volume_id=$(aegea ebs ls --tag Purpose=comp-bio-secure --tag Owner="$instance_owner" --json | jq -r last.id)

export secure_folder="$HOME/comp-bio-secure"
export mapper_name="comp-bio-secure"

sudo umount "$secure_folder" || true
sudo cryptsetup luksClose "/dev/mapper/$mapper_name" || true
aegea ebs detach $volume_id
rmdir "$secure_folder"
>&2 echo 
>&2 echo "Secure folder successfully detached"
>&2 echo 
