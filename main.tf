# main.tf
provider "aws" {
  region = "us-east-1"
}

# VPC - Incomplete
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "ecs-vpc"
  cidr = "10.0.0.0/16"

  # TODO: Ticket #501 - Complete VPC for multi-region
  # Requirements:
  # 1. Define private_subnets and public_subnets across 2 AZs (e.g., us-east-1a, us-east-1b)
  # 2. Add azs parameter
  # 3. Consider a second region (e.g., us-west-2) for SRE global reliability
  # Current Issue: VPC fails without subnets
  enable_nat_gateway = true
  single_nat_gateway = true
}

# ECS Cluster
resource "aws_ecs_cluster" "reliable_ecs" {
  name = "reliable-ecs-cluster"
}

# ALB for High Availability
resource "aws_lb" "flask_lb" {
  name               = "flask-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = module.vpc.public_subnets  # Fails without subnets
}

resource "aws_lb_target_group" "flask_tg" {
  name        = "flask-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/users"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "flask_listener" {
  load_balancer_arn = aws_lb.flask_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_tg.arn
  }
}

# Security Groups
resource "aws_security_group" "lb_sg" {
  vpc_id = module.vpc.vpc_id
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

resource "aws_security_group" "ecs_sg" {
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Service with ALB
resource "aws_ecs_service" "flask_service" {
  name            = "flask-service"
  cluster         = aws_ecs_cluster.reliable_ecs.id
  task_definition = aws_ecs_task_definition.flask_task.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.flask_tg.arn
    container_name   = "flask-app"
    container_port   = 5000
  }

  # TODO: Ticket #502 - Enable auto-scaling
  # Requirements:
  # 1. Add capacity_provider_strategy or enable ECS auto-scaling
  # 2. Define a scaling policy based on CPU/memory
  # Current Issue: Fixed task count, no dynamic scaling
}

# Task Definition with Datadog
resource "aws_ecs_task_definition" "flask_task" {
  family                   = "flask-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  container_definitions    = file("task-definition.json")
}

# IAM Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Datadog IAM Policy (Incomplete)
resource "aws_iam_role_policy" "datadog_policy" {
  name   = "datadog-policy"
  role   = aws_iam_role.ecs_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # TODO: Ticket #503 - Complete Datadog permissions
      # Requirements:
      # 1. Add permissions for CloudWatch logs and ECS metrics
      # 2. Include Datadog API key access if needed
      # Current Issue: No permissions, Datadog won’t collect metrics
    ]
  })
}
