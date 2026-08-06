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
