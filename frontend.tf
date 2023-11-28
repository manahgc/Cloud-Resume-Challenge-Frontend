#----------------------------------------------------------
#S3 BUCKET
#----------------------------------------------------------

#Provision Bucket for Static Website
resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name 
}

#Configure Bucket ACL for Public-Read Access
resource "aws_s3_bucket_acl" "website_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.website_bucket_ownership,
    aws_s3_bucket_public_access_block.website_bucket_public_access_block,
  ]

  bucket = aws_s3_bucket.website_bucket.id
  acl = "public-read"  

}

#Configure Bucket Policy for Public Access
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "PublicReadGetObject",
        "Effect": "Allow",
        "Principal": "*",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::${var.bucket_name}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_ownership_controls" "website_bucket_ownership" {
  bucket = aws_s3_bucket.website_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "website_bucket_public_access_block" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

#Configure Bucket Versioning
resource "aws_s3_bucket_versioning" "website_bucket_versioning" {
  bucket = aws_s3_bucket.website_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

#-----------------------------------------------------------
# Website Access logging
#----------------------------------------------------------
resource "aws_s3_bucket" "website_access_log_bucket" {
  bucket = var.access_log_bucket_name
}

resource "aws_s3_bucket_public_access_block" "website_access_log_public_access_block" {
  bucket = aws_s3_bucket.website_access_log_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "website_access_log_bucket_ownership" {
  bucket = aws_s3_bucket.website_access_log_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}


resource "aws_s3_bucket_acl" "website_access_log_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.website_access_log_bucket_ownership,
    aws_s3_bucket_public_access_block.website_access_log_public_access_block,
  ]

  bucket = aws_s3_bucket.website_access_log_bucket.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_logging" "website_bucket_logging" {
  bucket = aws_s3_bucket.website_bucket.id

  target_bucket = aws_s3_bucket.website_access_log_bucket.id
  target_prefix = "log/"
}

# resource "aws_s3_bucket_cors_configuration" "s3_website_cors_config" {
#   bucket = aws_s3_bucket.website_bucket.id

#   cors_rule {
#     allowed_headers = ["*"]
#     allowed_methods = ["PUT", "POST"]
#     allowed_origins = ["charlesmanah.com"]
#     expose_headers  = ["ETag"]
#     max_age_seconds = 3000
#   }

#   cors_rule {
#     allowed_methods = ["GET"]
#     allowed_origins = ["*"]
#   }
# }

#-------------------------------------------------------------
#Website Bucket Server Side Encryption
#-------------------------------------------------------------

resource "aws_kms_key" "website_bucket_key" {
  description = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website_bucket_serverside_encryption" {
  bucket = aws_s3_bucket.website_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.website_bucket_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

#--------------------------------------------------------------
# WEBSITE CONFIGURATION
#--------------------------------------------------------------

resource "aws_s3_bucket_website_configuration" "website_bucket_website_configuration" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
  
}

#-------------------------------------------------------
# Cloudfront Configuration 
#--------------------------------------------------------
resource "aws_cloudfront_origin_access_identity" "s3_website_OAI" {
  comment = "S3_website Bucket_OAI"
}
resource "aws_cloudfront_origin_access_control" "s3_website_OAC" {
  name                              = "s3_website"
  description                       = "s3_website_Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_website_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_website_OAC.id
    origin_id                = var.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "cloudresume-access-log-1234.s3.amazonaws.com"
    prefix          = "s3website"
  }

  aliases = ["charlesmanah.com"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = var.s3_origin_id
    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = var.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

    viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate.s3_website_cert.arn
    cloudfront_default_certificate = false
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }
}


#-------------------------------------------------------
# Domain Configuration
#-------------------------------------------------------
resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

resource "aws_route53_record" "website_cloudfront_record" {
  provider = aws
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_website_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_website_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

#--------------------------------------------------------------
# Amazon Certificate Manager (ACM)
#--------------------------------------------------------------

resource "aws_acm_certificate" "s3_website_cert" {
  domain_name       = "charlesmanah.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "primary" {
  name = aws_route53_zone.primary.name
  private_zone = false
}

resource "aws_route53_record" "domain_validation" {
  provider = aws
  for_each = {
    for dvo in aws_acm_certificate.s3_website_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id
}

resource "aws_acm_certificate_validation" "s3_website_cert_validation" {
  certificate_arn         = aws_acm_certificate.s3_website_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.domain_validation : record.fqdn]
}

# resource "aws_lb_listener" "example" {
#   certificate_arn = aws_acm_certificate_validation.example.certificate_arn
# }