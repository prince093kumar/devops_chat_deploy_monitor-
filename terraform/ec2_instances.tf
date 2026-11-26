# Lookup latest Ubuntu 22.04 LTS AMI (Canonical)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance: Microservices Chat Application Server
resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.app_instance_type
  key_name                    = local.selected_key_name
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.app_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    tags = {
      Name = "${var.project_name}-app-root-ebs"
    }
  }

  tags = {
    Name = "${var.project_name}-app-server"
    Role = "application"
  }
}

# EC2 Instance: Nagios Monitoring Server
resource "aws_instance" "monitoring_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.monitoring_instance_type
  key_name                    = local.selected_key_name
  vpc_security_group_ids      = [aws_security_group.monitoring_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.monitoring_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    tags = {
      Name = "${var.project_name}-monitoring-root-ebs"
    }
  }

  tags = {
    Name = "${var.project_name}-monitoring-server"
    Role = "monitoring"
  }
}

