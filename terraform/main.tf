# Define input variables
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for main VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Create an IAM role for ECS tasks
resource "aws_iam_role" "ecs_role" {
  name = "ecs_role_app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "",
        Effect    = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach an IAM policy to the ECS role
resource "aws_iam_role_policy_attachment" "ecs_policy_attachment" {
  role       = aws_iam_role.ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create a VPC (Virtual Private Cloud)
resource "aws_vpc" "vpc_react_app" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Create public subnets in two availability zones
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.vpc_react_app.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.vpc_react_app.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
}

# Create an internet gateway and a route for internet access
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc_react_app.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.vpc_react_app.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

# Create a security group for the React application
resource "aws_security_group" "security_group_react_app" {
  name        = "security_group_react_app"
  description = "Allow TLS inbound traffic on port 80 (http)"
  vpc_id      = aws_vpc.vpc_react_app.id

  # Define ingress and egress rules
  ingress {
    from_port   = 80
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 3000
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

# Create an ECS task definition for the GraphQL server
resource "aws_ecs_task_definition" "graphql_task" {
  family                  = "graphql_app_family"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  memory                  = "512"
  cpu                     = "256"
  execution_role_arn      = aws_iam_role.ecs_role.arn

  container_definitions = jsonencode([
    {
      name  = "graphql_server_container"
      image = "083135949040.dkr.ecr.us-east-1.amazonaws.com/graphql-server:latest" //image uri
      memory = 512
      essential = true
      portMappings = [
        {
          containerPort = 4000
          hostPort      = 4000
        }
      ]
    }
  ])
}

# Create an ECS cluster for the GraphQL server
resource "aws_ecs_cluster" "graphql_cluster" {
  name = "graphql_cluster_app"
}

# Create an ECS service for the GraphQL server
resource "aws_ecs_service" "graphql_service" {
  name            = "graphql_service"
  cluster         = aws_ecs_cluster.graphql_cluster.id
  task_definition = aws_ecs_task_definition.graphql_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.security_group_react_app.id]
    assign_public_ip = true
  }
}

# Create an ECS task definition for the React application
resource "aws_ecs_task_definition" "react_task" {
  family                  = "react_app_family"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  memory                  = "512"
  cpu                     = "256"
  execution_role_arn      = aws_iam_role.ecs_role.arn

  container_definitions = jsonencode([
    {
      name  = "react_frontend_container"
      image = "083135949040.dkr.ecr.us-east-1.amazonaws.com/react-frontend:latest" //image uri
      memory = 512
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])
}

# Create an ECS cluster for the React application
resource "aws_ecs_cluster" "react_cluster" {
  name = "react_cluster_app"
}

# Create an ECS service for the React application
resource "aws_ecs_service" "react_service" {
  name            = "react_service"
  cluster         = aws_ecs_cluster.react_cluster.id
  task_definition = aws_ecs_task_definition.react_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.security_group_react_app.id]
    assign_public_ip = true
  }
}
