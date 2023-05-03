#!/usr/bin/env bash

# Download spec from https://raw.githubusercontent.com/github/rest-api-description/main/descriptions/api.github.com/api.github.com.json

docker run --rm -v "${PWD}:/local" \
    -u $(id -u ${USER}):$(id -g ${USER}) \
    openapitools/openapi-generator-cli generate \
    -i /local/specifications/api.github.com.json \
    -g julia-client \
    -o /local/GitHubClient \
    --additional-properties=packageName=GitHubClient > /tmp/generate.out
