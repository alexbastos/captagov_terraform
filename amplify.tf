# =====================================================================
# AWS AMPLIFY HOSTING (Frontend Next.js)
# =====================================================================

resource "aws_amplify_app" "capta_frontend" {
  name         = "capta-frontend-${var.environment}"
  repository   = "https://github.com/alexbastos/captagov_frontend"
  access_token = var.github_access_token

  # Configuração para Next.js 14+ (Server-Side Rendering)
  platform = "WEB_COMPUTE"

  # Variável necessária para indicar que é um Monorepo
  environment_variables = {
    ENV                       = var.environment
    AMPLIFY_MONOREPO_APP_ROOT = "apps/web"
  }

  build_spec = <<-EOT
    version: 1
    applications:
      - frontend:
          phases:
            preBuild:
              commands:
                - npm install -g pnpm
                - pnpm install
            build:
              commands:
                - pnpm run build
          artifacts:
            baseDirectory: .next
            files:
              - '**/*'
          cache:
            paths:
              - .next/cache/**/*
              - node_modules/**/*
        appRoot: apps/web
  EOT
}

resource "aws_amplify_branch" "master" {
  app_id      = aws_amplify_app.capta_frontend.id
  branch_name = "master"

  enable_auto_build = true
  framework         = "Next.js - SSR"
}
