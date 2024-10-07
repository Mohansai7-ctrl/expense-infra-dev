#Root module is terraform-aws-security-group

#created security group for mysql server
module "mysql_sg" {
    #source = "git::https://github.com/Mohansai7-ctrl/terraform-aws-security-group.git?ref=main"
    source = "../../terraform-aws-security-group"
    vpc_id = local.vpc_id
    project_name = var.project_name
    environment = var.environment
    common_tags = var.common_tags
    sg_tags = var.mysql_sg_tags
    sg_name = "mysql"
}

#creating security group for backend server

module "backend_sg" {
    source = "git::https://github.com/Mohansai7-ctrl/terraform-aws-security-group.git?ref=main"
    vpc_id = local.vpc_id
    project_name = var.project_name
    environment = var.environment
    common_tags = var.common_tags
    sg_name = "backend"
    sg_tags = var.backend_sg_tags
}

#Creating sg group for frontend server:

module "frontend_sg" {
    source = "git::https://github.com/Mohansai7-ctrl/terraform-aws-security-group.git?ref=main"
    vpc_id = local.vpc_id
    project_name = var.project_name
    environment = var.environment
    common_tags = var.common_tags
    sg_name = "frontend"
    sg_tags = var.frontend_sg_tags
}

#creating bastion server security group, bastion server is for internal/organization employees/users to connect to servers via bastion via organization network instead of public network:
module "bastion_sg" {
    source = "git::https://github.com/Mohansai7-ctrl/terraform-aws-security-group.git?ref=main"
    vpc_id = local.vpc_id
    project_name = var.project_name
    environment = var.environment
    common_tags = var.common_tags
    sg_name = "bastion"
    sg_tags = var.bastion_sg_tags
}

#creating ansible security group becuase as we are integrating ansible with terraform so that to complete configuration management of all 3 servers:

module "ansible_sg" {
    source = "git::https://github.com/Mohansai7-ctrl/terraform-aws-security-group.git?ref=main"
    vpc_id = local.vpc_id
    project_name = var.project_name
    environment = var.environment
    common_tags = var.common_tags
    sg_name = "ansible"
    sg_tags = var.ansible_sg_tags
}

#creating security group for app_alb application load balancer
module "app_alb_sg" {
    source = "git::https://github.com/Mohansai7-ctrl/terraform-aws-security-group.git?ref=main"
    vpc_id = local.vpc_id
    project_name = var.project_name
    environment = var.environment
    common_tags = var.common_tags
    sg_name = "app_alb"
    sg_tags = var.app_alb_sg_tags

}

#As in root module ("terraform-aws-security_group"), we only provided egress, now we are providing security group rule for inbound-ingress for each server:

#Also here ports are two cases:
# i) Application port - if backend wants to connect to mysql, as here it just connecting/updating/deleting the content, so it requires application port of mysql port,  that is 3306

# ii) Server Port: if ansbile wants to connect to frontend server to install it or to do any changes in the frontend server, then it should have server port that is port 22


resource "aws_security_group_rule" "mysql_backend" { #mysql_backend == mysql allowing the requests/connects from backend
    type = "ingress"
    from_port = 3306  #as backend to enter mysql, mysql ports 3306 needs to be opened. == backend is a source connecting to mysql. accepting ports 
    to_port = 3306  #Application Port
    protocol = "tcp"
    source_security_group_id = module.backend_sg.id  #To use this attribute id, in root module outputs.tf it should define first, in outputs it will be used as resource_type.resource_name.attribute
    security_group_id = module.mysql_sg.id

}

#As app ALB is introduced in private subnet and in between frontend application and backend application,
# below is not correct, hence commenting:

# resource "aws_security_group_rule" "backend_frontend" {  #Source(frontend) ---------> is connecting to ------> destination(backend)
#     type = "ingress"
#     from_port = 8080
#     to_port = 8080
#     protocol = "tcp"
#     source_security_group_id = module.frontend_sg.id
#     security_group_id = module.backend_sg.id

# }

#creating app_alb is connecting to backend:
#commenting below as duplicate:
# resource "aws_security_group_rule" "backend_app_alb" {
#     type = "ingress"
#     from_port = 8080
#     to_port = 8080
#     protocol = "tcp"
#     source_security_group_id = module.app_alb_sg.id
#     security_group_id = module.backend_sg.id
# }

