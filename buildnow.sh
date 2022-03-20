#!/bin/bash
#
set -x

[[ "$1" != "" ]] && BRANCH="$1" || BRANCH=main
[[ "$BRANCH" == "main" ]] && TAG="latest" || TAG="$BRANCH"
[[ "$ARCHS" == "" ]] && ARCHS="linux/armhf,linux/arm64,linux/amd64,linux/i386"

BASETARGET=ghcr.io/sdr-enthusiasts
# BASETARGET=kx1t

IMAGE="$BASETARGET/$(pwd | sed -n 's|.*/docker-\(.*\)|\1|p'):$TAG"

[[ "$IMAGE" == "$BASETARGET/reversewebproxy:$TAG" ]] && IMAGE="$BASETARGET/webproxy:$TAG" || true

echo "press enter to start building $IMAGE from $BRANCH"
read

starttime="$(date +%s)"
# rebuild the container
git checkout $BRANCH || exit 2
git pull -a
docker buildx build --compress --push $2 --platform $ARCHS --tag $IMAGE .
echo "Total build time: $(( $(date +%s) - starttime )) seconds"
