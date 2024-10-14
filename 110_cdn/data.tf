data "aws_cloudfront_cache_policy" "noCache" {  #fetching/getting the cache_policy_id 's from aws cloudfront cache policy
    name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "cacheOptimized" {
    name = "Managed-CachingOptimized"
}

data "aws_ssm_parameter" "https_certificate_arn" {
    name = "/${var.project_name}/${var.environment}/https_certificate_arn"
}