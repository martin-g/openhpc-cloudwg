---
title: Exercise 1
layout: default
parent: SC 2020 Tutorial
nav_order: 3
---


# Exercise 1: AWS and OpenHPC
## Setting up your AWS (Amazon Web Services) account and building OpenHPC Amazon Machine Images (AMI) (30 mins)


In this exercise, we will configure our AWS account and build an Amazon Machine Image (AMI). 
In order to begin following along, you need to first follow the directions on the [Getting Started](getting-started.html) page in 
the [Personal AWS cluster from scratch](getting-started.html#personal-aws-cluster-from-scratch) section or be running an [EventEngine tutorial cluster](getting-started.html#eventengine-tutorial-cluster). 

You will need:

* An EC2 instance with [packer](https://packer.io) installed (or packer installed locally)
* Your ee-default-keypair (packer-sc20 if personal cluster) private key 


If you are missing any of the above, please return to the [Getting Started](getting-started.html) page.


### Preparing to build the AMI

* Log into your EC2 packer building instance (this was automatically created if using EventEngine)
  * Services > EC2 > Instances > Right click instance > Connect > SSH client > copy ssh command example
  * SSH into packer builder

~~~console
$ ssh -i "ee-default-keypair.pem" centos@ecx-xx-xxx-xxx-xxx.us-east-1.compute.amazonaws.com
~~~

* Set your AWS API keys

~~~console
$ export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE # use your AWS_ACCESS_KEY
$ export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY # use your AWS_SECRET_ACCESS_KEY
$ export AWS_DEFAULT_REGION=us-east-1
~~~

* If you are using an EventEngine account, also set your AWS_SESSION_TOKEN

~~~console
$ export AWS_SESSION_TOKEN=IQoJb3JpZ2luX2VjEJ3//////////wEaCXVzLWVhc3QtMSJHMEUCIG7pNhU9MREozHRR8xccBiSyOe9uW1pNAbTONkCnxyQ4AiEA6jcpzZQD8gLN84+6Y/2fUIfmT7kbFZLEjvm0i6tYrL4qoAII9v//////////ARABGgw5MzAwMTcwNDE3ODMiDJNZVNzJsnTb23a3OSr0AebUmrjYXazdkzVLYCqDIsMfRsz8xMcysNpLteslZhe+5iUspmNcMGI9dDsCqTdy1cVoOyZRXjzAFTFlvTyjAi4QLGBFi04xInvzMAjIr5ZqGm+oVrvWxy0UU6v2fAaN0MH8QLchfL93Nrp7OF8Qmg5hZAsQE7FT0xtXvv96zjqzWAOtNELtz8zSl+41i0/1ev5SOJ1NQjrbS09ZEnfmL16aaelutVjHuK+1YrUi+Bo2crAru8PakJL6kR3+kOTniOG1Gl+EpUcyx70+k61kVM2f+6VRJ5ORiybtHUkknzit/YgVL3oIJ9d4CQv1YIa5wfgY3CgwkcyR/QU6nQElm5DSJRrbsRL/lt/lKIiOmlpDDT+JMCsPdifQP8yQr3D9hE1Kvv9GVpNALME79tiXH4IZZ8veMIddw9RCjl64v02Wm7BF/8+aYs3EWkAipJiVQpliBp416iY+aRAG1C8IG4UCB68+soouV5+HTjKyAPoZ2kJFcJnOfBIzrA+xAU8NAaw6FoiT+TyvzEnVGrdNvsLzEXAMPLETOKEN
~~~

*Note: You do not have to set the SESSION TOKEN if you are using a personal AWS account*

* Download the tutorial content tarball and extract it.

TODO: mgrigorov: Provide an updated ohpc-sc20-tutorial.tar.gz !

~~~console
$ cd ~
$ wget -c https://github.com/utdsimmons/sc2020/raw/master/ohpc-sc20-tutorial.tar.gz -O - | tar -xz
~~~

The remainder of this tutorial assumes you extracted the tarball into ~ and you'll be working in ~/SC20



### Building the AMIs

In a typical OpenHPC cloud installation, the first thing we'd do is build two AMIs, one for the controller node (master) and
one for the login and compute nodes. However, the controller node AMI build takes 30+ minutes.
So, we will build our own login / compute node AMI and use a public controller node AMI published by the OpenHPC project.

To do this, we will be using [Packer](https://www.packer.io/) from [Hashicorp](https://www.hashicorp.com/). 

*Note: The packer yaml and shell script needed to build the controller AMI is available in the tutorial tarball for your reference.*

#### Build the compute AMI

~~~console
$ cd ~/SC20/packer-templates/compute
$ packer build compute.yml
~~~

*Note: The AMI hash is returned to standard output as the last line of the `packer build` command. It is also available from the EC2 console: Services -> EC2 -> AMIs*

##### compute.yaml
~~~yaml
{
  "variables": {
    "aws_access_key": "",
    "aws_secret_key": ""
  },
  "builders": [{
    "type": "amazon-ebs",
    "access_key": "{{user `aws_access_key`}}",
    "secret_key": "{{user `aws_secret_key`}}",
    "instance_type": "t3.micro",
    "region": "eu-north-1",
    "source_ami": "ami-0d8da681c21f3581d",
    "ssh_username": "openeuler",
    "ami_name": "openhpc-compute-{{timestamp}}",
    "launch_block_device_mappings": [
    {
      "device_name": "/dev/sda1",
      "volume_size": 10,
      "volume_type": "gp2",
      "delete_on_termination": true
    }]
  }],

  "provisioners": [{
    "type": "shell",
    "script": "compute_packages.sh",
    "execute_command": "chmod +x {{ .Path }}; sudo {{ .Vars }} {{ .Path }}"
  }]
}
~~~

##### compute_packages.sh
~~~bash
#!/bin/bash

dnf install -y http://repos.openhpc.community/OpenHPC/3/openEuler_22.03/aarch64/ohpc-release-3-1.oe2203.aarch64.rpm
dnf update -y 
dnf install -y ohpc-base
dnf install -y ohpc-release
dnf install -y ohpc-slurm-client
dnf install -y wget curl python3-pip jq git make nfs-utils libnfs
dnf install -y zip vim

# adding for mpich support
dnf install -y librdmacm libpsm2
~~~

#### Build the controller AMI

~~~console
$ export AWS_MAX_ATTEMPTS=60
$ export AWS_POLL_DELAY_SECONDS=60
$ cd ~/SC20/packer-templates/controller
$ packer build controller.yml
~~~

##### controller.yaml
~~~yaml
{
  "variables": {
    "aws_access_key": "",
    "aws_secret_key": ""
  },
  "builders": [{
    "type": "amazon-ebs",
    "access_key": "{{user `aws_access_key`}}",
    "secret_key": "{{user `aws_secret_key`}}",
    "instance_type": "t3.micro",
    "region": "eu-north-1",
    "source_ami": "ami-0d8da681c21f3581d",
    "ssh_username": "openeuler",
    "ami_name": "openhpc-controller-{{timestamp}}",
    "launch_block_device_mappings": [
    {
      "device_name": "/dev/sda1",
      "volume_size": 170,
      "volume_type": "gp2",
      "delete_on_termination": true
    }]
  }],

  "provisioners": [{
    "type": "shell",
    "script": "controller_packages.sh",
    "execute_command": "chmod +x {{ .Path }}; sudo {{ .Vars }} {{ .Path }}"
  }]
}
~~~

##### controller_packages.sh
~~~bash
#!/bin/bash

dnf install -y http://repos.openhpc.community/OpenHPC/3/openEuler_22.03/aarch64/ohpc-release-3-1.oe2203.aarch64.rpm
dnf update -y 

dnf install -y ohpc-base
dnf install -y ohpc-release
dnf install -y ohpc-slurm-server
dnf install -y lmod-ohpc

# dev packages
dnf install -y ohpc-autotools
dnf install -y EasyBuild-ohpc
dnf install -y hwloc-ohpc
dnf install -y spack-ohpc
dnf install -y valgrind-ohpc

# gnu12 serial/threaded packages
dnf install -y ohpc-gnu12-serial-libs
dnf install -y ohpc-gnu12-runtimes
dnf install -y hdf5-gnu12-ohpc

# install gnu12/mpich and gnu12/openmpi package variants
dnf install -y openmpi4-gnu12-ohpc mpich-ofi-gnu12-ohpc mpich-ucx-gnu12-ohpc
dnf install -y ohpc-gnu12-mpich* ohpc-gnu12-openmpi4*
dnf install -y lmod-defaults-gnu12-mpich-ofi-ohpc
dnf install -y wget curl python3-pip jq git make nfs-utils

pip3 install awscli

# basic utils and parallel python
dnf install -y zip vim
dnf install -y python3-mpi4py-gnu12-mpich-ohpc python3-mpi4py-gnu12-openmpi4-ohpc python3-numpy-gnu12-ohpc python3-scipy-gnu12-mpich-ohpc python3-scipy-gnu12-openmpi4-ohpc

# grab podman and docker interface to run optional from scratch without docker locally
dnf install -y podman-docker

# increase S3 performance
cat <<-EOF | install -D /dev/stdin /root/.aws/config
[default]
s3 =
    max_concurrent_requests = 100
    max_queue_size = 1000
    multipart_threshold = 256MB
    multipart_chunksize = 128MB
EOF
# prebake tutorial content
# TODO: mgrigorov: Disabled because it is too big for the Free Tier AWS instance ... :-/
# /usr/local/bin/aws s3 cp s3://ohpc-sc20-tutorial/ContainersHPC-v7.tar.gz - --no-sign-request | tar xz -C /home/openeuler
~~~


**Once your packer builder is done you may continue to [Exercise 2](exercise2.html).**
