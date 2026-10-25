#!/usr/bin/env bash

set -euo pipefail

DRY_RUN=false
case "${1:-}" in
    --dry-run) DRY_RUN=true ;;
    "") ;;
    *) echo "usage: $0 [--dry-run]" >&2; exit 2 ;;
esac

RELEASE="$(curl -fsSL 'https://api.github.com/repos/kovidgoyal/calibre/releases?per_page=1' | jq '.[0]')"
TAG="$(jq -r '.tag_name' <<< "${RELEASE}")"

if [[ ! $TAG =~ ^v[0-9.]+$ ]]; then
    echo "skipping invalid tag: $TAG"
    exit 1
fi

VERSION="${TAG:1}"
SHA256_X86_64="$(jq -r --arg name "calibre-${VERSION}-x86_64.txz" '.assets[] | select(.name == $name) | .digest | sub("^sha256:"; "")' <<< "${RELEASE}")"
SHA256_ARM64="$(jq -r --arg name "calibre-${VERSION}-arm64.txz" '.assets[] | select(.name == $name) | .digest | sub("^sha256:"; "")' <<< "${RELEASE}")"

# Calibre's signature server uses a private CA, pinned the same way as in the official installer
CA_CERT="$(dirname "${BASH_SOURCE[0]}")/calibre-ca.pem"
SIGNATURES_URL="https://code.calibre-ebook.com/signatures"

fetch_sha512() {
    curl -fsSL --cacert "${CA_CERT}" "${SIGNATURES_URL}/calibre-${VERSION}-$1.txz.sha512"
}

SHA512_X86_64="$(fetch_sha512 x86_64 | tr -d '[:space:]')"
SHA512_ARM64="$(fetch_sha512 arm64 | tr -d '[:space:]')"

if [[ ! $SHA256_X86_64 =~ ^[0-9a-f]{64}$ || ! $SHA256_ARM64 =~ ^[0-9a-f]{64}$ ]]; then
    echo "missing or invalid SHA-256 digest for Calibre release ${TAG}"
    exit 1
fi

if [[ ! $SHA512_X86_64 =~ ^[0-9a-f]{128}$ || ! $SHA512_ARM64 =~ ^[0-9a-f]{128}$ ]]; then
    echo "missing or invalid SHA-512 signature for Calibre release ${TAG}"
    exit 1
fi

sed -i \
    -e "s/^ARG CALIBRE_RELEASE=.*/ARG CALIBRE_RELEASE=\"${VERSION}\"/" \
    -e "s/^ARG CALIBRE_RELEASE_SHA256_X86_64=.*/ARG CALIBRE_RELEASE_SHA256_X86_64=\"${SHA256_X86_64}\"/" \
    -e "s/^ARG CALIBRE_RELEASE_SHA256_ARM64=.*/ARG CALIBRE_RELEASE_SHA256_ARM64=\"${SHA256_ARM64}\"/" \
    -e "s/^ARG CALIBRE_RELEASE_SHA512_X86_64=.*/ARG CALIBRE_RELEASE_SHA512_X86_64=\"${SHA512_X86_64}\"/" \
    -e "s/^ARG CALIBRE_RELEASE_SHA512_ARM64=.*/ARG CALIBRE_RELEASE_SHA512_ARM64=\"${SHA512_ARM64}\"/" \
    Dockerfile

if [[ $DRY_RUN == true ]]; then
    echo "dry run: Dockerfile updated for ${TAG}, skipping version check and git updates"
    git --no-pager diff Dockerfile || true
    exit 0
fi

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
