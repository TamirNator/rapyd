variable "region" {
  description = "AWS region"
  type = string
}

variable "vpc_name" {
  description = "AWS VPC Name"
}

variable "public_subnets" {
  description = "VPC Public Subnet CIDR"
}

variable "private_subnets" {
  description = "VPC Private Subnet CIDR"
}

variable "azs" {
  description = "VPC Availablilty Zones"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
}

variable "instance_ami" {
  default = "ami-0c104f6f4a5d9d1d5"
}

variable "instance_type" {
  default = "t2.micro"
}