#!/bin/bash

export SLURM_HEADNODE_IPADDR=$(curl -sS http://169.254.169.254/latest/meta-data/local-ipv4)
export SLURM_HEADNODE_AWS_REGION=$(curl -sS http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
export COMPUTE_SG=@COMPUTESG@
export COMPUTE_PROFILE=@PROFILE@
export COMPUTE_SUBNET_ID_1=@SUBNETID1@
export COMPUTE_SUBNET_ID_2=@SUBNETID2@
export COMPUTE_SUBNET_ID_3=@SUBNETID3@
export AWS_DEFAULT_MAC=$(curl -sS http://169.254.169.254/latest/meta-data/mac)
export AWS_SECURITY=$(curl -sS http://169.254.169.254/latest/meta-data/network/interfaces/macs/$AWS_DEFAULT_MAC/security-group-ids)
export AWS_AMI=@BASEAMI@
export AWS_KEYNAME=@KEYNAME@
export S3BUCKET=@S3BUCKET@
export SLURM_ROOT=/cluster/slurm
export SLURM_POWER_LOG=$SLURM_ROOT/power_save.log

function c5_singlenode_allzones()
{
    NODE_JSON=$(mktemp)

    aws ec2 run-instances --image-id $AWS_AMI \
                          --instance-type c5.24xlarge \
                          --key-name $AWS_KEYNAME \
                          --security-group-ids "$COMPUTE_SG" \
                          --subnet-id "$2" \
                          --iam-instance-profile Name=$COMPUTE_PROFILE \
                          --user-data file://$SLURM_ROOT/bin/slurm-compute.sh \
                          --region $SLURM_HEADNODE_AWS_REGION \
                          --cpu-options "CoreCount=48,ThreadsPerCore=1" \
                          --instance-market-options '{"MarketType":"spot"}' \
                          --block-device-mappings \
                            '[
                              {
                               "DeviceName":"/dev/sda1",
                               "Ebs": {
                                       "DeleteOnTermination": true,
                                       "VolumeSize": 340
                                      }
                              }
                             ]' \
                          --tag-specifications \
                            "ResourceType=instance,Tags= \
                              [{Key=Name,Value=SLURM-Compute},
                               {Key=SlurmLabel,Value=$1}]" \
    |& tee $NODE_JSON >> $SLURM_POWER_LOG
}

export SLURM_ROOT=/cluster/slurm
echo "`date` Resume invoked $0 $*" >> $SLURM_POWER_LOG
hosts=$($SLURM_ROOT/bin/scontrol show hostnames $1)
num_hosts=$(echo "$hosts" | wc -l)
for host in $hosts
do
  if [[ $host == *z1 ]]; then
  c5_singlenode_allzones $host $COMPUTE_SUBNET_ID_1
  elif [[ $host == *z2 ]]; then
  c5_singlenode_allzones $host $COMPUTE_SUBNET_ID_2
  elif [[ $host == *z3 ]]; then
  c5_singlenode_allzones $host $COMPUTE_SUBNET_ID_3
  fi
  export private_ip=$(jq '.Instances[0].PrivateIpAddress' $NODE_JSON | tr -d '"')
  $SLURM_ROOT/bin/scontrol update nodename=$host nodeaddr=$private_ip
  rm -rf $NODE_JSON
done
