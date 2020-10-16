#!/usr/bin/env zsh

# Hook script for dns-01 challenge via GoDaddy API
#
# https://developer.godaddy.com/doc
# https://github.com/lukas2511/dehydrated/blob/master/docs/examples/hook.sh

set -e
set -u
set -o pipefail

if [[ -z "${GODADDY_KEY}" ]] || [[ -z "${GODADDY_SECRET}" ]]; then
  echo " - Unable to locate Godaddy credentials in the environment!  Make sure GODADDY_KEY and GODADDY_SECRET environment variables are set"
fi

# not this will return with a dot at the start if there is a subdomain, otherwise will be blank
get_subdomain() {
  local myvar=$1
  local myarray=("${(@s/./)myvar}")
  local SUBDOMAIN=''
  local NUM_LEFT=${#myarray[@]}

  #zsh arrays start at 1
  local index=1;
  while [ $NUM_LEFT -gt 2 ] 
  do
    SUBDOMAIN="${SUBDOMAIN}.${myarray[$index]}"
    index=$((index + 1))
    NUM_LEFT=$((NUM_LEFT - 1))
  done
  echo $SUBDOMAIN
}

deploy_challenge() {
  local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
  local SUBDOMAIN=`get_subdomain ${DOMAIN}`
  echo -n " - Setting TXT record with GoDaddy _acme-challenge.${DOMAIN}=${TOKEN_VALUE}"
  curl -X PUT https://api.godaddy.com/v1/domains/${DOMAIN}/records/TXT/_acme-challenge${SUBDOMAIN} \
    -H "Authorization: sso-key ${GODADDY_KEY}:${GODADDY_SECRET}" \
    -H "Content-Type: application/json" \
    -d "[{\"name\": \"_acme-challenge\", \"ttl\": 600, \"data\": \"${TOKEN_VALUE}\"}]"
  echo
  echo " - Waiting 30 seconds for DNS to propagate."
  sleep 30
}

clean_challenge() {
  local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"
    local SUBDOMAIN=`get_subdomain ${DOMAIN}`
  echo -n " - Removing TXT record from GoDaddy _acme-challenge.${DOMAIN}=--removed--"
  curl -X PUT https://api.godaddy.com/v1/domains/${DOMAIN}/records/TXT/_acme-challenge{SUBDOMAIN} \
    -H "Authorization: sso-key ${GODADDY_KEY}:${GODADDY_SECRET}" \
    -H "Content-Type: application/json" \
    -d "[{\"name\": \"_acme-challenge\", \"ttl\": 600, \"data\": \"--removed--\"}]"
  echo
}

deploy_cert() {
  local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}"
  echo "doing nothing with deploy_cert"
  echo "domain=$DOMAIN"
  echo "keyfile=$KEYFILE"
  echo "cerfile="$CERTFILE"
  echo "fullchainfile="$FULLCHAINFILE"
  echo "chainfile=$CHAINFILE"
  echo "timestamp=$TIMESTAMP"

}

unchanged_cert() {
  local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"
  echo "The $DOMAIN certificate is still valid and therefore wasn't reissued."
}

HANDLER="$1"; shift
if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|deploy_cert|unchanged_cert)$ ]]; then
  "$HANDLER" "$@"
fi
