#We are pushing vpc_id and *_subnet_ids to ssm_parameter

resource "aws_ssm_parameter" "vpc_id" {
    name = "/${var.project_name}/${var.environment}/vpc_id"  #name you want to give for amazon Systems Manager (SSM)
    value = module.vpc.vpc_id   #vpc_id Which we want to store or push to ssm
    type = "String"


}

resource "aws_ssm_parameter" "public_subnet_ids" {
    name = "/${var.project_name}/${var.environment}/public_subnet_ids"
    value = join(",", module.vpc.public_subnet_ids)  #if we set the value directly, terrform ssm wont allow, as it needs to send as StringList, to convert list to StringList, here we are using join
    type = "StringList"
}

resource "aws_ssm_parameter" "private_subnet_ids" {
    name = "/${var.project_name}/${var.environment}/private_subnet_ids"
    value = join(",", module.vpc.private_subnet_ids)
    type = "StringList"
}

resource "aws_ssm_parameter" "database_subnet_ids" {
    name = "/${var.project_name}/${var.environment}/database_subnet_ids"
    value = join(",", module.vpc.database_subnet_ids)
    type = "StringList"
}

resource "aws_ssm_parameter" "database_subnet_group_name" {  #resource_name == database_subnet_group_name is used in root module output name , there it as "output "database_subnet_group_name" and its value as value = aws_db_subnet_group.default.name
    name = "/${var.project_name}/${var.environment}/database_subnet_group_name"
    value = module.vpc.database_subnet_group_name
    type = "String"
}