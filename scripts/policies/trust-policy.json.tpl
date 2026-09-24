{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Federated": "__PROVIDER_ARN__" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "__OIDC_URL__:aud": "__OIDC_AUDIENCE__"
        },
        "StringLike": {
          "__OIDC_URL__:sub": [
            "repo:__GITHUB_REPO__:ref:refs/heads/__BRANCH__",
            "repo:__GITHUB_REPO__:pull_request"
          ]
        }
      }
    }
  ]
}
