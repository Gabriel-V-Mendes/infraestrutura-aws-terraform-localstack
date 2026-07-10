output "ec2_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "ec2_security_group_id" {
  value = aws_security_group.ec2_sg.id
}