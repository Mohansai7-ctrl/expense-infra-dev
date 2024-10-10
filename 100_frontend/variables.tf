variable "project_name" {
    default = "expense"
}

variable "environment" {
    default = "dev"
}

variable "common_tags" {
    default = {
        Project = "expnese"
        Terraform = true
        Environment = "dev"
        
    }
}

variable "backend_tags" {
    default = {
        Component = "frontend"
        
    }
}

variable "zone_name" {
    default = "mohansai.online"
}