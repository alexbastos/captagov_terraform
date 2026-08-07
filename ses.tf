# Configuração da Identidade de E-mail no Amazon SES (Modo Sandbox)
# A AWS enviará um e-mail de verificação para este endereço assim que o Terraform for aplicado.
resource "aws_ses_email_identity" "api_email" {
  email = "capcodesolucoes@gmail.com"
}
