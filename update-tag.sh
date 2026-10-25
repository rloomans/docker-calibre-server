#!/usr/bin/env bash

set -euo pipefail

TAG="$(curl -sS 'https://api.github.com/repos/kovidgoyal/calibre/releases?per_page=1' | jq -r '.[0].tag_name')"

if [[ ! $TAG =~ ^v[0-9.]+$ ]]; then
    echo "skipping invalid tag: $TAG"
    exit 1
fi

sed -i "s/ARG CALIBRE_RELEASE\=.*/ARG CALIBRE_RELEASE\=\"${TAG:1}\"/" Dockerfile

if git diff --exit-code Dockerfile; then
    echo "Dockerfile already on ${TAG}"

    if [ "$(git tag --list "${TAG}")" != "${TAG}" ]; then
      echo ${TAG} tag is missing
      git tag "${TAG}"
    fi
else
    git add Dockerfile
    git commit -m "update Calibre to ${TAG}"

    git push origin main

    git tag --force "${TAG}"
fi

git push --force --tags
git push origin "${TAG}"
