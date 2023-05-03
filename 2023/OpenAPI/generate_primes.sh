#!/usr/bin/env bash

docker run --rm -v "${PWD}:/local" \
    -u $(id -u ${USER}):$(id -g ${USER}) \
    openapitools/openapi-generator-cli generate \
    -i /local/specifications/primes.json \
    -g julia-client \
    -o /local/PrimesClient \
    --additional-properties=packageName=PrimesClient > /tmp/generate.out

docker run --rm -v "${PWD}:/local" \
    -u $(id -u ${USER}):$(id -g ${USER}) \
    openapitools/openapi-generator-cli generate \
    -i /local/specifications/primes.json \
    -g julia-server \
    -o /local/PrimesServer \
    --additional-properties=packageName=PrimesServer > /tmp/generate.out
