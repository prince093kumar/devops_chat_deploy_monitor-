variable "aws_region" {
  description = "AWS region where resources will be provisioned"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project identifier prefix for naming resources"
  type        = string
  default     = "microchat-devops"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "app_instance_type" {
  description = "EC2 instance type for the Microservices App Server (minimum 2GB RAM recommended for Docker builds)"
  type        = string
  default     = "t3.medium"
}

variable "monitoring_instance_type" {
  description = "EC2 instance type for the Nagios Monitoring Server"
  type        = string
  default     = "t3.micro"
}

variable "app_volume_size" {
  description = "Root EBS volume size in GB for App Server"
  type        = number
  default     = 25
}

variable "monitoring_volume_size" {
  description = "Root EBS volume size in GB for Monitoring Server"
  type        = number
  default     = 15
}

variable "key_name" {
  description = "Optional existing AWS Key Pair name. If blank, Terraform creates a dedicated key pair automatically"
  type        = string
  default     = ""
}

variable "public_key_path" {
  description = "Path to an existing SSH public key. If blank and key_name is blank, Terraform generates a new RSA key pair"
  type        = string
  default     = ""
}

variable "private_key_output_path" {
  description = "Where to save the auto-generated private SSH key on local machine"
  type        = string
  default     = "../ansible/id_rsa_devops"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block permitted to connect via SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

