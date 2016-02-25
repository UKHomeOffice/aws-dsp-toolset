#!/usr/bin/bash

set -o errexit
set -o pipefail

# Get the master key id
kms_master_key_id=$(cd stacks ; stacks config -e ${STACKS_ENV} kms_master_key_id)

# Check if there is a secrets yaml and decode and make it available to stacks
secrets_file_enc="stacks/config.d/secrets.yaml.enc"
secrets_file="stacks/config.d/secrets.yaml"
if [[ -f ${secrets_file_enc} ]]; then
  DECODE_OUT=$(mktemp) || { echo "Failed to create tempfile ${DECODE_OUT}"; exit 1; }
  cat "${secrets_file_enc}" | base64 --decode > "${DECODE_OUT}"
  aws kms decrypt --ciphertext-blob "fileb://${DECODE_OUT}" --query Plaintext \
    --output text | base64 --decode > "${secrets_file}" && \
  rm "${secrets_file_enc}"
fi
