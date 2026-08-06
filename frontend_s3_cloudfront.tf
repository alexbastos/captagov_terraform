# =====================================================================
# 1. BUCKET S3 (Armazenamento dos arquivos do Frontend)
# =====================================================================
resource "aws_s3_bucket" "frontend" {
  bucket        = "captagov-s3"
  force_destroy = true

  tags = {
    Name        = "Frontend Static Hosting"
    Environment = "dev"
  }
}

# Bloqueia todo acesso público direto ao S3 (Garante que só o CloudFront acesse)
resource "aws_s3_bucket_public_access_block" "frontend_public_access" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =====================================================================
# 2. ORIGIN ACCESS CONTROL - OAC (Autenticação entre CloudFront e S3)
# =====================================================================
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "frontend-s3-oac"
  description                       = "Permite que o CloudFront acesse o S3 de forma privada"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# =====================================================================
# 3. CLOUDFRONT DISTRIBUTION (CDN Global + Suporte a Rotas SPA)
# =====================================================================
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = "S3-${aws_s3_bucket.frontend.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  # Configuração padrão de Cache e HTTPS
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # -------------------------------------------------------------------
  # SUPORTE A MÚLTIPLAS ROTAS PARA SPAs (React, Vue, Angular)
  # Redireciona erros 403 e 404 para o index.html com status 200 OK
  # -------------------------------------------------------------------
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  # Restrições Geográficas (Sem restrições)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Certificado SSL padrão da AWS para o domínio *.cloudfront.net
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Environment = "dev"
  }
}

# =====================================================================
# 4. S3 BUCKET POLICY (Apenas o CloudFront pode ler os arquivos)
# =====================================================================
resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })

  # Garante que as travas de acesso público já foram aplicadas antes da política
  depends_on = [aws_s3_bucket_public_access_block.frontend_public_access]
}