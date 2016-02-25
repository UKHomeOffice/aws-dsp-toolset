#!/usr/bin/bash

set -o errexit
set -o pipefail

kms_master_key_id=$(cd stacks ; stacks config -e ${STACKS_ENV} kms_master_key_id)

s3secrets kms encrypt -k ${kms_master_key_id} stacks/config.d/secrets.yaml
cat stacks/config.d/secrets.yaml.encrypted | base64 > stacks/config.d/secrets.yaml.enc && \
  rm stacks/config.d/secrets.yaml.encrypted
