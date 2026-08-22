# =====================================================================
# DEPLOY DO FRONTEND NA MESMA EC2
# =====================================================================

resource "null_resource" "deploy_frontend_ec2" {
  # O trigger abaixo faz com que esse script rode toda vez que houver uma alteração ou aplicar o Terraform
  triggers = {
    always_run = timestamp()
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa") # Chave usada para acessar a EC2
    host        = aws_instance.app_server.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "echo '==> 1. Configurando Memória Swap (2GB) para evitar travamentos (OOM)...'",
      "if [ ! -f /swapfile ]; then",
      "  sudo fallocate -l 2G /swapfile",
      "  sudo chmod 600 /swapfile",
      "  sudo mkswap /swapfile",
      "  sudo swapon /swapfile",
      "  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab",
      "else",
      "  echo 'Swap já configurado.'",
      "fi",

      "echo '==> 2. Clonando o repositório do Frontend...'",
      "cd /home/ubuntu",
      "if [ ! -d 'captagov_frontend' ]; then",
      "  git clone https://github.com/alexbastos/captagov_frontend.git",
      "  cd captagov_frontend",
      "else",
      "  cd captagov_frontend",
      "  git pull origin master",
      "fi",

      "echo '==> 3. Criando variáveis de ambiente (.env)...'",
      "cat <<EOT > .env",
      "AUTHENTICATION_API_BASE_URL=https://bwtp7pm5pc.execute-api.us-east-1.amazonaws.com",
      "CAPTAGOV_APP_ORIGIN=http://${aws_instance.app_server.public_ip}:3001",
      "EOT",

      "echo '==> 4. Construindo e subindo o contêiner do Frontend na porta 3001...'",
      "git checkout package.json || true",
      "git checkout Dockerfile || true",
      "sed -i -E 's/\"packageManager\": \"pnpm@[0-9.]+\"/\"packageManager\": \"pnpm@11.16.0\"/' package.json || true",
      "docker build -t captagov-frontend .",
      "docker stop captagov-frontend-container || true",
      "docker rm captagov-frontend-container || true",
      "docker run -d --restart unless-stopped --name captagov-frontend-container -p 3001:3000 --env-file .env captagov-frontend",

      "echo '==> DEPLOY DO FRONTEND CONCLUÍDO COM SUCESSO! <=='"
    ]
  }

  # Assegurar que a EC2 já foi criada antes de rodar este script
  depends_on = [aws_instance.app_server]
}
