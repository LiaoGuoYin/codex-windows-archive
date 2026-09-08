#!/usr/bin/env bash

github_request() {
  local method="$1"
  local url="$2"
  shift 2
  http_request "${method}" "${url}" \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer ${CI_TOKEN}" \
    --header "X-GitHub-Api-Version: 2022-11-28" \
    "$@"
}

publish_release() {
  local tag="$1"
  local title="$2"
  local body="$3"
  local target="$4"
  shift 4
  local assets=("$@")
  local api_url
  local release_url
  local release_id
  local release_json
  local upload_url
  local payload

  if [[ "${CI_SERVER_URL%/}" == "https://github.com" ]]; then
    api_url="https://api.github.com"
  else
    api_url="${CI_SERVER_URL%/}/api/v3"
  fi
  release_url="${api_url}/repos/${CI_REPOSITORY}/releases"

  github_request GET "${release_url}/tags/$(urlencode "${tag}")"
  case "${http_status}" in
    200)
      release_json="$(<"${http_body_file}")"
      if [[ "$(jq -r '.draft' <<<"${release_json}")" == "false" ]]; then
        echo "Published release ${tag} already exists; skipping upload."
        return 0
      fi
      echo "Draft release ${tag} exists; replacing its assets."
      ;;
    404)
      payload="$(jq -n \
        --arg tag "${tag}" --arg target "${target}" \
        --arg title "${title}" --arg body "${body}" \
        '{tag_name:$tag,target_commitish:$target,name:$title,body:$body,draft:true,prerelease:false}')"
      github_request POST "${release_url}" \
        --header "Content-Type: application/json" --data "${payload}"
      require_status 201 "Create GitHub draft release"
      release_json="$(<"${http_body_file}")"
      echo "Created draft release ${tag}."
      ;;
    *)
      require_status 200 "Get GitHub release"
      ;;
  esac

  release_id="$(jq -er '.id' <<<"${release_json}")"
  upload_url="$(jq -er '.upload_url' <<<"${release_json}")"
  upload_url="${upload_url%%\{*}"

  local asset
  local asset_id
  local asset_name
  for asset in "${assets[@]}"; do
    asset_name="$(basename "${asset}")"
    while IFS= read -r asset_id; do
      [[ -n "${asset_id}" ]] || continue
      github_request DELETE \
        "${release_url}/assets/${asset_id}"
      require_status 204 "Delete existing GitHub asset ${asset_name}"
    done < <(jq -r --arg name "${asset_name}" \
      '.assets[]? | select(.name == $name) | .id' <<<"${release_json}")

    github_request POST \
      "${upload_url}?name=$(urlencode "${asset_name}")" \
      --header "Content-Type: application/octet-stream" \
      --data-binary "@${asset}"
    require_status 201 "Upload GitHub asset ${asset_name}"
    echo "Uploaded ${asset_name}."
  done

  github_request PATCH "${release_url}/${release_id}" \
    --header "Content-Type: application/json" --data '{"draft":false}'
  require_status 200 "Publish GitHub release"
  echo "Published release ${tag}."
}
