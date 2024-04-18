#!/bin/bash
function get_auth_string() {
  uri=$1

  if [ -z "$uri" ]; then
    echo "Usage: get_auth_string <uri>" >&2
    return 1
  fi

  # Remove anything after the last '/' in the uri
  num_forward_slashes=$(grep -o '/' <<<"$uri" | grep -c .)
  if [ $num_forward_slashes -gt 2 ]; then
    uri="${uri%/*}"
  fi

  # Get user token from az cli
  echo "Getting Access token to $uri" >&2
  token=$(az account get-access-token --resource=$uri --query accessToken --output tsv)

  if [ -z "$token" ]; then
    echo "Failed to get access token" >&2
    return 1
  fi

  auth="Fed=true;AppToken=$token;"

  echo "$auth"
}

function execute_script() {
  script_fullpath=$1
  connectionString=$2

  if [ -z "$script_fullpath" ] || [ -z "$connectionString" ]; then
    echo "Usage: execute_script <script_fullpath> <connectionString>" >&2
    return 1
  fi

  if [ -z "$KUSTO_CLI_PATH" ]; then
    echo "KUSTO_CLI_PATH environment variable is not set" >&2
    return 1
  fi

  echo "Executing script: $script_fullpath" >&2
  echo "HERE"
  dotnet $KUSTO_CLI_PATH "$connectionString" \
    -execute:"#blockmode" \
    -execute:"#save output.out" \
    -execute:"#script $script_fullpath"
  echo "THERE"
  ls
  cat output.out
}
set -e

## Path to this script
#DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

#source "$DIR/functions.sh"

while getopts s:u: flag; do
    case "${flag}" in
    s) script_relativepath=${OPTARG} ;;
    u) uri=${OPTARG} ;;
    esac
done

if [ -z "$KUSTO_CLI_PATH" ]; then
    echo "KUSTO_CLI_PATH is not set"
    exit 1
fi

auth=$(get_auth_string $uri $tenant)
connectionString="$uri;$auth"

echo "Connection string: $connectionString"

if [ ! -z "$script_relativepath" ]; then
    script_fullpath="$GITHUB_WORKSPACE/$script_relativepath"
    result=$(execute_script "$script_fullpath" "$connectionString")
else
    echo "No script provided"
    exit 1
fi

echo "result=<<EOF" >> $GITHUB_OUTPUT
cat output.out >> $GITHUB_OUTPUT
echo "EOF" >> $GITHUB_OUTPUT