output "app_server_public_ip" {
  description = "Public IP address of the Chat Application Server"
  value       = aws_instance.app_server.public_ip
}

output "monitoring_server_public_ip" {
  description = "Public IP address of the Nagios Monitoring Server"
  value       = aws_instance.monitoring_server.public_ip
}

output "app_web_url" {
  description = "URL to access the React Chat Frontend"
  value       = "http://${aws_instance.app_server.public_ip}:3000"
}

output "api_gateway_url" {
  description = "URL to access the Express API Gateway health endpoint"
  value       = "http://${aws_instance.app_server.public_ip}:5000/health"
}

output "nagios_dashboard_url" {
  description = "URL to access the Nagios Core Web Dashboard"
  value       = "http://${aws_instance.monitoring_server.public_ip}/nagios4/"
}

output "ssh_app_server_cmd" {
  description = "Direct SSH command to connect to App Server"
  value       = "ssh -i ${local.ssh_key_path} ubuntu@${aws_instance.app_server.public_ip}"
}

output "ssh_monitoring_server_cmd" {
  description = "Direct SSH command to connect to Nagios Monitoring Server"
  value       = "ssh -i ${local.ssh_key_path} ubuntu@${aws_instance.monitoring_server.public_ip}"
}

output "ssh_private_key_file" {
  description = "Path to the SSH private key used to connect to instances"
  value       = local.ssh_key_path
}

