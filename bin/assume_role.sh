#!/usr/bin/bash
#
# Assume role is used to assume a role in another account via AWS STS
#

IDENTITY_FILE="/aws-dsp/scripts/.identity"
CREDENTIALS_FILE="${HOME}/.aws/credentials"
DEFAULT_ASSUMED_FILE="/tmp/.assumed_role.json"
DEFAULT_AWS_PROFILE="${DEFAULT_AWS_PROFILE:-"hod-central"}"
DEFAULT_CENTRAL_ACCOUNT_ID=$(cd stacks && stacks config aws_central_account_id)
DEFAULT_ACCOUNT_ID=$(cd stacks && stacks config aws_account_id)
DEFAULT_ROLE_PREFIX=${DEFAULT_ROLE_PREFIX:-"cross_role"}
DEFAULT_ROLE="restricted_admin"
DEFAULT_TTL="3600"

usage() {
  cat <<EOF
  Usage: $(basename $0)
  Description: is used to to acquire credentials in another account

  -r|--role         ROLE_NAME      : the role you wish to assume in the remote account (default: ${DEFAULT_ROLE})
  -A|--account      AWS_ID         : the AWS account id for the remote account you are assuming into (default: $DEFAULT_ACCOUNT_ID)
  -u|--username     USERNAME       : the username in the central account you are known as (no defaults)
  -i|--identity     PATH           : a path to a local cached identity file, used to store the above (default: ${IDENTITY_FILE})
  -t|--ttl          SECONDS        : the time in seconds a token should be granted for (default: ${DEFAULT_TTL})
  -T|--token        TOKEN          : the TOTP token for the associated mfa in the central
  -f|--file         PATH           : the file to write the assume role credentials to
    |--central-id   AWS_ID         : the AWS account id for the central account (default: $DEFAULT_CENTRAL_ACCOUNT_ID)
  -h|--help                        : display this usage menu
EOF
  if [[ -n "${@}" ]]; then
    echo "[error] $@"
    exit 1
  fi
  exit 0
}

# has_expired checks if a assumed role has expired
has_expired() {
  # if no expiration give, we assume expired
  [[ -z "${AWS_SESSION_EXPIRE}" ]] && return 1
  # if the session has expired
  [[ $(date -d "${AWS_SESSION_EXPIRE}" +%s) -lt $(date +%s) ]] && return 1
  return 0
}

# write_identity keeps a local copy of the identity to keep the cli reduce options
write_identity() {
  cat <<EOF > ${IDENTITY_FILE}
ASSUMED_USERNAME=${ASSUMED_USERNAME}
EOF
}

