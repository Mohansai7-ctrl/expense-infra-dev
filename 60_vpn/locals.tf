locals {
    resource_name = "${var.project_name}-${var.environment}"
    public_subnet_ids = split(",", data.aws_ssm_parameter.public_subnet_ids.value)[0]
    ami = data.aws_ami.ami_info.id
    vpn_sg_id = data.aws_ssm_parameter.vpn_sg_id.value
}