# =====================================================================
# AWS APP RUNNER HOSTING (Frontend Next.js)
# =====================================================================

# 1. Conexão com o GitHub (Requer autorização manual no Console)
resource "aws_apprunner_connection" "github" {
  connection_name = "captagov-github-connection"
  provider_type   = "GITHUB"
}

# 2. Serviço App Runner
resource "aws_apprunner_service" "frontend" {
  service_name = "captagov-frontend-${var.environment}"

  source_configuration {
    authentication_configuration {
      connection_arn = aws_apprunner_connection.github.arn
    }

    auto_deployments_enabled = true

    code_repository {
      repository_url = "https://github.com/alexbastos/captagov_frontend"
      source_code_version {
        type  = "BRANCH"
        value = "master"
      }
      code_configuration {
        # 'REPOSITORY' diz para o App Runner ler o arquivo 'apprunner.yaml' na raiz do seu projeto.
        # Não é possível selecionar "Dockerfile" diretamente via Terraform API como no Console.
        configuration_source = "REPOSITORY"
      }
    }
  }

  instance_configuration {
    cpu    = "1024" # 1 vCPU
    memory = "2048" # 2 GB
  }

  tags = {
    Environment = var.environment
    Project     = "captagov"
  }
}
