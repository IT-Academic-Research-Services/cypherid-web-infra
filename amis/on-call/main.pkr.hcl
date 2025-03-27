source "amazon-ebs" "idseq-on-call" {
  ami_description = "AMI for running idseq on call tasks"
  ami_name        = "idseq-on-call"
  instance_type   = "t2.medium"
  region          = "us-west-2"

  tags = {
    name = "idseq-on-call"
  }

  iam_instance_profile = "idseq-packer-instance"
  ssh_username         = "ubuntu"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 16
    volume_type           = "gp2"
    delete_on_termination = true
  }

  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "czi-ubuntu18-main-*"
      root-device-type    = "ebs"
    }
    # This is the AWS account ID of the base image owner
    # not the account ID the image will end up in.
    owners      = ["723754913286"]
    most_recent = true
  }

  force_deregister      = true
  force_delete_snapshot = true

  run_tags = {
    "managedBy" = "packer"
  }

  run_volume_tags = {
    "managedBy" = "packer"
  }
}

locals {
  apt_packages = [
    "apt-transport-https",
    "awscli",
    "ca-certificates",
    "curl",
    "firefox",
    "gnupg-agent",
    "mysql-server",
    "nodejs",
    "npm",
    "python3-pip",
    "python3-setuptools",
    "ruby-full",
    "software-properties-common",
  ]

  pip_packages = [
    "aegea",
    "virtualenv",
  ]
}

build {
  sources = [
    "source.amazon-ebs.idseq-on-call"
  ]

  provisioner "file" {
    source      = "amis/on-call/downloads.cksums"
    destination = "/tmp/downloads.cksums"
  }

  # This script is not versioned so checking it's checksum will lead to breakages
  # Since it is being run in bash it should be manually inspected so a downloaded
  # version is kept here and uploaded manually. To get the latest version use:
  # curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh -o install-homebrew.sh
  provisioner "file" {
    source      = "amis/on-call/install-homebrew.sh"
    destination = "/tmp/install-homebrew.sh"
  }

  provisioner "file" {
    sources     = [ "amis/on-call/README.md", "amis/on-call/idseq-web.sh" ]
    destination = "/home/ubuntu/"
  }

  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      # change permissions
      "chmod u+x /home/ubuntu/idseq-web.sh",
      # wait for cloud-init script to end
      "sudo systemd-run --property='After=cloud-init.service apt-daily.service apt-daily-upgrade.service' --wait /bin/true",
      # install apt dependencies
      "sudo apt-get update && sudo apt-get install -y ${join(" ", local.apt_packages)}",
      # update pip
      "pip3 install -U pip",
      # install pip dependencies
      "pip3 install ${join(" ", local.pip_packages)}",
      "cd /tmp",
      # download
      "curl -L https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Linux-x86_64 -o docker-compose-Linux-x86_64",
      # verify download integrity
      "sha256sum --quiet -c downloads.cksums",
      # install homebrew
      "bash install-homebrew.sh",
      # install blessclient
      "brew tap chanzuckerberg/tap && brew install blessclient@1",
      # install docker
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo apt-key fingerprint 0EBFCD88",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt-get update && sudo apt-get -y install docker-ce docker-ce-cli containerd.io",
      "sudo usermod -aG docker ubuntu",
      # install docker-compose
      "sudo mv docker-compose-Linux-x86_64 /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose",
      # configure aws
      "echo 'token=$(curl -s -X PUT \"http://169.254.169.254/latest/api/token\" -H \"X-aws-ec2-metadata-token-ttl-seconds: 21600\")' >> ~/.bashrc",
      "echo 'export AWS_DEFAULT_AZ=$(curl -H \"X-aws-ec2-metadata-token: $token\" -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .availabilityZone)' >> ~/.bashrc",
      "echo 'export AWS_DEFAULT_REGION=$(curl -H \"X-aws-ec2-metadata-token: $token\" -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)' >> ~/.bashrc",
      "echo 'aws configure set default.region $AWS_DEFAULT_REGION' >> ~/.bashrc",
      # set message of the day
      "sudo bash -c 'echo \"Welcome IDSeq on call user!\nIf you need help check out /home/ubuntu/README.md\" > /etc/motd'",
    ]
  }
}
