# Security Group for Application Server (Microservices Chat App)
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for Chat Microservices App Server"

  # SSH access
  ingress {
    description = "SSH access from allowed CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # React Frontend (Nginx)
  ingress {
    description = "React Frontend Web Client"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # API Gateway
  ingress {
    description = "Express API Gateway"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Auth Microservice direct check
  ingress {
    description = "Auth Microservice direct health check"
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Chat Microservice direct check
  ingress {
    description = "Chat Microservice direct health check"
    from_port   = 5002
    to_port     = 5002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Notification Microservice direct check
  ingress {
    description = "Notification Microservice direct health check"
    from_port   = 5003
    to_port     = 5003
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NRPE daemon for Nagios deep server monitoring
  ingress {
    description     = "NRPE daemon check from Nagios Server"
    from_port       = 5666
    to_port         = 5666
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring_sg.id]
  }

  # ICMP Ping from Nagios
  ingress {
    description     = "ICMP Echo (Ping) from Nagios Server"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.monitoring_sg.id]
  }

  # General ICMP Echo for diagnostics
  ingress {
    description = "ICMP Ping diagnostics"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound all
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

# Security Group for Nagios Monitoring Server
resource "aws_security_group" "monitoring_sg" {
  name        = "${var.project_name}-monitoring-sg"
  description = "Security group for Nagios Monitoring Server"

  # SSH access
  ingress {
    description = "SSH access from allowed CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # Nagios Web UI (Apache HTTP)
  ingress {
    description = "Nagios Core Web Dashboard"
    from_port   = 8
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ICMP Echo for diagnostics
  ingress {
    description = "ICMP Ping diagnostics"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound all
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-monitoring-sg"
  }
}

