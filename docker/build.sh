#!/bin/bash

DIR=$(realpath $(dirname "$0")/../)
mkdir -p $DIR/docker/build $DIR/docker/cache
docker buildx create --name e7db-diskmark --use
docker buildx build \
    --cache-from "type=local,src=$DIR/docker/cache" \
    --cache-to "type=local,dest=$DIR/docker/cache" \
    --file $DIR/Dockerfile \
    --metadata-file $DIR/docker/build/metadata.json \
    --output "type=registry" \
    --platform=linux/amd64,linux/arm/v7,linux/arm64/v8,linux/ppc64le,linux/s390x \
    --tag e7db/diskmark \
    $DIR
docker buildx rm e7db-diskmark
