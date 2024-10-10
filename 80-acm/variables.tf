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
        Environment = "dev"
        Terraform = true
    }
}

variable "zone_id" {
    default = "Z01771702MEQ3I9CTODSQ"
}