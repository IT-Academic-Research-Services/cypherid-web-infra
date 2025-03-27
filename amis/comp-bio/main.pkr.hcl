source "amazon-ebs" "idseq-comp-bio" {
  ami_description = "AMI for running comp bio analysis on production data"
  ami_name        = "idseq-comp-bio"
  instance_type   = "m5.xlarge"
  region          = "us-west-2"

  tags = {
    name = "idseq-comp-bio",
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
    "gnupg-agent",
    "libasound2",
    "libbz2-dev",
    "libcurl4-openssl-dev",
    "libegl1-mesa",
    "libgl1-mesa-glx",
    "liblzma-dev",
    "libncurses5-dev",
    "libssl-dev",
    "libxcomposite1",
    "libxcursor1",
    "libxi6",
    "libxrandr2",
    "libxss1",
    "libxtst6",
    "openjdk-11-jdk",
    "python3-pip",
    "software-properties-common",
    "zlib1g-dev",
  ]

  pip_packages = [
    "aegea",
    "biopython",
    "ete3",
    "jupyterlab",
    "numpy",
    "pandas",
    "pysam",
    "scikit-learn miniwdl",
    "seaborn",
    "virtualenv",
  ]
}

build {
  sources = [
    "source.amazon-ebs.idseq-comp-bio"
  ]

  provisioner "file" {
    source      = "amis/comp-bio/downloads.cksums"
    destination = "/tmp/downloads.cksums"
  }
 
  # This script is not versioned so checking it's checksum will lead to breakages
  # Since it is being run in bash it should be manually inspected so a downloaded
  # version is kept here and uploaded manually. To get the latest version use:
  # curl https://get.nextflow.io -o get-nextflow.sh
  provisioner "file" {
    source      = "amis/comp-bio/get-nextflow.sh"
    destination = "/tmp/get-nextflow.sh"
  }

  provisioner "file" {
    source      = "amis/comp-bio/README.md"
    destination = "/home/ubuntu/"
  }

  provisioner "file" {
    source      = "amis/comp-bio/rootfs/home/ubuntu/"
    destination = "/home/ubuntu/"
  }

  provisioner "shell" {
    inline_shebang = "/bin/bash -ex"
    inline = [
      # wait for cloud-init script to end
      "sudo systemd-run --property='After=cloud-init.service apt-daily.service apt-daily-upgrade.service' --wait /bin/true",
      # install apt dependencies
      "sudo apt-get update && sudo apt-get install -y ${join(" ", local.apt_packages)}",
      # update pip
      "pip3 install -U pip",
      # install pip dependencies
      "pip3 install ${join(" ", local.pip_packages)}",
      "cd /tmp",
      # download files
      "curl https://repo.anaconda.com/archive/Anaconda3-2020.07-Linux-x86_64.sh -o Anaconda3-2020.07-Linux-x86_64.sh",
      "curl -L https://github.com/samtools/samtools/releases/download/1.11/samtools-1.11.tar.bz2 -o samtools-1.11.tar.bz2",
      "curl -L https://github.com/samtools/bcftools/releases/download/1.11/bcftools-1.11.tar.bz2 -o bcftools-1.11.tar.bz2",
      "curl -L https://github.com/samtools/htslib/releases/download/1.11/htslib-1.11.tar.bz2 -o htslib-1.11.tar.bz2",
      "curl -L https://github.com/lh3/minimap2/releases/download/v2.17/minimap2-2.17_x64-linux.tar.bz2 -o minimap2-2.17_x64-linux.tar.bz2",
      "curl https://data.broadinstitute.org/igv/projects/downloads/2.8/IGV_2.8.11.zip -o IGV_2.8.11.zip",
      "curl -L https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Linux-x86_64 -o docker-compose-Linux-x86_64",
      # verify download integrity
      "sha256sum --quiet -c downloads.cksums",
      # install htslib
      "tar -xjvf htslib-1.11.tar.bz2",
      "cd htslib-1.11 && ./configure --prefix=/usr/local/bin && make && sudo make install && cd ..",
      # install samtools
      "tar -xjvf samtools-1.11.tar.bz2",
      "cd samtools-1.11 && ./configure --prefix=/usr/local/bin && make && sudo make install && cd ..",
      # install bcftools
      "tar -xjvf bcftools-1.11.tar.bz2",
      "cd bcftools-1.11 && ./configure --prefix=/usr/local/bin && make && sudo make install && cd ..",
      # install anaconda
      "bash Anaconda3-2020.07-Linux-x86_64.sh -b",
      # install bowtie2
      "source ~/anaconda3/bin/activate",
      "conda init",
      "conda install -c bioconda bowtie2",
      # install minimap2
      "tar -jxvf minimap2-2.17_x64-linux.tar.bz2 minimap2-2.17_x64-linux/minimap2 && sudo mv minimap2-2.17_x64-linux/minimap2 /usr/local/bin/",
      # install igv
      "sudo unzip IGV_2.8.11.zip -d /opt",
      "echo 'PATH=\"$PATH:/opt/IGV_2.8.11\"' >> ~/.bashrc",
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
      "sudo bash -c 'echo \"Welcome IDSeq comp bio user!\nIf you need help check out /home/ubuntu/README.md\" > /etc/motd'",
    ]
  }
}
