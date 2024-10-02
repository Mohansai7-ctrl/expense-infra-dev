#Root module is terraform-aws-vpc

module "vpc" {
    source = "git::https://github.com/Mohansai7-ctrl/terraform-aws-vpc.git?ref=main"
    #source = "../terraform-aws-vpc"
    #These are the variable names of root module, but not acts as arguments of this child module
    vpc_cidr = var.vpc_cidr
    project_name = var.project_name
    environment = var.environment
    common_tags = var.common_tags
    public_subnet_cidrs = var.public_subnet_cidrs
    private_subnet_cidrs = var.private_subnet_cidrs
    database_subnet_cidrs = var.database_subnet_cidrs
    is_peering_required = true
}