module "web_alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = local.resource_name
  vpc_id  = local.vpc_id
  subnets = ["local.public_subnet_ids"]

  
  tags = merge(
    var.common_tags,
    var.web_alb_tags,
    {
        Name = local.resource_name
    }
  )
}

resource "aws_lb_listener" "web_alb_http" {
  load_balancer_arn = module.web_alb.arn
  port              = "80"
  protocol          = "HTTP"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = local.https_certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = ".<h1>This is from web alb http 80<h2>"
      status_code  = "200"
    }
  }

}

resource "aws_lb_listener" "web_alb_https" {
  load_balancer_arn = module.web_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = local.https_certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = ".<h1>This is from web alb https 443<h2>"
      status_code  = "200"
    }
  }

}


module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  
  zone_name = var.zone_name
  records = [
    {
      name    = "expense-${var.environment}"  #expense-dev.zone_name == expense-dev.mohansai.online
      type    = "A"
      
      alias   = {
        name    = module.web_alb.dns_name  # DNS Name of web_alb
        zone_id = module.web_alb.zone_id    #Zone_id of web_alb
      }
      allow_overwrite = true  
    
    }

  ]
  

}

  



