provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "terraform-state-hidayat"
    key    = "Learning/cluster_web_server/terraform.tfstate"
    region = "us-east-1"

    dynamodb_table = "terraform-state-lock"
    encrypt        = true

  }
}


data "aws_vpc" "default" {
  default = true

}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

}

resource "aws_launch_template" "cluster_web_server_lt" {
  name                   = "Cluster-Web-Server-Launch-Template"
  image_id               = "ami-0866a3c8686eaeeba"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.test-srv-sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "Hello World!" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
  )

  tags = {
    Name    = "Web-Cluster-LT"
    Owner   = "Hidayat Taghiyev"
    Project = "Learning"
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_autoscaling_group" "cluster_web_server_asg" {
  name = "Cluster Web Server ASG"

  desired_capacity = 2
  max_size         = 4
  min_size         = 1
  #availability_zones = [ "us-east-1a", "us-east-1b", "us-east-1c" ]
  vpc_zone_identifier = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.cluster_web_server-tg.arn]
  health_check_type = "ELB"

  launch_template {
    id = aws_launch_template.cluster_web_server_lt.id

  }

  tag {
    key                 = "Name"
    value               = "asg-server"
    propagate_at_launch = true
  }

}

resource "aws_alb" "cluster_web_server_alb" {
  name               = "Cluster-Web-Server-Load-Balancer"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb-sg.id]

  tags = {
    Name  = "Web App LB"
    Owner = "Hidayat Taghiyev"
    Env   = "Prod"

  }

}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_alb.cluster_web_server_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }

  }

}

resource "aws_lb_target_group" "cluster_web_server-tg" {
  name     = "Web-Server-Target-Group"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 15
    timeout             = 3
    unhealthy_threshold = 2
    healthy_threshold   = 2
    matcher             = "200"
  }

}

resource "aws_lb_listener_rule" "cluster_web_server_lr" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cluster_web_server-tg.arn

  }

}

resource "aws_security_group" "alb-sg" {
  name = "App LB Sec Group"
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

output "alb_dns_name" {
  value       = aws_alb.cluster_web_server_alb.dns_name
  description = "DNS name of the ALB"

}
