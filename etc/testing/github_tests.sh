#!/bin/bash

set -xeuo pipefail

# In case we're retrying on a new cluster
rm -f "${HOME}"/.pachyderm/config.json

# Get a kubernetes cluster
# Specify the slot so that future builds on this branch+suite id automatically
# clean up previous VMs
BRANCH="${CIRCLE_BRANCH:-$GITHUB_REF}"
DEBUG_WEBSOCKETS=1 testctl get --config .testfaster.yml --slot "${BRANCH},${BUCKET}"

KUBECONFIG="$(pwd)/kubeconfig"
export KUBECONFIG

echo "ENT_ACT_CODE=${ENT_ACT_CODE}"
echo "decoded:"
echo "$ENT_ACT_CODE" |base64 -d | jq .

# [x]: get docker image over there (well, we did already)
# we assume 'make docker-build' has been done by a previous build step. see .circleci/config.yml

# [ ]: send files across TODO: make this use rsync --delete
./etc/testing/testctl-scp.sh . /root/

# [ ]: get pachctl binary over there
./etc/testing/testctl-scp.sh $(which pachctl) /usr/local/bin/pachctl

# [x]: pass environment variables through, at least ENT_ACT_CODE, BUCKET
# [x]: pass arguments over
./etc/testing/testctl-ssh.sh \
    -o SendEnv=ENT_ACT_CODE \
    -o SendEnv=BUCKET \
    -- ./etc/testing/github_tests_inner.sh "$@"

