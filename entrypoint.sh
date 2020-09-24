#!/bin/bash -l

set -ex

git_setup() {
  cat <<- EOF > "$HOME/.netrc"
		machine github.com
		login "$GITHUB_ACTOR"
		password "$GITHUB_TOKEN"
		machine api.github.com
		login "$GITHUB_ACTOR"
		password "$GITHUB_TOKEN"
EOF
  chmod 600 "$HOME/.netrc"

  git config --global user.email "$GITBOT_EMAIL"
  git config --global user.name "$GITHUB_ACTOR"
}


CLIENT_EMAIL="$(jq -r .client_email <<< "${GOOGLE_CREDENTIALS}")"
echo "${GOOGLE_CREDENTIALS}" > /tmp/creds.json
/google-cloud-sdk/bin/gcloud auth activate-service-account "${CLIENT_EMAIL}" --key-file=/tmp/creds.json

git_setup
git remote -v

# check out the source branch at exactly the ref where we were triggered
SOURCE_BRANCH="tmp-$(basename "${GITHUB_REF}")"
DESTINATION_BRANCH="$(basename "${GITHUB_REF}")"
git checkout -b "${SOURCE_BRANCH}" "${GITHUB_SHA}"

git remote add destination "${GOOGLE_SOURCE_REPO_URL}"
git config --replace-all credential.helper '!/google-cloud-sdk/bin/gcloud auth git-helper --account='"${CLIENT_EMAIL}"' --ignore-unknown $@'

git push destination "${SOURCE_BRANCH}:${DESTINATION_BRANCH}" -f
