#!/bin/bash

set -xeuo pipefail

# In case we're retrying on a new cluster
rm -f "${HOME}"/.pachyderm/config.json

# Get a kubernetes cluster
# Specify the slot so that future builds on this branch+suite id automatically
# clean up previous VMs
BRANCH="${CIRCLE_BRANCH:-$GITHUB_REF}"
testctl get --config .testfaster.yml --slot "${BRANCH},${BUCKET}"

KUBECONFIG="$(pwd)/kubeconfig"
export KUBECONFIG

echo "ENT_ACT_CODE=${ENT_ACT_CODE}"
echo "decoded:"
echo "$ENT_ACT_CODE" |base64 -d | jq .

# [x]: get docker image over there (well, we did already)
# we assume 'make docker-build' has been done by a previous build step. see .circleci/config.yml

# [ ]: send files across TODO: make this use rsync --delete
./etc/testing/testctl-rsync.sh . /root/project

# [x]: pass environment variables through, at least ENT_ACT_CODE, BUCKET
# [x]: pass arguments over

# workaround https://serverfault.com/questions/482907/setting-a-variable-for-a-given-ssh-host

LC_ENT_ACT_CODE="$ENT_ACT_CODE"
export LC_ENT_ACT_CODE
LC_BUCKET="$BUCKET"
export LC_BUCKET

./etc/testing/testctl-ssh.sh \
    -o SendEnv=LC_ENT_ACT_CODE \
    -o SendEnv=LC_BUCKET \
    -- ./project/etc/testing/github_tests_inner.sh "$@"

