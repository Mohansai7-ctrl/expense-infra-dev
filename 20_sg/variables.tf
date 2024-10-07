variable "project_name" {
    default = "expense"
}

variable "environment" {
    default = "dev"
}


variable "mysql_sg_tags" {
    default = {
        Component = "mysql"
    }
}

variable "common_tags" {
    default = {
        Project = "expense"
        Terraform = "true"
        Environment = "dev"
    }
}

variable "backend_sg_tags" {
    default = {
        Component = "backend"
    }
}

variable "frontend_sg_tags" {
    default = {
        Component = "frontend"
    }
}

variable "bastion_sg_tags" {
    default = {
        Component = "bastion"
    }
}

variable "ansible_sg_tags" {
    default = {
        Component = "ansible"
    }
}

#backed load balancer tags:
variable "app_alb_sg_tags" {
    default = {
        Component = "app-alb"
    }
}



