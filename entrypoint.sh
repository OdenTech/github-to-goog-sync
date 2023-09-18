#!/bin/bash -l

set -ex

export PATH=/google-cloud-sdk/bin:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin

google_auth_setup() {
  CLIENT_EMAIL="$(jq -r .client_email <<<"${GOOGLE_CREDENTIALS}")"
  echo "${GOOGLE_CREDENTIALS}" >/tmp/creds.json
  /google-cloud-sdk/bin/gcloud auth activate-service-account "${CLIENT_EMAIL}" --key-file=/tmp/creds.json
}

git_setup() {
  cat <<-EOF >"$HOME/.netrc"
		machine github.com
		login "$GITHUB_ACTOR"
		password "$GITHUB_TOKEN"
		machine api.github.com
		login "$GITHUB_ACTOR"
		password "$GITHUB_TOKEN"
EOF
  chmod 600 "$HOME/.netrc"

  # rf: https://github.com/actions/checkout/issues/760 this works around a new perms
  # check added for CVE-2022-24765
  git config --global --add safe.directory /github/workspace
  git config --global credential.'https://source.developer.google.com/'.helper '!/google-cloud-sdk/bin/gcloud auth git-helper --account='"${CLIENT_EMAIL}"' --ignore-unknown $@'
  git config --global http.postBuffer 157286400
  git gc
  git fsck
}

SOURCE_BRANCH="tmp-$(basename "${GITHUB_REF}")"
DESTINATION_BRANCH="$(basename "${GITHUB_REF}")"

# we really need some less fragile way to establish this mapping
case "${DESTINATION_BRANCH}" in
master)
  GOOGLE_CREDENTIALS="${GOOGLE_CREDENTIALS_ODEN_PRODUCTION}"
  GOOGLE_SOURCE_REPO_URL="${GOOGLE_SOURCE_REPO_URL_ODEN_PRODUCTION}"
  ;;
*)
  GOOGLE_CREDENTIALS="${GOOGLE_CREDENTIALS_ODEN_QA}"
  GOOGLE_SOURCE_REPO_URL="${GOOGLE_SOURCE_REPO_URL_ODEN_QA}"
  ;;
esac

google_auth_setup
git_setup

# check out the source branch at exactly the ref where we were triggered
git checkout -b "${SOURCE_BRANCH}" "${GITHUB_SHA}"

git config user.name "$(git log -n 1 --pretty=format:%an)"
git config user.email "$(git log -n 1 --pretty=format:%ae)"

git remote add destination "${GOOGLE_SOURCE_REPO_URL}"

git push destination "${SOURCE_BRANCH}:${DESTINATION_BRANCH}" -f
