#!/usr/bin/env bash

#// https://github.com/open-toolchain/sdk/wiki/Toolchain-Creation-page-parameters#headless-toolchain-creation-and-update

# log in using the api key
ibmcloud login --apikey "$API_KEY" -r "$REGION" -g "$RESOURCE_GROUP"

# get the bearer token to create the toolchain instance
IAM_TOKEN="IAM token:  "
BEARER_TOKEN=$(ibmcloud iam oauth-tokens | grep "$IAM_TOKEN" | sed -e "s/^$IAM_TOKEN//")
#echo $BEARER_TOKEN

# prefix region for toolchains
TOOLCHAIN_REGION=$REGION
if [[ ! $TOOLCHAIN_REGION =~ "ibm:" ]]; then
  export TOOLCHAIN_REGION="ibm:yp:$REGION"
fi

RESOURCE_GROUP_ID=$(ibmcloud resource group $RESOURCE_GROUP --output JSON | jq ".[].id" -r)

# check for the existence of the Secrets Manager instance
SM_FOUND=$(ibmcloud resource service-instances | grep "$SM_SERVICE_NAME")
if [[ $SM_FOUND ]]; then
  echo "Secrets Manager '$SM_SERVICE_NAME' already exists."
else
  echo "Secrets Manager '$SM_SERVICE_NAME' does not exist."
  echo "Creating Secrets Manager service now..."
  # NOTE: Secrets Manager service can take approx 5-8 minutes to provision
  ibmcloud resource service-instance-create $SM_SERVICE_NAME secrets-manager lite $REGION
  wait_secs=600
  count=0
  sleep_time=60
  wait_mins=$(($wait_secs / $sleep_time))
  echo "Waiting up to $wait_mins minutes for Secrets Manager service to provision..."
  while [[ $count -le $wait_secs ]]; do
    ibmcloud resource service-instances >services.txt
    secretLine=$(cat services.txt | grep $SM_SERVICE_NAME)
    stringArray=($secretLine)
    if [[ "${stringArray[2]}" != "active" ]]; then
      echo "Secrets Manager status: ${stringArray[2]}"
      count=$(($count + $sleep_time))
      if [[ $count -gt $wait_secs ]]; then
        echo "Secrets Manager service took longer than $wait_mins minutes to provision."
        echo "You might have to re-configure this integration in the toolchain once the service finally provisions."
      else
        echo "Waiting $sleep_time seconds to check again..."
        sleep $sleep_time
      fi
    else
      echo "Secrets Manager successfully provisioned"
      echo "Status: ${stringArray[2]}"
      break
    fi
  done
fi

# generate gpg key
gpg --batch --pinentry-mode loopback --generate-key <<EOF
%no-protection
Key-Type: 1
Key-Length: 2048
Subkey-Type: 1
Subkey-Length: 2048
Name-Real: Root User
Name-Email: root@cipipeline.ibm.com
Expire-Date: 0
EOF
export GPG_SECRET=$(gpg --export-secret-key root@cipipeline.ibm.com  | base64)
gpg --export-secret-key root@cipipeline.ibm.com  | base64 > privatekey.txt

# get secrets manager instance id
IN=$(ibmcloud resource service-instance "$SM_SERVICE_NAME" | grep crn)
IFS=':' read -ra ADDR <<< "$IN"
SM_INSTANCE_ID="${ADDR[8]}"

# get secrets data for API, GPG, and COS API keys
SECRETS_NAMES=("IAM_API_Key" "GPG_Key" "COS_API_Key")
SECRETS_PAYLOADS=("$API_KEY" "$GPG_SECRET" "$COS_API_KEY")

