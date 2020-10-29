#!/bin/bash

set -xeuo pipefail

# In case we're retrying on a new cluster
rm -f "${HOME}"/.pachyderm/config.json

# Get a kubernetes cluster
echo before
ls -alh

# Specify the slot so that future builds on this branch+suite id automatically
# clean up previous VMs
testctl get --config .testfaster.yml --slot "${CIRCLE_BRANCH},${BUCKET}"

echo after
ls -alh

KUBECONFIG="$(pwd)/kubeconfig"
export KUBECONFIG

# TODO: replace this with `testctl ip`
#VM_IP=$(grep server kubeconfig |cut -d ':' -f 3 |sed 's/\/\///')
#export VM_IP

kubectl version

echo "Running test suite based on BUCKET=$BUCKET"

# TODO: Like github_build.sh, need to handle the external PR case as well.
# Previous code for this was as follows, which suggests we might need a way to
# push docker images to the testfaster VM. Which we can do now via `testctl
# ssh`!
#
#    make docker-build
#    # push pipeline build images
#    pushd etc/pipeline-build
#        make push-to-minikube
#    popd

# XXX :local tag will collide with other concurrent tests running on the same
# github actions runner

#make install
#version=$(pachctl version --client-only)
#docker pull "pachyderm/pachd:${version}"
#docker tag "pachyderm/pachd:${version}" "pachyderm/pachd:local"
#docker pull "pachyderm/worker:${version}"
#docker tag "pachyderm/worker:${version}" "pachyderm/worker:local"

# we assume 'make docker-build' has been done by a previous build step. see .circleci/config.yml
#make docker-build
for X in worker pachd; do
    echo "Copying pachyderm/$X:local to kube"
    docker save pachyderm/$X:local |gzip | pv | testctl ssh --tty=false -- sh -c 'gzip -d | docker load'
done
make launch-dev

# should be able to connect to pachyderm via KUBECONFIG
pachctl version

#pachctl config update context "$(pachctl config get active-context)" --pachd-address="$VM_IP:30650"

function test_bucket {
    set +x
    package="${1}"
    target="${2}"
    bucket_num="${3}"
    num_buckets="${4}"
    if (( bucket_num == 0 )); then
        echo "Error: bucket_num should be > 0, but was 0" >/dev/stderr
        exit 1
    fi

    echo "Running bucket $bucket_num of $num_buckets"
    # shellcheck disable=SC2207
    tests=( $(go test -v  "${package}" -list ".*" | grep -v '^ok' | grep -v '^Benchmark') )
    total_tests="${#tests[@]}"
    # Determine the offset and length of the sub-array of tests we want to run
    # The last bucket may have a few extra tests, to accommodate rounding
    # errors from bucketing:
    let "bucket_size=total_tests/num_buckets" \
        "start=bucket_size * (bucket_num-1)" \
        "bucket_size+=bucket_num < num_buckets ? 0 : total_tests%num_buckets"
    test_regex="$(IFS=\|; echo "${tests[*]:start:bucket_size}")"
    echo "Running ${bucket_size} tests of ${total_tests} total tests"
    make RUN="-run=\"${test_regex}\"" "${target}"
    set -x
}

# Clean cached test results
go clean -testcache

case "${BUCKET}" in
 MISC)
    make lint
    make enterprise-code-checkin-test
    make test-cmds
    make test-libs
    make test-proto-static
    make test-transaction
    make test-deploy-manifests
    make test-s3gateway-unit
    make test-enterprise
    make test-worker
    if [[ "$TRAVIS_SECURE_ENV_VARS" == "true" ]]; then
        # these tests require secure env vars to run, which aren't available
        # when the PR is coming from an outside contributor - so we just
        # disable them
        make test-tls
        make test-vault
    fi
    ;;
 ADMIN)
    make test-admin
    ;;
 EXAMPLES)
    echo "Running the example test suite"
    ./etc/testing/examples.sh
    ;;
 PFS)
    make test-pfs-server
    make test-pfs-storage
    ;;
 PPS?)
    pushd etc/testing/images/ubuntu_with_s3_clients
    make push-to-minikube
    popd
    make docker-build-kafka
    bucket_num="${BUCKET#PPS}"
    test_bucket "./src/server" test-pps "${bucket_num}" "${PPS_BUCKETS}"
    if [[ "${bucket_num}" -eq "${PPS_BUCKETS}" ]]; then
      go test -v -count=1 ./src/server/pps/server -timeout 3600s
    fi
    ;;
 AUTH?)
    bucket_num="${BUCKET#AUTH}"
    test_bucket "./src/server/auth/server/testing" test-auth "${bucket_num}" "${AUTH_BUCKETS}"
    set +x
    ;;
 *)
    echo "Unknown bucket"
    exit 1
    ;;
esac
