#!/usr/bin/bash

set -o errexit
set -o pipefail

kms_master_key_id=$(cd stacks ; stacks config kms_master_key_id)

secrets_file_enc="stacks/config.d/secrets_${STACKS_ENV}.yaml.enc"
secrets_tmp_enc="${secrets_file_enc}rypted"
secrets_file="stacks/config.d/secrets_${STACKS_ENV}.yaml"

if [[ -f "${secrets_file}" ]]; then
  aws kms encrypt \
    --key-id ${kms_master_key_id} \
    --plaintext fileb://${secrets_file} \
    --query CiphertextBlob \
    --output text > ${secrets_file_enc}
fi
