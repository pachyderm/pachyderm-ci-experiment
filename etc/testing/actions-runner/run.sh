#!/bin/bash
set -euo pipefail
if [ ! -f .env ]; then
    echo "Please put something like this in your .env file"
    echo
    echo "GH_REPOSITORY=https://github.com/<org>/<repo>"
    echo "GH_RUNNER_TOKEN=<token from https://github.com/<org>/<repo>/settings/actions/add-new-runner>"
    echo "GH_RUNNER_REPLICAS=12"
    echo
    exit 1
fi
docker-compose up -d
set -o allexport; source .env; set +o allexport
if [ "$GH_RUNNER_REPLICAS" != "" ]; then
    docker-compose scale runner=$GH_RUNNER_REPLICAS
fi
