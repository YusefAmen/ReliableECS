provider "aws" {
  region = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key 
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "ecs-main"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/28"

  tags = {
    Name = "Main"
  }
}

resource "aws_ecs_cluster" "my_cluster" {
  name = "my-python-app-cluster"
}

resource "aws_cloudwatch_log_group" "app_logs" {
  name = "/ecs/python-flask"
  retention_in_days = 1

  tags = {
    Environment = "dev"
    Application = "flaskServiceA"
  }
}
