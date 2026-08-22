# =====================================================================
# 1. AWS API Gateway (HTTP API)
# =====================================================================
resource "aws_apigatewayv2_api" "http_api" {
  name          = "api-gateway-${var.environment}"
  protocol_type = "HTTP"
  description   = "API Gateway for Identity Provider and Microservices"

  cors_configuration {
    allow_origins     = ["https://d3hxgfwn86i4hl.cloudfront.net", "http://localhost:5173", "http://localhost:3000", "http://localhost:3001"]
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers     = ["Content-Type", "Authorization"]
    allow_credentials = true
  }
}

# =====================================================================
# 2. Estágio Default (Deploy automático)
# =====================================================================
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# =====================================================================
# 3. JWT Authorizer
# =====================================================================
# resource "aws_apigatewayv2_authorizer" "jwt" {
#   api_id           = aws_apigatewayv2_api.http_api.id
#   authorizer_type  = "JWT"
#   identity_sources = ["$request.header.Authorization"]
#   name             = "jwt-authorizer-${var.environment}"
#
#   jwt_configuration {
#     issuer   = "http://${aws_instance.app_server.public_ip}:3000/authentication_api/api/v1/auth"
#     audience = [] # Pode ser configurado se a API validar Audience
#   }
# }

# =====================================================================
# 4. Integration: Auth Service (Pública)
# =====================================================================
resource "aws_apigatewayv2_integration" "auth_service" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_instance.app_server.public_ip}:3000/authentication_api/api/v1/auth/{proxy}"
  integration_method = "ANY"
}

# Rota pública para Autenticação (Login, Register, JWKS)
resource "aws_apigatewayv2_route" "auth_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /authentication_api/api/v1/auth/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.auth_service.id}"
  # Rota sem authorization_type (Pública)
}

# =====================================================================
# 5. Integration: Outros Serviços (Protegida)
# =====================================================================
resource "aws_apigatewayv2_integration" "other_service" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_instance.app_server.public_ip}:3000/authentication_api/api/v1/users/{proxy}"
  integration_method = "ANY"
}

# Rota protegida (Exemplo: Users API, Payments API)
resource "aws_apigatewayv2_route" "protected_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /authentication_api/api/v1/users/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.other_service.id}"

  # Exige o token JWT válido validado pelo Authorizer
  # authorization_type = "JWT"
  # authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

# Rota exata para chamadas na raiz (ex: GET /authentication_api/api/v1/users)
resource "aws_apigatewayv2_integration" "other_service_exact" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_instance.app_server.public_ip}:3000/authentication_api/api/v1/users"
  integration_method = "ANY"
}

resource "aws_apigatewayv2_route" "protected_route_exact" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /authentication_api/api/v1/users"
  target    = "integrations/${aws_apigatewayv2_integration.other_service_exact.id}"
}

# =====================================================================
# 6. Integration: Client Apps (Protegida)
# =====================================================================
resource "aws_apigatewayv2_integration" "client_apps_service" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_instance.app_server.public_ip}:3000/authentication_api/api/v1/client-apps/{proxy}"
  integration_method = "ANY"
}

resource "aws_apigatewayv2_route" "client_apps_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /authentication_api/api/v1/client-apps/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.client_apps_service.id}"

  # Futuramente pode habilitar o Authorizer aqui:
  # authorization_type = "JWT"
  # authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

# Rota exata para chamadas na raiz (ex: GET /authentication_api/api/v1/client-apps)
resource "aws_apigatewayv2_integration" "client_apps_service_exact" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_instance.app_server.public_ip}:3000/authentication_api/api/v1/client-apps"
  integration_method = "ANY"
}

resource "aws_apigatewayv2_route" "client_apps_route_exact" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /authentication_api/api/v1/client-apps"
  target    = "integrations/${aws_apigatewayv2_integration.client_apps_service_exact.id}"
}

# =====================================================================
# 7. Integration: Swagger Docs (Pública)
# =====================================================================
resource "aws_apigatewayv2_integration" "swagger_service" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_instance.app_server.public_ip}:3000/docs/authentication_api/{proxy}"
  integration_method = "ANY"
}

resource "aws_apigatewayv2_route" "swagger_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /docs/authentication_api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.swagger_service.id}"
}

# Rota exata caso precise acessar /docs sem barra no final
resource "aws_apigatewayv2_integration" "swagger_service_exact" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_instance.app_server.public_ip}:3000/docs/authentication_api"
  integration_method = "ANY"
}

resource "aws_apigatewayv2_route" "swagger_route_exact" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /docs/authentication_api"
  target    = "integrations/${aws_apigatewayv2_integration.swagger_service_exact.id}"
}

# =====================================================================
# 8. Integration: Health Check (Pública)
# =====================================================================
resource "aws_apigatewayv2_integration" "health_service" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_instance.app_server.public_ip}:3000/health/authentication_api"
  integration_method = "ANY"
}

resource "aws_apigatewayv2_route" "health_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /health/authentication_api"
  target    = "integrations/${aws_apigatewayv2_integration.health_service.id}"
}
# =====================================================================
# 9. Integration: Frontend (Default Route)
# =====================================================================
resource "aws_apigatewayv2_integration" "frontend_service" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "http://${aws_instance.app_server.public_ip}:3001"
  integration_method = "ANY"
}

resource "aws_apigatewayv2_route" "frontend_default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.frontend_service.id}"
}
