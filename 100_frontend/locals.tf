locals {
    resource_name = "${var.project_name}-${var.environment}-frontend"
    ami = data.aws_ami.ami_info.id
    backend_sg_id = data.aws_ssm_parameter.frontend_sg_id.value
    public_subnet_ids = split(",", data.aws_ssm_parameter.public_subnet_ids.value)[0]
    vpc_id = data.aws_ssm_parameter.vpc_id.value
    
}