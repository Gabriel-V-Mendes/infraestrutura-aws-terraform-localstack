
resource "aws_security_group" "rds_sg" {
  name        = "${var.environment}-rds-sg"
  description = "Permite acesso apenas das instancias EC2"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL access from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ec2_security_group_id] # A regra de ouro da segurança
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-rds-sg" }
}


resource "aws_instance" "postgres_mock" {
  ami                    = "ami-0c55b159cbfafe1f0" # AMI Amazon Linux
  instance_type          = "t3.micro"
  
  
  subnet_id              = var.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  tags = {
    Name = "${var.environment}-mock-postgres-db"
  }
}