## assume_role is called to assume a role in another account i.e. from central to hod-dsp-{dev/prod}
assume_role() {
  echo "Attempting to assume role: ${ASSUMED_ROLE}, account: ${ASSUMED_ACCOUNT_ID}"
  # step: write current credentials out to a temporary file
  if [[ ! -f "${CREDENTIALS_FILE}" ]]; then
    mkdir -p "$(dirname ${CREDENTIALS_FILE})"
    cat <<EOF > ${CREDENTIALS_FILE}
[${DEFAULT_AWS_PROFILE}]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
region = ${AWS_DEFAULT_REGION}
EOF
  fi
  # step: grab the mfa token from the user
  if [[ -z "${ASSUMED_TOKEN}" ]]; then
    echo -n "Please enter you two-factor token from central account: "
    read ASSUMED_TOKEN
  fi
  # step: grab the token
  if aws --profile ${DEFAULT_AWS_PROFILE} \
    sts assume-role \
    --role-arn arn:aws:iam::${ASSUMED_ACCOUNT_ID}:role/${DEFAULT_ROLE_PREFIX}/${ASSUMED_ROLE} \
    --role-session-name ${ASSUMED_USERNAME}_${ASSUMED_ROLE} \
    --serial-number arn:aws:iam::${CENTRAL_ID}:mfa/${ASSUMED_USERNAME} \
    --duration-seconds ${ASSUMED_TTL} \
    --token-code ${ASSUMED_TOKEN} > ${DEFAULT_ASSUMED_FILE}; then
    # step: update the the credentials
    export AWS_ACCESS_KEY_ID="$(jq -r '.Credentials.AccessKeyId' ${DEFAULT_ASSUMED_FILE})"
    export AWS_SECRET_ACCESS_KEY="$(jq -r '.Credentials.SecretAccessKey' ${DEFAULT_ASSUMED_FILE})"
    export AWS_SECURITY_TOKEN="$(jq -r '.Credentials.SessionToken' ${DEFAULT_ASSUMED_FILE})"
    export AWS_SESSION_EXPIRE="$(jq -r '.Credentials.Expiration' ${DEFAULT_ASSUMED_FILE})"
    # step: delete the file
    rm -f ${DEFAULT_ASSUMED_FILE} 2>/dev/null
    ## write the credentials to a file if required
    if [[ -n "${ROLES_CREDENTIALS}" ]]; then
      cat <<EOF > ${ROLES_CREDENTIALS}
export AWS_SESSION_EXPIRE="${AWS_SESSION_EXPIRE}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export AWS_SECURITY_TOKEN="${AWS_SECURITY_TOKEN}"
export AWS_SESSION_TOKEN="${AWS_SECURITY_TOKEN}"
EOF
      echo "You can source the STS credentials from: ${ROLES_CREDENTIALS}"
    fi
  else
    usage "failed to assume the role: ${ASSUMED_ROLE}, account: ${ASSUMED_ACCOUNT_ID}"
  fi
}

## step: grab the command line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--role)        ASSUMED_ROLE=$2;        shift 2; ;;
    -A|--account)     ASSUMED_ACCOUNT_ID=$2;  shift 2; ;;
    -u|--username)    ASSUMED_USERNAME=$2;    shift 2; ;;
    -t|--ttl)         ASSUMED_TTL=$2;         shift 2; ;;
    -T|--token)       ASSUMED_TOKEN=$2;       shift 2; ;;
    -f|--file)        ROLES_CREDENTIALS=$2;   shift 2; ;;
    -i|--identity)    IDENTITY_FILE=$2;       shift 2; ;;
    --central-id)     CENTRAL_ID=$2;          shift 2; ;;
    -h|--help)        usage;                           ;;
    *)                shift;                           ;;
  esac
done

## step: set the defaults
ASSUMED_ROLE=${ASSUMED_ROLE:-$DEFAULT_ROLE}
ASSUMED_TTL=${ASSUMED_TTL:-$DEFAULT_TTL}
ASSUMED_ACCOUNT_ID=${ASSUMED_ACCOUNT_ID:-$DEFAULT_ACCOUNT_ID}
CENTRAL_ID=${CENTRAL_ID:-$DEFAULT_CENTRAL_ACCOUNT_ID}
ROLES_CREDENTIALS=${ROLES_CREDENTIALS:-$DEFAULT_ROLE_CREDENTIALS_FILE}

## step: source in any identity files
[[ -f "${IDENTITY_FILE}"      ]] && source "${IDENTITY_FILE}"
# step: ensure the options
[[ -z "${ASSUMED_ROLE}"       ]] && usage "you have not specified assumed role"
[[ -z "${ASSUMED_ACCOUNT_ID}" ]] && usage "you have specified the account id you wish to assume into"
[[ -z "${ASSUMED_TTL}"        ]] && usage "you have not specified a ttl for the sts"
[[ -z "${CENTRAL_ID}"         ]] && usage "you have not specified the central account id"

## step: check we have the user email address
if [[ -z "${ASSUMED_USERNAME}" ]]; then
  echo -n "Please enter your username in the central account: "
  read ASSUMED_USERNAME
  write_identity
fi

## step: check if the session has expired
if ! has_expired; then
  assume_role
fi
