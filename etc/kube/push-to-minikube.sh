#!/bin/bash
# This script pushes docker images to the minikube vm so that they can be
# pulled/run by kubernetes pods

if [[ $# -ne 1 ]]; then
  echo "error: need the name of the docker image to push"
fi

command -v pv >/dev/null 2>&1 || { echo >&2 "Required command 'pv' not found. Run 'sudo apt-get install pv'."; exit 1; }

if [ -f /TESTFASTER_PREWARM_COMPLETE ]; then
    echo "Detected running in CI, nothing to do."
    exit 0
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if command -v testctl 2>/dev/null; then

    # Assume we're using testfaster if the testfaster CLI is installed.  In
    # which case, push the docker image in question onto the remote host via
    # 'testctl ssh'.
    docker save "${1}" | pv \
        | "${DIR}"/../testing/testctl-ssh.sh -- docker load

else
    # Detect if minikube was started with --vm-driver=none by inspecting the output
    # from 'minikube docker-env'
    if minikube docker-env \
        | grep -q "'none' driver does not support 'minikube docker-env' command"
    then
      exit 0 # Nothing to push -- vm-driver=none uses the system docker daemon
    fi

    docker save "${1}" | pv | (
      eval "$(minikube docker-env)"
      docker load
    )

fi


