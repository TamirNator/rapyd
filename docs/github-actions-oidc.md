# GitHub Actions OIDC

The Terraform workflow authenticates to AWS with GitHub's OIDC token. It does
not use long-lived AWS access keys.

## Repository variables

Configure these non-secret repository variables in GitHub:

- `AWS_TERRAFORM_ROLE_ARN`: ARN of the IAM role GitHub Actions may assume
- `KARPENTER_CHART_VERSION`: approved Karpenter chart version

## IAM role trust policy

The role must trust GitHub's OIDC provider:

`arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com`

The trust policy should restrict both the audience and this repository. The
workflow needs to support `main` pushes and same-repository pull requests:

```json
{
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
  },
  "StringLike": {
    "token.actions.githubusercontent.com:sub": [
      "repo:TamirNator/rapyd:ref:refs/heads/main",
      "repo:TamirNator/rapyd:pull_request"
    ]
  }
}
```

The workflow deliberately does not request AWS credentials for pull requests
from forks. The workflow currently runs plans only; it does not run `apply`.

The role should have only the read and state access required for planning:

- read access to resources inspected by Terraform
- access to the Terraform state bucket
- access to the state lock table

Do not grant `AdministratorAccess` just to make the first plan pass.