set -e
#install deps
apt-get update
apt-get install -y wget zip


key="/$cluster_name/linkerd/ca.key"
cert="/$cluster_name/linkerd/ca.crt"
echo
echo working on $(uname -m)
echo

wget https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip
unzip aws*zip
./aws/install

if [ "$(uname -m)" == "x86_64" ]; then
  wget https://github.com/smallstep/cli/releases/download/v0.24.4/step_linux_0.24.4_amd64.tar.gz
else
  wget https://github.com/smallstep/cli/releases/download/v0.24.4/step_linux_0.24.4_arm64.tar.gz 
fi

tar -xvzf step_linux*.tar.gz



# Check if key already exists in parameter store
# Perform no action if it does
found_key=$(aws ssm describe-parameters --parameter-filters Key=Name,Values=$key --output text --no-cli-pager)
if [ ! -z "$found_key" ]; then
  echo "Key: $key already exists in parameter store, preforming no action"
  exit 0
fi

echo "Key: $key does not exist in parameter store, generating new key and cert"


# Generate new key and cert, named k8s.crt k8s.key
./step_*/bin/step certificate create root.linkerd.cluster.local k8s.crt k8s.key --profile root-ca --no-password --insecure --curve=P-256 --kty=EC

# Push key and cert to parameter store
aws ssm put-parameter --name $key --value "$(cat k8s.key)" --type SecureString --no-cli-pager
aws ssm put-parameter --name $cert --value "$(cat k8s.crt)" --type SecureString --no-cli-pager