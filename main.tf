module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.17.0"

  name       = var.vpc_name
  cidr       = var.vpc_cidr
  azs        = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  enable_nat_gateway  = true
}


module "bastion_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = "85.130.153.92/32"
    }
  ]
  egress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.vpc_cidr
    }
  ]
  egress_rules = ["all-all"]
}

module "instance_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "private-instance-sg"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.vpc_cidr
    }
  ]
  egress_rules = ["all-all"]
}


module "bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"
  name                   = "bastion-host"
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [module.bastion_security_group.security_group_id]
  key_name               = aws_key_pair.bastion_key.key_name
  user_data = <<-EOF
              #!/bin/bash
              set -e 

              # Save the private key to the Bastion securely
              echo "${tls_private_key.bastion.private_key_pem}" > /home/ec2-user/bastion.pem
              chmod 600 /home/ec2-user/bastion.pem
              chown ec2-user:ec2-user /home/ec2-user/bastion.pem
EOF
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name          = "private-ec2"
  ami           = var.instance_ami
  instance_type = var.instance_type
  subnet_id     = module.vpc.private_subnets[0]
  vpc_security_group_ids = [module.instance_security_group.security_group_id]
  iam_instance_profile   = module.iam_role.iam_instance_profile_name
  key_name               = aws_key_pair.bastion_key.key_name
  user_data = <<-EOF
              #!/bin/bash
              set -e  # Stop on first error

              # Clean yum cache to prevent conflicts
              sudo yum clean all
              sudo rm -rf /var/cache/yum

              # Install required packages
              sudo yum install -y awslogs

              # Configure AWS Logs agent
              cat <<EOT > /etc/awslogs/awslogs.conf
              [general]
              state_file = /var/lib/awslogs/agent-state

              [/var/log/messages]
              file = /var/log/messages
              log_group_name = /ec2/logs
              log_stream_name = {instance_id}/messages
              datetime_format = %b %d %H:%M:%S

              [/var/log/syslog]
              file = /var/log/syslog
              log_group_name = /ec2/logs
              log_stream_name = {instance_id}/syslog
              datetime_format = %b %d %H:%M:%S
              EOT

              # Enable and start AWS Logs agent
              sudo systemctl enable awslogsd
              sudo systemctl start awslogsd
EOF
    depends_on = [ aws_key_pair.bastion_key ]
}

module "iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 4.0"

  role_name        = "ec2-limited-role"
  trusted_role_services = ["ec2.amazonaws.com"]

  custom_role_policy_arns = [
    aws_iam_policy.cloudwatch_policy.arn
  ]
}

resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "CloudWatchLogsPolicy"
  description = "Allows writing to CloudWatch logs"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["logs:CreateLogStream", "logs:PutLogEvents"],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "ec2_logs" {
  name              = "/ec2/logs"
  retention_in_days = 7
}

resource "tls_private_key" "bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "bastion_key" {
  key_name   = "bastion-key"
  public_key = tls_private_key.bastion.public_key_openssh
}

resource "aws_secretsmanager_secret" "bastion_private_key" {
  name = "bastion-private-key"
}

resource "aws_secretsmanager_secret_version" "bastion_private_key_value" {
  secret_id     = aws_secretsmanager_secret.bastion_private_key.id
  secret_string = tls_private_key.bastion.private_key_pem
}

resource "aws_eip" "bastion_eip" {
}

resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = module.bastion.id
  allocation_id = aws_eip.bastion_eip.id
}