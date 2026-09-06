locals {
  mcp_interface_endpoints = ["ecr.api", "ecr.dkr", "logs", "secretsmanager"]
}

resource "aws_security_group" "mcp_alb" {
  name        = "${var.project_name}-alb"
  description = "Public ALB for MCP"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Just for show -- pair with the HTTPS listener below if you add a custom domain.
  # ingress {
  #   description = "HTTPS from the internet"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "mcp" {
  name               = "${var.project_name}-mcp"
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.mcp_alb.id]
}

resource "aws_lb_target_group" "mcp" {
  name        = "${var.project_name}-mcp"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "mcp_http" {
  load_balancer_arn = aws_lb.mcp.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mcp.arn
  }
}

# Just for show -- needs the ACM cert in mcp-ecs-dns.tf.
/*
resource "aws_lb_listener" "mcp_https" {
  load_balancer_arn = aws_lb.mcp.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.mcp.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mcp.arn
  }
}

resource "aws_lb_listener" "mcp_http_redirect" {
  load_balancer_arn = aws_lb.mcp.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
*/

resource "aws_security_group" "mcp_endpoints" {
  name        = "${var.project_name}-vpce"
  description = "Allow HTTPS from the VPC to interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

resource "aws_vpc_endpoint" "mcp_interface" {
  for_each = toset(local.mcp_interface_endpoints)

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.mcp_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "mcp_s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}