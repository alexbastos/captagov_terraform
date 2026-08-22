output "api_gateway_url" {
  description = "The invoke URL of the API Gateway"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "capta_gov_cloudfront_url" {
  description = "The domain name of the Capta Gov CloudFront distribution"
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "frontend_test_cloudfront_url" {
  description = "The domain name of the Frontend Test CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend_test_distribution.domain_name
}

output "ses_domain_verification_record_name" {
  description = "Host (Nome) para o registro TXT de verificacao na Hostinger"
  value       = "_amazonses.${aws_ses_domain_identity.domain.domain}"
}

output "ses_domain_verification_record_type" {
  description = "Tipo do registro para verificacao do SES"
  value       = "TXT"
}

output "ses_domain_verification_record_value" {
  description = "Valor do registro TXT de verificacao na Hostinger"
  value       = aws_ses_domain_identity.domain.verification_token
}

output "ses_dkim_verification_records" {
  description = "Registros CNAME para configurar o DKIM na Hostinger"
  value = [
    for token in aws_ses_domain_dkim.dkim.dkim_tokens : {
      name  = "${token}._domainkey.${aws_ses_domain_identity.domain.domain}"
      type  = "CNAME"
      value = "${token}.dkim.amazonses.com"
    }
  ]
}

output "ec2_frontend_url" {
  description = "URL do Frontend rodando na mesma EC2 (acessível via API Gateway HTTPS)"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}
