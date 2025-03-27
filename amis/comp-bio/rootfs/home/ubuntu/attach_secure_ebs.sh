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

export DEV="/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol${volume_id#"vol-"}"
export mapper_name="comp-bio-secure"
export secure_folder="$HOME/comp-bio-secure"

if [ ! -L "$DEV" ]; then
  >&2 echo ". attaching volume $volume_id"
  aegea ebs attach $volume_id

  while [ ! -L $DEV ]; do
    >&2 echo ". waiting for volume $volume_id to be available to this instance..."
    sleep 3
  done
fi

>&2 echo ". Decrypting volume"
sudo cryptsetup luksOpen "$DEV" "$mapper_name"
mkdir -p "$secure_folder" || true
sudo mount "/dev/mapper/$mapper_name" "$secure_folder"
sudo chown ubuntu "$secure_folder"

>&2 echo
>&2 echo "Secure folder successfully mounted to '$secure_folder'"
>&2 echo
