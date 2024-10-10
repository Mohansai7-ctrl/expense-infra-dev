resource "aws_ssm_parameter" "https_certificat_arn" {
    name = "/${var.project_name}/${var.environment}/https_certificate_arn"
    value = aws_acm_certificate.expense.arn
    type = "String"

}