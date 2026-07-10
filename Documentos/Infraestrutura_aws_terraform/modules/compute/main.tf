# Security Group da Instância EC2
resource "aws_security_group" "ec2_sg" {
  name        = "${var.environment}-ec2-sg"
  description = "Permite trafego web direto para o lab"
  vpc_id      = var.vpc_id

 
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-ec2-sg" }
}


resource "aws_instance" "app_server" {
  ami                    = "ami-0c55b159cbfafe1f0" # AMI Amazon Linux
  instance_type          = var.instance_type
  
  
  subnet_id              = var.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # Script de inicializacao para rodar um mini-servidor web
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello from DevOps Mentor!" > index.html
              nohup busybox httpd -f -p 80 &
              EOF

  tags = {
    Name = "${var.environment}-app-server"
  }
}