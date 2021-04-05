#!/bin/bash
#
set -x

[[ "$1" != "" ]] && BRANCH="$1" || BRANCH=main
[[ "$BRANCH" == "main" ]] && TAG="latest" || TAG="$BRANCH"

# rebuild the container
pushd ~/git/docker-reversewebproxy
git checkout $BRANCH || exit 2

git pull
docker buildx build --compress --push $2 --platform linux/armhf,linux/arm64 --tag kx1t/webproxy:$TAG .
popd
