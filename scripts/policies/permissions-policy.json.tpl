{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "NetworkingEC2",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
        "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:CreateRoute", "ec2:DeleteRoute",
        "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable", "ec2:ReplaceRouteTableAssociation",
        "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
        "ec2:AllocateAddress", "ec2:ReleaseAddress", "ec2:AssociateAddress", "ec2:DisassociateAddress",
        "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
        "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
        "ec2:UpdateSecurityGroupRuleDescriptionsIngress", "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
        "ec2:CreateVpcPeeringConnection", "ec2:AcceptVpcPeeringConnection", "ec2:DeleteVpcPeeringConnection",
        "ec2:CreateNetworkAclEntry", "ec2:DeleteNetworkAclEntry", "ec2:ReplaceNetworkAclEntry",
        "ec2:CreateTags", "ec2:DeleteTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKS",
      "Effect": "Allow",
      "Action": [
        "eks:*"
      ],
      "Resource": [
        "arn:aws:eks:__AWS_REGION__:__ACCOUNT_ID__:cluster/rapyd-*",
        "arn:aws:eks:__AWS_REGION__:__ACCOUNT_ID__:nodegroup/rapyd-*/*/*",
        "arn:aws:eks:__AWS_REGION__:__ACCOUNT_ID__:addon/rapyd-*/*/*",
        "arn:aws:eks:__AWS_REGION__:__ACCOUNT_ID__:access-entry/rapyd-*/*/*/*",
        "arn:aws:eks:__AWS_REGION__:__ACCOUNT_ID__:podidentityassociation/rapyd-*/*"
      ]
    },
    {
      "Sid": "EKSAddonVersionLookup",
      "Effect": "Allow",
      "Action": ["eks:DescribeAddonVersions"],
      "Resource": "*"
    },
    {
      "Sid": "IamScopedToApprovedPrefixesOnly",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole", "iam:DeleteRole", "iam:GetRole",
        "iam:UpdateRole", "iam:UpdateAssumeRolePolicy",
        "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags",
        "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies",
        "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy", "iam:ListRolePolicies",
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::__ACCOUNT_ID__:role/eks-*",
        "arn:aws:iam::__ACCOUNT_ID__:role/sentinel-*"
      ]
    },
    {
      "Sid": "IamPolicyForApprovedPrefixesOnly",
      "Effect": "Allow",
      "Action": [
        "iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy",
        "iam:GetPolicyVersion", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:ListPolicyVersions"
      ],
      "Resource": [
        "arn:aws:iam::__ACCOUNT_ID__:policy/eks-*",
        "arn:aws:iam::__ACCOUNT_ID__:policy/sentinel-*"
      ]
    },
    {
      "Sid": "DenyIamOutsideApprovedPrefixes",
      "Effect": "Deny",
      "Action": [
        "iam:CreateRole", "iam:DeleteRole", "iam:UpdateRole", "iam:UpdateAssumeRolePolicy",
        "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
        "iam:PassRole",
        "iam:CreatePolicy", "iam:DeletePolicy", "iam:CreatePolicyVersion"
      ],
      "NotResource": [
        "arn:aws:iam::__ACCOUNT_ID__:role/eks-*",
        "arn:aws:iam::__ACCOUNT_ID__:role/sentinel-*",
        "arn:aws:iam::__ACCOUNT_ID__:policy/eks-*",
        "arn:aws:iam::__ACCOUNT_ID__:policy/sentinel-*"
      ]
    },
    {
      "Sid": "TerraformStateBucket",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket", "s3:PutBucketVersioning", "s3:PutEncryptionConfiguration",
        "s3:PutBucketPublicAccessBlock", "s3:GetBucketVersioning", "s3:GetEncryptionConfiguration",
        "s3:GetBucketPublicAccessBlock", "s3:GetBucketPolicy", "s3:PutBucketPolicy",
        "s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::rapyd-tfstate-*",
        "arn:aws:s3:::rapyd-tfstate-*/*"
      ]
    },
    {
      "Sid": "KarpenterInterruptionQueue",
      "Effect": "Allow",
      "Action": [
        "sqs:CreateQueue", "sqs:DeleteQueue", "sqs:GetQueueAttributes",
        "sqs:SetQueueAttributes", "sqs:GetQueueUrl", "sqs:TagQueue", "sqs:ListQueueTags"
      ],
      "Resource": "arn:aws:sqs:__AWS_REGION__:__ACCOUNT_ID__:Karpenter-rapyd-*"
    },
    {
      "Sid": "KarpenterInterruptionEvents",
      "Effect": "Allow",
      "Action": [
        "events:PutRule", "events:DescribeRule", "events:DeleteRule",
        "events:PutTargets", "events:RemoveTargets", "events:ListTargetsByRule"
      ],
      "Resource": "arn:aws:events:__AWS_REGION__:__ACCOUNT_ID__:rule/*"
    },
    {
      "Sid": "CloudWatchLogsForEksControlPlane",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup", "logs:DescribeLogGroups", "logs:PutRetentionPolicy",
        "logs:DeleteLogGroup", "logs:TagLogGroup", "logs:ListTagsLogGroup"
      ],
      "Resource": "arn:aws:logs:__AWS_REGION__:__ACCOUNT_ID__:log-group:/aws/eks/rapyd-*:*"
    },
    {
      "Sid": "CallerIdentity",
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    }
  ]
}
