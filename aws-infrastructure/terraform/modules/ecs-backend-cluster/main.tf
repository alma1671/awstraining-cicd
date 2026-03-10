resource "aws_security_group" "sg_lb_backend" {
  description = "Controls access to backend load balancer"
  vpc_id = var.aws_vpc_id
  name = "sg_lb_backend"

  ingress {
    description = "Access to HTTP"
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.common_tags,
    {
      "Name" = "SG Load Balancer backend"
    }
  )
}

resource "aws_lb" "backend_ecs_lb" {
  name                       = "backend-lb"
  internal                   = false
  load_balancer_type         = "application"
  subnets = var.public_subnets_id
  tags = var.common_tags
  security_groups = [ aws_security_group.sg_lb_backend.id ]
}

# Target Group for LoadBalancer
resource "aws_lb_target_group" "backend_ecs_lb_target_group" {
  name                 = "backend-test-tg"
  port                 = 8080
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.aws_vpc_id

  health_check {
    path     = "/actuator/health"
    protocol = "HTTP"
  }

  tags = var.common_tags
}

# Listener for LoadBalancer on port 80
resource "aws_lb_listener" "backend_ecs_lb_listener" {
  load_balancer_arn = aws_lb.backend_ecs_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_ecs_lb_target_group.arn
  }

  tags = merge(
    var.common_tags
  )
}

# ECS Cluster for backend
resource "aws_ecs_cluster" "ecs_backend_cluster" {
  name               = var.ecs_cluster_name
  tags = var.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "fargate_capacity_provider" {
  cluster_name = aws_ecs_cluster.ecs_backend_cluster.name

  capacity_providers = ["FARGATE"]
}

resource "aws_cloudwatch_metric_alarm" "backend_ecs_unhealthy_hosts" {
  alarm_name          = "backend-ecs-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = "60"
  datapoints_to_alarm = "7"
  evaluation_periods  = "10"
  statistic           = "Average"
  threshold           = ceil(var.backend_service_deployment_desired_task_count / 2)
  alarm_description   = "Region=${var.region}; Env=${var.environment}; Desc=Unhealthy tasks in backend reached threshold"
  alarm_actions       = [
    var.sns_alarm_topic_arn
  ]
  treat_missing_data = "missing"
  dimensions         = {
    TargetGroup  = aws_lb_target_group.backend_ecs_lb_target_group.arn_suffix
    LoadBalancer = aws_lb.backend_ecs_lb.arn_suffix
  }
  tags = var.common_tags
}
