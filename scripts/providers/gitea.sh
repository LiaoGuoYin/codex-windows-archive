#!/usr/bin/env bash

gitea_request() {
  local method="$1"
  local url="$2"
  shift 2
  http_request "${method}" "${url}" \
    --header "Accept: application/json" \
    --header "Authorization: token ${CI_TOKEN}" \
    "$@"
}

publish_release() {
  local tag="$1"
  local title="$2"
  local body="$3"
  local target="$4"
  shift 4
  local assets=("$@")
  local api_url="${CI_SERVER_URL%/}/api/v1"
  local release_url
  local release_id
  local release_json
  local payload

  release_url="${api_url}/repos/${CI_REPOSITORY}/releases"
  gitea_request GET "${release_url}/tags/$(urlencode "${tag}")"
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
      gitea_request POST "${release_url}" \
        --header "Content-Type: application/json" --data "${payload}"
      require_status 201 "Create Gitea draft release"
      release_json="$(<"${http_body_file}")"
      echo "Created draft release ${tag}."
      ;;
    *)
      require_status 200 "Get Gitea release"
      ;;
  esac

  release_id="$(jq -er '.id' <<<"${release_json}")"

  local asset
  local asset_id
  local asset_name
  for asset in "${assets[@]}"; do
    asset_name="$(basename "${asset}")"
    while IFS= read -r asset_id; do
      [[ -n "${asset_id}" ]] || continue
      gitea_request DELETE \
        "${release_url}/${release_id}/assets/${asset_id}"
      require_status 204 "Delete existing Gitea asset ${asset_name}"
    done < <(jq -r --arg name "${asset_name}" \
      '.assets[]? | select(.name == $name) | .id' <<<"${release_json}")

    gitea_request POST \
      "${release_url}/${release_id}/assets?name=$(urlencode "${asset_name}")" \
      --header "Content-Type: application/octet-stream" \
      --data-binary "@${asset}"
    require_status 201 "Upload Gitea asset ${asset_name}"
    echo "Uploaded ${asset_name}."
  done

  gitea_request PATCH "${release_url}/${release_id}" \
    --header "Content-Type: application/json" --data '{"draft":false}'
  require_status 200 "Publish Gitea release"
  echo "Published release ${tag}."
}
