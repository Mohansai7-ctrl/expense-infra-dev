resource "aws_ssm_parameter" "web_alb_listener_arn" {
    name = "/${var.project_name}/${var.environment}/web_alb_listener_arn"
    value = aws_lb_listener.web_alb_https.arn
    type = "String"
}