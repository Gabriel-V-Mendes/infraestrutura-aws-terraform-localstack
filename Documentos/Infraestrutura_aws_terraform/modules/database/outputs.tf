output "db_private_ip" {
  value = aws_instance.postgres_mock.private_ip
}