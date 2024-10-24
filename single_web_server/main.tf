provider "aws" {
  region = "us-east-1"

}

resource "aws_instance" "test-srv" {
  ami                         = "ami-0866a3c8686eaeeba"
  instance_type               = "t2.micro"
  user_data                   = <<-EOF
                #!bin/bash
                echo "Hello World!" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF
  user_data_replace_on_change = true
  vpc_security_group_ids      = [aws_security_group.test-srv-sg.id]

  tags = {
    Name    = "Terraform-Test"
    Owner   = "Hidayat Taghiyev"
    Project = "Learning"
  }

}

resource "aws_security_group" "test-srv-sg" {
  name = "terraform-test-srv-sg"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

variable "server_port" {
  description = "Server port used for Communication"
  type        = number
  default     = 8080
}

output "server_public_ip" {
  description = "Public IP of the Server"
  value       = aws_instance.test-srv.public_ip

}

output "server_id" {
  description = "Name of the Server"
  value       = aws_instance.test-srv.id

}

### testing

 
