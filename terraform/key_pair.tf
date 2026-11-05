# Generate RSA key pair when neither existing key_name nor public_key_path is provided
resource "tls_private_key" "devops_key" {
  count     = var.key_name == "" && var.public_key_path == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save generated private key locally for Ansible and SSH use
resource "local_sensitive_file" "private_key" {
  count           = var.key_name == "" && var.public_key_path == "" ? 1 : 0
  content         = tls_private_key.devops_key[0].private_key_pem
  filename        = var.private_key_output_path
  file_permission = "0600"
}

# Create AWS Key Pair if not using existing AWS key_name
resource "aws_key_pair" "generated" {
  count      = var.key_name == "" ? 1 : 0
  key_name   = "${var.project_name}-key"
  public_key = var.public_key_path != "" ? file(var.public_key_path) : tls_private_key.devops_key[0].public_key_openssh

  tags = {
    Name = "${var.project_name}-key"
  }
}

locals {
  selected_key_name = var.key_name != "" ? var.key_name : aws_key_pair.generated[0].key_name
  ssh_key_path      = var.key_name != "" ? "~/.ssh/${var.key_name}.pem" : var.private_key_output_path
}
