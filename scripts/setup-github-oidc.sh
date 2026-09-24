#!/usr/bin/env bash

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <github-org>/<github-repo> [branch] [region]" >&2
  exit 1
fi

GITHUB_REPO="$1"
BRANCH="${2:-main}"
AWS_REGION="${3:-us-east-1}"
ROLE_NAME="sentinel-rapyd-github-actions-deploy"
POLICY_NAME="sentinel-rapyd-github-actions-deploy-policy"
OIDC_URL="token.actions.githubusercontent.com"
OIDC_AUDIENCE="sts.amazonaws.com"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${SCRIPT_DIR}/policies"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

render_policy() {
  local template="$1"
  local out="$2"
  shift 2
  local sed_args=()
  for pair in "$@"; do
    local token="${pair%%=*}"
    local value="${pair#*=}"
    sed_args+=(-e "s|__${token}__|${value}|g")
  done
  sed "${sed_args[@]}" "${POLICY_DIR}/${template}" > "${WORK_DIR}/${out}"
}

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account: $ACCOUNT_ID"
echo "Repo:    $GITHUB_REPO"
echo "Branch:  $BRANCH (plus any pull_request from this same repo)"
echo

EXISTING_PROVIDER_ARN=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?contains(Arn, '${OIDC_URL}')].Arn" \
  --output text)

if [ -n "$EXISTING_PROVIDER_ARN" ]; then
  echo "OIDC provider already exists: $EXISTING_PROVIDER_ARN"
  PROVIDER_ARN="$EXISTING_PROVIDER_ARN"
else
  echo "Creating OIDC provider for $OIDC_URL..."
  PROVIDER_ARN=$(aws iam create-open-id-connect-provider \
    --url "https://${OIDC_URL}" \
    --client-id-list "$OIDC_AUDIENCE" \
    --query "OpenIDConnectProviderArn" --output text)
  echo "Created: $PROVIDER_ARN"
fi
echo

render_policy "trust-policy.json.tpl" "trust-policy.json" \
  "PROVIDER_ARN=${PROVIDER_ARN}" \
  "OIDC_URL=${OIDC_URL}" \
  "OIDC_AUDIENCE=${OIDC_AUDIENCE}" \
  "GITHUB_REPO=${GITHUB_REPO}" \
  "BRANCH=${BRANCH}"

echo "Creating/updating role $ROLE_NAME..."
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" \
    --policy-document "file://${WORK_DIR}/trust-policy.json"
  echo "Trust policy updated on existing role."
else
  aws iam create-role --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://${WORK_DIR}/trust-policy.json" \
    --description "GitHub Actions OIDC deploy role for the Sentinel split-architecture PoC (${GITHUB_REPO})"
  echo "Role created."
fi
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo

render_policy "permissions-policy.json.tpl" "permissions-policy.json" \
  "ACCOUNT_ID=${ACCOUNT_ID}" \
  "AWS_REGION=${AWS_REGION}"

echo "Creating/updating inline policy $POLICY_NAME on $ROLE_NAME..."
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "$POLICY_NAME" \
  --policy-document "file://${WORK_DIR}/permissions-policy.json"
echo "Policy attached."
echo

echo "Done. Set this as the AWS_TERRAFORM_ROLE_ARN repository variable in GitHub:"
echo "  $ROLE_ARN"
