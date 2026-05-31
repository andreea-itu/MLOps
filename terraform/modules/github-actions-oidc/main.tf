data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  github_thumbprints = distinct([
    for cert in data.tls_certificate.github.certificates :
    replace(cert.sha1_fingerprint, ":", "")
  ])

  ecs_deploy_enabled = var.ecs_cluster_name != "" && var.ecs_service_name != ""

  ecs_deploy_statements = concat(
    local.ecs_deploy_enabled ? [{
      Sid    = "ECSDeploy"
      Effect = "Allow"
      Action = [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
      ]
      Resource = [
        "arn:aws:ecs:eu-west-1:${var.account_id}:cluster/${var.ecs_cluster_name}",
        "arn:aws:ecs:eu-west-1:${var.account_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}",
        "arn:aws:ecs:eu-west-1:${var.account_id}:task-definition/${var.ecs_service_name}:*",
      ]
    }] : [],
    local.ecs_deploy_enabled ? [{
      Sid    = "ECSPassRole"
      Effect = "Allow"
      Action = ["iam:PassRole"]
      Resource = [
        "arn:aws:iam::${var.account_id}:role/${var.ecs_service_name}-execution",
        "arn:aws:iam::${var.account_id}:role/${var.ecs_service_name}-task",
      ]
      Condition = {
        StringLike = {
          "iam:PassedToService" = "ecs-tasks.amazonaws.com"
        }
      }
    }] : [],
  )
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = local.github_thumbprints
}

resource "aws_iam_role" "github_actions" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = var.allowed_subjects
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "github_actions" {
  name = "${var.role_name}-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = var.ecr_repository_arns
      },
      {
        Sid    = "S3DvcAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ],
        "Resource" : [
          "arn:aws:ecr:eu-west-1:${var.account_id}:repository/${var.ecr_repository_name}",
          "arn:aws:ecr:eu-west-1:${var.account_id}:repository/${var.ecr_repository_name}/*",
        ]
      },
    ], local.ecs_deploy_statements)
  })
}
