variable "app_alb_tags" {
    default = {
        Component = "app_alb"
    }
}

variable "zone_name" {
    default = "mohansai.online"
}

variable "project_name" {
    default = "expense"
}

variable "environment" {
    default = "dev"
}

variable "common_tags" {
    default = {
        Project = "expense"
        Terraform = true
        Environment = "dev"
    }
}