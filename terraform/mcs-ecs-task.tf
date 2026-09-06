resource "aws_cloudwatch_log_group" "mcp" {
  name              = "/ecs/${var.project_name}-mcp"
  retention_in_days = 14
}

resource "aws_ecs_cluster" "mcp" {
  name = "${var.project_name}-cluster"
}

resource "aws_ecs_task_definition" "mcp" {
  family                   = "${var.project_name}-mcp"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "mcp-grafana"
    image     = var.mcp_image
    essential = true
    command   = ["-t", "streamable-http", "--address", "0.0.0.0:8000", "--metrics", "--allowed-hosts=*"]

    portMappings = [
      { containerPort = 8000, protocol = "tcp" }
    ]

    environment = [
      { name = "GRAFANA_URL", value = var.mcp_grafana_url != "" ? var.mcp_grafana_url : local.grafana_url }
    ]

    secrets = [{
      name      = "GRAFANA_SERVICE_ACCOUNT_TOKEN"
      valueFrom = aws_secretsmanager_secret.grafana_sa_token.arn
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.mcp.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "mcp"
      }
    }
  }])
}

resource "aws_security_group" "mcp_ecs" {
  name        = "${var.project_name}-mcp"
  description = "MCP server task"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "MCP from the internet"
    from_port   = 8000
    to_port     = 8000
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

resource "aws_ecs_service" "mcp" {
  name            = "${var.project_name}-mcp"
  cluster         = aws_ecs_cluster.mcp.id
  task_definition = aws_ecs_task_definition.mcp.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.mcp_ecs.id]
    assign_public_ip = true
  }
}