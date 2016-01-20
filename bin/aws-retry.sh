#!/usr/bin/bash

function retry() {
  tries=0
  max_tries=3
  sleep_sec=1
  exit_code=256
  error=''

  until { error=$(${@} 2>&1 1>&${stdout}); } {stdout}>&1; do
    exit_code=$?

    tries=$(( ${tries} + 1 ))
    if [[ ${tries} -gt ${max_tries} ]]; then
      exit ${exit_code}
    fi

    if [[ ${exit_code} == 255 ]] && (echo "${error}" | grep -q 'RequestLimitExceeded'); then
      if [[ ${tries} != 1 ]]; then
        sleep ${sleep_sec}
      fi
      sleep_sec=$((${sleep_sec} * 2))
      echo "${error}" >&2
      echo 'Being throttled. Retrying..' >&2
    else
      echo "${error}" >&2
      exit ${exit_code}
    fi
  done
}

retry $@
