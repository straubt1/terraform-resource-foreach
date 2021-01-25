module "nlbs" {
  source   = "./nlb"
  for_each = { for lb in var.network_lbs : format("%s-%s-nlb", var.namespace, lb.lb_name) => lb }

  namespace  = var.namespace
  lb_name    = each.value.lb_name
  vpc_id     = each.value.vpc_id
  subnet_ids = each.value.subnet_ids
  listeners  = each.value.listeners
}

# Remove
output "debug" {
  value = module.nlbs
}
