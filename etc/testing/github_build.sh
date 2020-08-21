#!/bin/bash

set -ex

# TODO: On travis we skip this step if we're running from a public fork (based
# on $TRAVIS_SECURE_ENV_VARS var). Need to replicate that if we want to support
# GitHub Actions with public forks (using their infra, not ours for that case
# hopefully to sidestep security concerns).

docker login -u pachydermbuildbot -p "${DOCKER_PWD}"
make install docker-build
version=$(pachctl version --client-only)
docker tag "pachyderm/pachd:local" "pachyderm/pachd:${version}"
docker push "pachyderm/pachd:${version}"
docker tag "pachyderm/worker:local" "pachyderm/worker:${version}"
docker push "pachyderm/worker:${version}"

# Push pipeline build images
make docker-push-pipeline-build
