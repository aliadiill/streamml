resource "aws_cloudfront_origin_access_control" "dashboard" {

  name                              = local.name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"

}
data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}
data "aws_cloudfront_origin_request_policy" "api" {
  name = "Managed-AllViewerExceptHostHeader"
}
resource "aws_cloudfront_response_headers_policy" "security" {

  name = "${local.name}-security"
  security_headers_config {

    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true

    }
    referrer_policy {
      referrer_policy = "same-origin"
      override        = true

    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true

    }
    content_security_policy {

      content_security_policy = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self' https://${aws_cognito_user_pool_domain.dashboard.domain}.auth.${var.region}.amazoncognito.com; object-src 'none'; base-uri 'self'; frame-ancestors 'none'"
      override                = true

    }

  }

}
resource "aws_cloudfront_distribution" "dashboard" {

  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  origin {

    domain_name              = aws_s3_bucket.this["web"].bucket_regional_domain_name
    origin_id                = "web"
    origin_access_control_id = aws_cloudfront_origin_access_control.dashboard.id

  }
  origin {

    domain_name = replace(aws_apigatewayv2_api.dashboard.api_endpoint, "https://", "")
    origin_id   = "api"
    custom_origin_config {

      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]

    }

  }
  default_cache_behavior {

    target_origin_id           = "web"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = true

  }
  ordered_cache_behavior {

    path_pattern               = "/api/*"
    target_origin_id           = "api"
    viewer_protocol_policy     = "https-only"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.api.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id

  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }

}
resource "aws_s3_bucket_policy" "this" {

  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  policy = jsonencode({

    Version = "2012-10-17",
    Statement = concat([{
      Sid    = "DenyInsecureTransport", Effect = "Deny", Principal = "*",
      Action = "s3:*", Resource = [each.value.arn, "${each.value.arn}/*"],
      Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
      }],
      each.key == "web" ? [{
        Sid = "CloudFrontRead", Effect = "Allow", Principal = {
          Service = "cloudfront.amazonaws.com"
        },
        Action = "s3:GetObject", Resource = "${each.value.arn}/*",
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.dashboard.arn
          }
        }
    }] : [])

  })

}

