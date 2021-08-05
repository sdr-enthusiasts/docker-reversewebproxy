#!/bin/bash
#
set -x

[[ "$1" != "" ]] && BRANCH="$1" || BRANCH=main
[[ "$BRANCH" == "main" ]] && TAG="latest" || TAG="$BRANCH"

# rebuild the container
pushd ~/git/docker-reversewebproxy
git checkout $BRANCH || exit 2

git pull

# make the build certs root_certs folder:
# Note that this is normally done as part of the github actions - we don't have those here, so we need to do it ourselves before building:
#ls -la /etc/ssl/certs/
mkdir -p ./root_certs/etc/ssl/certs
mkdir -p ./root_certs/usr/share/ca-certificates/mozilla
cp --no-dereference /etc/ssl/certs/*.crt ./root_certs/etc/ssl/certs
cp --no-dereference /etc/ssl/certs/*.pem ./root_certs/etc/ssl/certs
cp --no-dereference /usr/share/ca-certificates/mozilla/*.crt ./root_certs/usr/share/ca-certificates/mozilla

DOCKER_BUILDKIT=1 docker buildx build --progress=plain --compress --push $2 --platform linux/armhf,linux/arm64 --tag kx1t/webproxy:$TAG .

rm -rf ./root_certs
popd
