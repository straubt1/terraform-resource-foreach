variable "namespace" {
  description = "Resource name prefix to be applied to every resource."
  default     = "terraform"
  type        = string
}

variable "tags" {
  description = "Common tags to be applied to every resource."
  default     = {}
  type        = map(string)
}

variable "network_lbs" {
  description = "Complex variable declaring the NLBs to create with a variable number of listeners."
  default     = []
  type = list(object({
    lb_name    = string
    vpc_id     = string
    subnet_ids = list(string)
    listeners = list(object({
      name                  = string
      targetPort            = number
      listenerPort          = number
      protocol              = string
      health_check_protocol = string
    }))
  }))
}
