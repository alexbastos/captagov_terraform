# Configuração da Identidade de E-mail no Amazon SES (Modo Sandbox)
# A AWS enviará um e-mail de verificação para este endereço assim que o Terraform for aplicado.
resource "aws_ses_email_identity" "api_email" {
  email = "capcodesolucoes@gmail.com"
}

resource "aws_ses_email_identity" "automatizy_email" {
  email = "automatizycompany@gmail.com"
}

# Identidade de Domínio
resource "aws_ses_domain_identity" "domain" {
  domain = "capcode.com.br"
}

# Geração dos tokens DKIM para o domínio
resource "aws_ses_domain_dkim" "dkim" {
  domain = aws_ses_domain_identity.domain.domain
}
