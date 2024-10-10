locals {
    resource_name = "${var.project_name}-${var.environment}-web_alb"
    vpc_id = data.aws_ssm_parameter.vpc_id.id
    public_subnet_ids = split(",", data.aws_ssm_parameter.public_subnet_ids.value)
    https_certificat_arn = data.aws_ssm_parameter.https_certificat_arn.value
}