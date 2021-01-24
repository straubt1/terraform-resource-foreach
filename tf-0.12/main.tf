locals {
  # Each of these locals creates a map that can be iterated over by the "resource" block later using a 'for_each' construct.
  # This keeps the complexity in one place, allows the syntax within each "resource" block to be simplified, 
  #   and allows us to use an output as a debug step.
  # Key Point: The initial iteratator for the `for` is always the same variable (in this case 'var.network_lbs').

  # for each Network LB needed 
  network_lbs = [
    for lb in var.network_lbs : {
      # key is used for the resource address and resource name, but could be different if required
      # key MUST be unique for each instance of the resource!
      key = format("%s-%s-nlb", var.namespace, lb.lbname)

      # dynamic settings for the resource
      subnet_ids = lb.subnet_ids
    }
  ]

  # for_each Target Group needed
  network_lbs_tg = flatten([
    for lb in var.network_lbs : [
      for l in lb.listeners : {
        # key is used for the resource address and resource name, but could be different if required
        # key MUST be unique for each instance of the resource!
        key = format("%s-%s-%s", var.namespace, lb.lbname, l.name)

        # dynamic settings for the resource
        port                  = l.targetPort
        protocol              = l.protocol
        health_check_protocol = l.health_check_protocol
        vpc_id                = lb.vpc_id
      }
    ]
  ])

  # for_each Listener needed, this will wire up the TG and the LB
  network_lbs_listener = flatten([
    for lb in var.network_lbs : [
      for l in lb.listeners : {
        # key is used for the resource address and resource name, but could be different if required
        # key MUST be unique for each instance of the resource!
        key = format("%s-%s-%s", var.namespace, lb.lbname, l.name)

        # these keys must be exactly the same as used in the LB and TG resources above, this allows for clean lookup at "apply" time 
        lb_key = format("%s-%s-nlb", var.namespace, lb.lbname)
        tg_key = format("%s-%s-%s", var.namespace, lb.lbname, l.name)

        # dynamic settings for the resource 
        port     = l.listenerPort
        protocol = l.protocol
      }
    ]
  ])

}

# Remove
output "debug" {
  value = {
    network_lbs          = local.network_lbs
    network_lbs_tg       = local.network_lbs_tg
    network_lbs_listener = local.network_lbs_listener
  }
}

resource "aws_lb" "additional-nlb" {
  # for loop will convert the list into a usable map 
  for_each = { for r in local.network_lbs : r.key => r }

  name    = each.value.key
  subnets = each.value.subnet_ids
  tags = merge(var.tags, {
    "Name" : each.value.key
  })

  internal                         = true
  load_balancer_type               = "network"
  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = "true"
}

resource "aws_lb_target_group" "add-nlb-tg" {
  # for loop will convert the list into a usable map 
  for_each = { for r in local.network_lbs_tg : r.key => r }

  name     = each.value.key
  port     = each.value.port
  protocol = each.value.protocol
  vpc_id   = each.value.vpc_id
  health_check {
    protocol            = each.value.health_check_protocol
    port                = each.value.port
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
  tags = merge(var.tags, {
    "Name" : each.value.key
  })
}

resource "aws_lb_listener" "add-nlb-listener" {
  # for loop will convert the list into a usable map 
  for_each = { for r in local.network_lbs_listener : r.key => r }

  load_balancer_arn = aws_lb.additional-nlb[each.value.lb_key].arn
  port              = each.value.port
  protocol          = each.value.protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.add-nlb-tg[each.value.tg_key].arn
  }
}
