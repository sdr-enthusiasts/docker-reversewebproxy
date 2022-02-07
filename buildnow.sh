#!/bin/bash
#
set -x

[[ "$1" != "" ]] && BRANCH="$1" || BRANCH=main
[[ "$BRANCH" == "main" ]] && TAG="latest" || TAG="$BRANCH"
[[ "$ARCHS" == "" ]] && ARCHS="linux/armhf,linux/arm64,linux/amd64,linux/i386"

IMAGE=kx1t/$(pwd | sed -n 's|.*/docker-\(.*\)|\1|p'):$TAG
echo "press enter to start building $IMAGE from $BRANCH"
read

# rebuild the container
pushd ~/git/docker-planefence-notifier
git checkout $BRANCH || exit 2

git pull -a
docker buildx build --progress=plain --compress --push $2 --platform $ARCHS --tag $IMAGE .
popd
