#!/usr/bin/bash

REPO=${1}
if [ -z ${2+x} ]; then MATCH="."; else MATCH="${2}"; fi

readonly MIRROR_DIR="./mirror"
URL="https://api.github.com/repos/${REPO}"

mkdir -p "${MIRROR_DIR}/.etags"

NEW_TAG=$(curl --etag-save "${MIRROR_DIR}/.etags/${REPO//\//_}-tags.etag" --etag-compare "${MIRROR_DIR}/.etags/${REPO//\//_}-tags.etag" --silent --output /dev/null --write-out "%{http_code}" "${URL}/tags")

if [[ ${NEW_TAG} -eq 304 ]]; then
  echo "No change for ${REPO}"
  exit 0
fi

RELEASES=$(curl --silent "${URL}/releases" | jq '[.[] | {tag_name: .tag_name, draft: .draft, assets: [.assets[].browser_download_url]}]')

for RELEASE in $(echo "${RELEASES}" | jq -r '.[] | @base64'); do
  DRAFT=$(echo "${RELEASE}" | base64 --decode | jq -r '.draft')
  NAME=$(echo "${RELEASE}" | base64 --decode | jq -r '.tag_name')
  URLS=$(echo "${RELEASE}" | base64 --decode | jq -r '.assets | .[]')

  if [[ "${DRAFT}" != "false" ]]; then
    continue
  fi

  RELEASE_DEST="${MIRROR_DIR}/${REPO}/${NAME}"
  MATCHED_URLS=""
  for url in ${URLS}; do
    if [[ ${url} =~ ${MATCH} ]]; then
      MATCHED_URLS="${MATCHED_URLS} ${url}"
    fi
  done
  # Trim left (because of first assignation
  MATCHED_URLS="${MATCHED_URLS##*( )}"

  if [ -n "${MATCHED_URLS}" ]; then
    mkdir -p "${RELEASE_DEST}"
    # Do not double quote MATCHED_URLS
    # shellcheck disable=SC2086
    wget --timestamping --directory-prefix="${RELEASE_DEST}" --no-verbose ${MATCHED_URLS}
  fi
done
