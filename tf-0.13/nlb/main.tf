resource "aws_lb" "main" {
  name    = format("%s-%s-nlb", var.namespace, var.lb_name)
  subnets = var.subnet_ids
  tags = merge(var.tags, {
    "Name" : format("%s-%s-nlb", var.namespace, var.lb_name)
  })

  internal                         = true
  load_balancer_type               = "network"
  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = "true"
}

resource "aws_lb_target_group" "main" {
  # The key here must be the same for Target Group and Listeners
  for_each = { for l in var.listeners : format("%s-%s-%s", var.namespace, var.lb_name, l.name) => l }

  name     = each.key
  port     = each.value.targetPort
  protocol = each.value.protocol
  vpc_id   = var.vpc_id

  health_check {
    protocol            = each.value.health_check_protocol
    port                = each.value.targetPort
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, {
    "Name" : each.key
  })
}

resource "aws_lb_listener" "main" {
  # The key here must be the same for Target Group and Listeners
  for_each = { for l in var.listeners : format("%s-%s-%s", var.namespace, var.lb_name, l.name) => l }

  load_balancer_arn = aws_lb.main.arn
  port              = each.value.listenerPort
  protocol          = each.value.protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[each.key].arn
  }
}
