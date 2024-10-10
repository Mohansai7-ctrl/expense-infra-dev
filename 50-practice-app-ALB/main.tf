#creating app_alb module.

module "app_alb" {
  source = "terraform-aws-modules/alb/aws"

  internal = true  #means creating app-alb in private subnet within internal vpc network
  name    = "${var.project_name}-${var.environment}-app-alb" #As this is name tag, should not use underscore
  vpc_id  = local.vpc_id
  subnets = local.private_subnet_ids
  create_security_group = false #as we already security group in 20_sg
  security_groups = [local.security_groups]
  enable_deletion_protection = false  #Here while destroying the load balancer, as false is configured deletion protection wont be there



  tags = merge(
    var.common_tags,
    var.app_alb_tags

  )
    
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = module.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  #forward action, redirect action, fixed response action,authenticat oidc/cognito action - these are different type of actions present. Here we are using fixed response action just to check the app alb
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<h1>Hello, This is bakcned or app application load balancer alb</h1>"
      status_code  = "200"
    }
  }
}

#creating records by alias for the app_alb

module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  
  zone_name = var.zone_name

  records = [
    {
      name    = "*.app-${var.environment}"  #  *.app-expense.mohansai.online
      type    = "A"
      alias   = {   #If alias is used, then no need to give ttl
        name    = module.app_alb.dns_name  #dns_name is fixed dns name and zone_id, these values will get from created app_alb module
        zone_id = module.app_alb.zone_id #This belongs ALB internal hosted zone, not ours
      }
      allow-overwrite = true
    }
  ]

  
}