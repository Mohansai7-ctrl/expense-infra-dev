locals {
    vpc_id = data.aws_ssm_parameter.vpc_id.value  #checking/getting the value of vpc_id
}

