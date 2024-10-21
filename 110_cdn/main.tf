resource "aws_cloudfront_distribution" "expense" {
  origin {   #origin can be anythings, s3, http or any web server, web services like Elementary MediaPackages and MediaStore, ALB and API Gateway ...etc.,.
    domain_name              = "${var.project_name}-${var.environment}.${var.zone_name}" #expense-dev.mohansai.online ---> this request forwards or towards the expense website
    
    origin_id                = "${var.project_name}-${var.environment}.${var.zone_name}"

    custom_origin_config {
    http_port = 80
    https_port = 443
    origin_protocol_policy = "https-only"
    origin_ssl_protocols = ["TLSv1.2"]
    
    }
    

  
  }

  
  enabled             = true
  

  aliases = ["${var.project_name}-cdn.${var.zone_name}"]  #expense-cdn.mohansai.online


 #default_cache behavior its last in the preferences, dynamic content evaluated at last and no cache
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.project_name}-${var.environment}.${var.zone_name}"

    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400   #1 hr to 1 day
    cache_policy_id = data.aws_cloudfront_cache_policy.noCache.id
  }


  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/images/*"  #static or cdn content will be cached at path expense-cdn.mohansai.online/images/*
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${var.project_name}-${var.environment}.${var.zone_name}"

    

    min_ttl                = 0 
    default_ttl            = 86400   #1 day to 365 days
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id = data.aws_cloudfront_cache_policy.cacheOptimized.id
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/static/*"   #static or cdn content will be cached at path expense-cdn.mohansai.online/static/*
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${var.project_name}-${var.environment}.${var.zone_name}"

    

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id = data.aws_cloudfront_cache_policy.cacheOptimized.id
  }

  
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "IN", "CA", "GB", "DE"]
    }
  }

  tags = merge(
    var.common_tags,
    var.cdn_tags,
    {
        Name = local.resource_name
    }
  )

  viewer_certificate {
    acm_certificate_arn = local.https_certificate_arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"

  zone_name = var.zone_name #mohansai.online
  records = [
    {
      name    = "expense-cdn" # expense-cdn.mohansai.online 
      type    = "A"
      alias   = {
        name    = aws_cloudfront_distribution.expense.domain_name
        zone_id = aws_cloudfront_distribution.expense.hosted_zone_id # This belongs CDN internal hosted zone, not ours
      }
      allow_overwrite = true
    }
  ]
}