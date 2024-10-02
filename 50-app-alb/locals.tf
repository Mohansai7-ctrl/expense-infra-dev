locals {
    #app_alb_sg_id = data.aws_ssm_parameter.app_alb_sg_id.value
    private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.value)
    vpc_id = data.aws_ssm_parameter.vpc_id.value
    resource_name = "${var.project_name}-${var.environment}"
}