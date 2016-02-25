#!/usr/bin/env bash

[[ ${DEBUG} == 'true' ]] && set -x

set -o errexit
set -o pipefail

function show_help() {
  echo ""
  echo "Usage: ${BASH_SOURCE[0]} vpc_cidr remote_profile remote_cidr [local_route_table_name remote_route_table_name]"
  echo ""
  echo "                 vpc_cidr = CIDR of the current AWS account"
  echo "           remote_profile = AWS profile name of the remote peer"
  echo "              remote_cidr = CIDR of the remote peer VPC network"
  echo ""
  echo "   local_route_table_name = Value for Name Tag of LOCAL route table"
  echo "  remote_route_table_name = Value for Name Tag of REMOTE route table"
  echo "Example: (assumes \"main\" route table is NOT used)"
  echo "  ${BASH_SOURCE[0]} 10.40.0.0/16 hod-vpn 10.99.0.0/16"
  echo "Example: (explicit route table names)"
  echo "  ${BASH_SOURCE[0]} 10.40.0.0/16 hod-vpn 10.99.0.0/16 ci-default-routetable dev-default-routetable"
  echo ""
}

function get_profile_opt() {
  profile_opt=""
  if [[ "${profile}" != "" ]]; then
    profile_opt=" --profile ${profile} "
  fi
}

function get_vpc_id() {
  cidr=$1
  profile=$2
  get_profile_opt

  echo "$(aws ${profile_opt} ec2 describe-vpcs | \
      jq -r ".Vpcs[]| select(.CidrBlock == \"${cidr}\") | .VpcId ")"

}

function get_route_table_id() {
  vpc_id=$1
  profile=$2
  route_table_name_tag=$3
  get_profile_opt

  if [[ -n ${route_table_name_tag} ]]; then
    rt_clause=".Tags[].Key == \"Name\" and .Tags[].Value == \"${route_table_name_tag}\""
  else
    rt_clause=".Associations[0].Main == false"
  fi
  echo "$(aws ${profile_opt} ec2 describe-route-tables | jq -r " \
      .RouteTables[] |
      select(.VpcId == \"${vpc_id}\" and ${rt_clause}) | .RouteTableId")"
}

function get_route_entry() {
  vpc_id=$1
  gateway_id=$2
  profile=$3
  get_profile_opt

  echo "$(aws ${profile_opt} ec2 describe-route-tables | jq -r "
        .RouteTables[] | select(.VpcId == \"${vpc_id}\") |
        .Routes[] |
        select(.VpcPeeringConnectionId == \"${gateway_id}\")")"
}

vpc_cidr=$1
remote_profile=$2
remote_cidr=$3
local_route_table_name=$4
remote_route_table_name=$5

if [[ ${1} == '--help' ]]; then
  show_help
  exit 0
fi

if [ -z "${vpc_cidr}" ] || [ -z "${remote_profile}" ] || [ -z "${remote_cidr}" ] ; then
  echo "ERROR: missing parameters..."
  show_help
  exit 1
fi

# Create the peering (this needs to test for it first)
remote_vpc_id=$(get_vpc_id ${remote_cidr} ${remote_profile})
local_vpc_id=$(get_vpc_id ${vpc_cidr})
[[ -n ${remote_vpc_id} ]]  || (echo "ERROR: can't find VpcId for ${vpc_cidr}"; exit 1)
[[ -n ${local_vpc_id}  ]]  || (echo "ERROR: can't find VpcId for ${remote_cidr}"; exit 1)

peering_account_id=$(aws --profile ${remote_profile} iam list-users | \
                     jq ".Users[0] | .Arn" | awk -F: '{print $5}')
[[ -n ${peering_account_id}  ]]  || (echo "ERROR: can't find peer account id for profile ${remote_profile}"; exit 1)

remote_peering_id=$(aws ec2 --profile ${remote_profile} describe-vpc-peering-connections | \
  jq -r ".VpcPeeringConnections[] |
         select(.Status.Code == \"active\") | \
         select( .AccepterVpcInfo.CidrBlock == \"${vpc_cidr}\" or .RequesterVpcInfo.CidrBlock == \"${vpc_cidr}\" ) | \
         .VpcPeeringConnectionId" )

echo "--- Updating peer ${local_vpc_id} with ${remote_profile} (${remote_vpc_id})..."
if [[ -n ${remote_peering_id} ]]; then
  echo "Peer exists already"

  # Get local vpc_peering_id's:
  vpc_peering_id=$(aws ec2 describe-vpc-peering-connections | \
    jq -r ".VpcPeeringConnections[]|
           select(.Status.Code == \"active\") |
           select(.AccepterVpcInfo.CidrBlock == \"${remote_cidr}\" or .RequesterVpcInfo.CidrBlock == \"${remote_cidr}\" ) |
           select(.AccepterVpcInfo.CidrBlock == \"${vpc_cidr}\" or .RequesterVpcInfo.CidrBlock == \"${vpc_cidr}\" ) |
           .VpcPeeringConnectionId")
  echo "--- Peering ID:$vpc_peering_id"
else
  echo "--- About to peer ${local_vpc_id} with ${remote_profile} (${remote_vpc_id})..."
  vpc_peering_id=$(aws ec2 create-vpc-peering-connection \
                   --vpc-id ${local_vpc_id} --peer-vpc-id ${remote_vpc_id} --peer-owner-id ${peering_account_id} | \
                   jq -r ".VpcPeeringConnection.VpcPeeringConnectionId")

  echo "--- Peering ID:${vpc_peering_id}..."
  remote_peering_id=$(aws ec2 \
                      --profile ${remote_profile} \
                      accept-vpc-peering-connection \
                      --vpc-peering-connection-id ${vpc_peering_id} | \
                      jq -r ".VpcPeeringConnection.VpcPeeringConnectionId")
fi

# Make sure routes exist already...
# Create the routing entries in LOCAL VPC:
local_route_table_id=$(get_route_table_id ${local_vpc_id} "" "${local_route_table_name}")
if [[ -n $(get_route_entry ${local_vpc_id} ${vpc_peering_id}) ]]; then
  echo "Local Route exists already"
else
  echo "--- Creating local route in ${local_vpc_id} to ${remote_cidr}..."
  aws ec2 \
    create-route \
    --route-table-id ${local_route_table_id} \
    --destination-cidr-block ${remote_cidr} --gateway-id ${vpc_peering_id} > /dev/null
fi
# Create the routing entries in REMOTE VPC:
remote_route_table_id=$(get_route_table_id ${remote_vpc_id} ${remote_profile} "${remote_route_table_name}")
echo "-- Remote route table id:${remote_route_table_id}"
if [[ -n $(get_route_entry ${remote_vpc_id} ${remote_peering_id} ${remote_profile}) ]]; then
  echo "Remote Route exists already"
else
  echo "--- Creating remote route in ${remote_vpc_id} to ${vpc_cidr}..."

  aws ec2 \
    --profile ${remote_profile} \
    create-route \
    --route-table-id ${remote_route_table_id} \
    --destination-cidr-block ${vpc_cidr} --gateway-id ${remote_peering_id} > /dev/null
fi