# loop through secrets names and create secrets for each in the secrets manager
for i in ${!SECRETS_NAMES[@]}; do
  echo "Creating Arbitrary secret for ${SECRETS_NAMES[$i]} in $SM_SERVICE_NAME..."
  REQUEST_BODY=$( jq -n \
    --arg sn "${SECRETS_NAMES[$i]}" \
    --arg sp "${SECRETS_PAYLOADS[$i]}" \
    '{metadata: {collection_type: "application/vnd.ibm.secrets-manager.secret+json", collection_total: 1}, resources: [{name: $sn, payload: $sp}]}' )
  RESPONSE=$(curl --write-out '%{http_code}' --silent --output /dev/null -i -X POST \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "Authorization: $BEARER_TOKEN" \
    -d "$REQUEST_BODY" \
    "https://$SM_INSTANCE_ID.$REGION.secrets-manager.appdomain.cloud/api/v1/secrets/arbitrary")
  if [[ "$RESPONSE" =~ ^2 ]]; then
    echo "The secret was successfully created."
  else
    echo "The secret failed to be created."
    case $RESPONSE in
      400)
        echo "Status Code: 400 Bad Request"
	      ;;
      401)
        echo "Status Code: 401 Unauthorized"
	      ;;
      403)
        echo "Status Code: 403 Forbidden"
	      ;;
      409)
        echo "Status Code: 409 Secret Already Exists"
	      ;;
      429)
        echo "Status Code: 429 Too Many Requests"
	      ;;
      *)
	      echo "Status Code: $RESPONSE Unknown"
	      ;;
    esac
  fi
done

# URL encode VAULT_SECRET, TOOLCHAIN_TEMPLATE_REPO, APPLICATION_REPO, API_KEY, and COS_API_KEY
#export VAULT_SECRET=$(echo "$VAULT_SECRET" | jq -sRr @uri)  # added -s (slurp) option due to multiple lines
export TOOLCHAIN_TEMPLATE_REPO=$(echo "$TOOLCHAIN_TEMPLATE_REPO" | jq -Rr @uri)
export APPLICATION_REPO=$(echo "$APPLICATION_REPO" | jq -Rr @uri)
export API_KEY=$(echo "$API_KEY" | jq -Rr @uri)
export appName=$APP_NAME
export COS_API_KEY=$(echo "$COS_API_KEY" | jq -Rr @uri)

# create parameters for headless toolchain
PARAMETERS="autocreate=true&appName=$APP_NAME&apiKey=$API_KEY"`
`"&repository=$TOOLCHAIN_TEMPLATE_REPO&repository_token=$GITLAB_TOKEN&branch=$BRANCH"`
`"&sourceRepoUrl=$APPLICATION_REPO&resourceGroupId=$RESOURCE_GROUP_ID"`
`"&registryRegion=$TOOLCHAIN_REGION&registryNamespace=$REGISTRY_NAMESPACE&devRegion=$REGION"`
`"&devResourceGroup=$RESOURCE_GROUP&devClusterName=$CLUSTER_NAME&devClusterNamespace=$CLUSTER_NAMESPACE"`
`"&toolchainName=$TOOLCHAIN_NAME&pipeline_type=$PIPELINE_TYPE&gitToken=$GITLAB_TOKEN"`
`"&cosBucketName=$COS_BUCKET_NAME&cosEndpoint=$COS_URL&cosApiKey=$COS_API_KEY"`
`"&smName=$SM_NAME&smRegion=$TOOLCHAIN_REGION&smResourceGroup=$RESOURCE_GROUP&smInstanceName=$SM_SERVICE_NAME"

# debugging
echo "Here are the parameters:"
echo "$PARAMETERS"

# create headless toolchain
RESPONSE=$(curl -i -X POST \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'Accept: application/json' \
  -H "Authorization: $BEARER_TOKEN" \
  --data-binary vaultSecret@privatekey.txt \
  -d "$PARAMETERS" \
  "https://cloud.ibm.com/devops/setup/deploy?env_id=$TOOLCHAIN_REGION&repository=$TOOLCHAIN_TEMPLATE_REPO&branch=$BRANCH")

echo "$RESPONSE"
LOCATION=$(grep location <<<"$RESPONSE" | awk {'print $2'})
echo "View the toolchain at: $LOCATION"

exit 0;
