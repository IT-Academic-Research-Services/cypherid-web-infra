#!/bin/bash
set -ex

REGIONS=(us-east-1 us-east-2 us-west-1 us-west-2)

OLDIFS=$IFS
IFS=','  # A trick to get bash to comma separate into tuples. See https://stackoverflow.com/questions/9713104/
FIRST=1
for p in \
    czi_ubuntu16_main_pinned,czi-ubuntu16-main* \
    czi_ubuntu18_main_pinned,czi-ubuntu18-main* \
    czi_amazon_main_pinned,czi-amazon-linux-main* \
    czi_amazon2_ecs_main_pinned,czi-amzn2-ecs-main* \
    czi_amazon2_eks_1_16_main_pinned,czi-amzn2-eks-1.16-main* \
    czi_ubuntu18_deep_learning_main_pinned,czi-ubuntu18-deep-learning-main* \
    czi_amazon1_main_pinned,czi-amzn1-main*; do
  if [[ "$FIRST" == "1" ]]; then FIRST=0; else echo; fi
  set -- $p
  cat <<EOF
variable "$1" {
  type = map(string)

  default = {
EOF
  for region in ${REGIONS[@]}; do
    ami=$(aws --profile czi-images --region $region ec2 describe-images --filters \
      "Name=name,Values=$2" \
      "Name=virtualization-type,Values=hvm" \
      "Name=root-device-type,Values=ebs" \
      "Name=state,Values=available" \
      --output json \
      --query 'max_by(Images[], &CreationDate).ImageId'
    )
    if [[ "$ami" != "null" ]]; then
      echo "    $region = $ami"
    fi
  done
cat <<EOF
  }
}
EOF
done
IFS=$OLDIFS
