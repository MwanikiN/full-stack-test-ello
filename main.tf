# Terraform configuration to define AWS resources 
provider "aws" {
  region = "us-east-1" # Change to your desired region
}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "my-vpc"
  }
}

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.default.id
}
resource "aws_ecr_repository" "graphql_server" {
  name = "ello-full-stack-test/graphql-server"
}
resource "aws_ecr_repository" "full_stack_app" {
  name = "ello-full-stack-test/full-stack-app"
}

resource "aws_ecs_cluster" "my_cluster" {
  name = "my-cluster"
}

resource "aws_lb" "app_load_balancer" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  enable_deletion_protection = false
  subnets            = aws_subnet.public.*.id
}

resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "ECS security group"
  vpc_id      = aws_vpc.default.id 
}

# Create a security group rule allowing traffic on port 80 (HTTP)
resource "aws_security_group_rule" "http_ingress" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_sg.id
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_ecs_task_definition" "graphql_server" {
  family                   = "graphql-server"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  cpu    = "256"  # Specify the required CPU units
  memory = "512"  # Specify the required memory in megabytes

  container_definitions = jsonencode([{
    name  = "graphql-server",
    image = "083135949040.dkr.ecr.us-east-1.amazonaws.com/ello-full-stack-test:graphql-server",
    portMappings = [{
      containerPort = 4000
      hostPort      = 4000
    }],
  }])

  tags = {
    Name = "graphql-server"
  }
}

resource "aws_ecs_task_definition" "full_stack_app" {
  family                   = "full-stack-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  cpu    = "256"  # Specify the required CPU units
  memory = "512"  # Specify the required memory in megabytes

  container_definitions = jsonencode([{
    name  = "full-stack-app",
    image = "083135949040.dkr.ecr.us-east-1.amazonaws.com/ello-full-stack-test:full-stack-test",
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }],
  }])

  tags = {
    Name = "full-stack-app"
  }
}

resource "aws_lb_target_group" "graphql_server_target" {
  name     = "graphql-server-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.default.id
}

resource "aws_lb_target_group" "full_stack_app_target" {
  name     = "full-stack-app-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.default.id
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app_load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
      message_body = "OK"
    }
  }
}

resource "aws_ecs_service" "graphql_server" {
  name            = "graphql-server-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.graphql_server.arn
  launch_type     = "FARGATE"
  desired_count = 1

  network_configuration {
    subnets = aws_subnet.public.*.id

    security_groups = [
      aws_security_group.ecs_sg.id, 
    ]
  }

  depends_on = [aws_lb_listener.app]
}


resource "aws_ecs_service" "full_stack_app" {
  name            = "full-stack-app-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.full_stack_app.arn
  launch_type     = "FARGATE"
  desired_count = 1

  network_configuration {
    subnets = aws_subnet.public.*.id

    security_groups = [
      aws_security_group.ecs_sg.id,
    ]
  }

  depends_on = [aws_lb_listener.app]
}

resource "aws_subnet" "public" {
  count                   = 2 # Adjust as needed for your VPC setup
  vpc_id                  = aws_vpc.default.id
  cidr_block              = cidrsubnet(aws_vpc.default.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index) 
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

output "graphql_server_endpoint" {
  value = aws_lb.app_load_balancer.dns_name
}

output "full_stack_app_endpoint" {
  value = aws_lb.app_load_balancer.dns_name
}