#now frontend application is connecting to backend app alb:
#commenting below as duplicate:
# resource "aws_security_group_rule" "app_alb_bastion" {
#     type = "ingress"
#     from_port = 80
#     to_port = 80
#     protocol = "tcp"
#     source_security_group_id = module.bastion_sg.id
#     security_group_id = module.app_alb_sg.id
# }

resource "aws_security_group_rule" "frontend_public" {
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.frontend_sg.id

}

#now bastion needs to connec to frontend, backend, and mysql

resource "aws_security_group_rule" "mysql_bastion" {  #bastion is a source connecting to mysql
    type = "ingress"
    from_port = 3306  #Server Port if rds is introduced then db port should be 3306, if only db in ec2 instance then port can be 22
    to_port = 3306
    protocol = "tcp"
    source_security_group_id = module.bastion_sg.id
    security_group_id = module.mysql_sg.id
}

resource "aws_security_group_rule" "backend_bastion" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    source_security_group_id = module.bastion_sg.id
    security_group_id = module.backend_sg.id
}

resource "aws_security_group_rule" "frontend_bastion" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    source_security_group_id = module.bastion_sg.id
    security_group_id = module.frontend_sg.id
}


#Here to troubleshoot any issues, organization employees can connect via bastion to access servers, here the actual cidr block should be organization IP.
resource "aws_security_group_rule" "bastion_public" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  #As source here is Public, we need to use cidr block instead of security group
    security_group_id = module.bastion_sg.id
}

#creating inbound rules of ansible with each server except with bastion:

resource "aws_security_group_rule" "mysql_ansible" {
    type = "ingress"
    from_port = 3306  #Server Port if rds is introduced then db port should be 3306, if only db in ec2 instance then port can be 22
    to_port = 3306
    protocol = "tcp"
    source_security_group_id = module.ansible_sg.id
    security_group_id = module.mysql_sg.id
}

resource "aws_security_group_rule" "backend_ansible" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    source_security_group_id = module.ansible_sg.id
    security_group_id = module.backend_sg.id
}

resource "aws_security_group_rule" "frontend_ansible" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    source_security_group_id = module.ansible_sg.id
    security_group_id = module.frontend_sg.id
}

#Here to troubleshoot any issues, to connect to servers to perform/manage the servers, ansible can connect via public, here the actual cidr block should be organization IP.
resource "aws_security_group_rule" "ansible_public" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  #As source is public, we need to use cidr block instead of using Security Group
    security_group_id = module.ansible_sg.id

}

#creating security group rules for load balancer
#i) alb is connecting to backend

resource "aws_security_group_rule" "backend_app_alb" {
    type = "ingress"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    source_security_group_id = module.app_alb_sg.id
    security_group_id = module.backend_sg.id

}

#ii) bastion connecting to app_alb

resource "aws_security_group_rule" "app_alb_bastion" {
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.app_alb_sg.id
}

#To access the backend app alb , then backend application, rds db from bastion (logging into the bastion server),
# but to access the same from your laptop(browser), then you need vpn server installation.

# Hence, Creating vpn security group:

module "vpn_sg" {
    source = "git::https://github.com/Mohansai7-ctrl/terraform-aws-security-group.git?ref=main"
    vpc_id = local.vpc_id
    project_name = var.project_name
    environment = var.environment
    common_tags = var.common_tags
    sg_name = "vpn"
    
}

#Creating vpn security group rules: public--->vpn and vpn --->app_alb
#for vpn, ssh port 22 and vpn ports like 443, 943 and 1194 should be opened
resource "aws_security_group_rule" "vpn_public" {   
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.vpn_sg.id

}

resource "aws_security_group_rule" "vpn_public_443" {
    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.vpn_sg.id
}

resource "aws_security_group_rule" "vpn_public_943" {
    type = "ingress"
    from_port = 943
    to_port = 943
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.vpn_sg.id
}

resource "aws_security_group_rule" "vpn_public_1194" {
    type = "ingress"
    from_port = 1194
    to_port = 1194
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.vpn_sg.id
}

#now vpn is going to connect to backend alb via port 80
resource "aws_security_group_rule" "app_alb_vpn" {
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    source_security_group_id = module.vpn_sg.id
    security_group_id = module.app_alb_sg.id
}

#now vpn is going to connect to backend app via port 22 and 8080
resource "aws_security_group_rule" "app_alb_vpn_22" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    source_security_group_id = module.vpn_sg.id
    security_group_id = module.app_alb_sg.id
}

resource "aws_security_group_rule" "app_alb_vpn_8080" {
    type = "ingress"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    source_security_group_id = module.vpn_sg.id
    security_group_id = module.app_alb_sg.id
}

