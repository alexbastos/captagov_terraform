# 1. Buscar a AMI mais recente do Ubuntu 22.04 LTS na AWS
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # ID Oficial da Canonical (criadora do Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. Cadastro da Chave SSH para acesso à EC2
resource "aws_key_pair" "ec2_key" {
  key_name   = "auth-api-key"
  public_key = file("~/.ssh/id_rsa.pub") # 👈 Caminho para sua chave pública SSH no seu PC
}

# 3. Security Group da EC2
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-app-sg"
  description = "Security Group para a EC2 da API de Autenticacao"

  # Entrada: SSH (22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Recomendado em prod: Colocar o seu IP público aqui
  }

  # Entrada: HTTP (80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Entrada: HTTPS (443)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Entrada: Porta da sua API (exemplo: 3000)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Entrada: Porta do Frontend (3001)
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Saida: Permitir todo tráfego de saída (para baixar imagens docker, clonar git, etc)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-app-sg"
  }
}

# 4. IAM Role para a EC2 (Acesso ao SES)
resource "aws_iam_role" "ec2_role" {
  name = "auth-api-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ses_policy" {
  name = "auth-api-ses-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "auth-api-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# 5. Instância EC2
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro" # 2 vCPU, 1GB RAM (Elegível ao Free Tier da AWS)

  key_name               = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Tamanho do disco (20GB SSD)
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  # Script de inicialização automática (User Data)
  user_data = <<-EOF
              #!/bin/bash
              set -e

              # 1. Atualizar pacotes do sistema
              apt-get update -y
              apt-get install -y ca-certificates curl gnupg lsb-release git

              # 2. Instalar Docker
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
              chmod a+r /etc/apt/keyrings/docker.asc

              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null

              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

              # 3. Habilitar serviço do Docker e permissão ao usuário ubuntu
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu

              # 4. Clonar o Repositório e Iniciar com Docker Compose
              REPO_URL="https://github.com/alexbastos/authentication_api.git"
              APP_DIR="/home/ubuntu/app"

              git clone $REPO_URL $APP_DIR
              chown -R ubuntu:ubuntu $APP_DIR

              cd $APP_DIR

              # Obter IP publico da EC2 para definir como ISSUER do JWT
              PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

              # (Opcional) Criar o arquivo .env com as variáveis de ambiente
              cat <<EOT > .env
              DATABASE_URL=postgresql://auth_user:auth_password@postgres:5432/auth_db?schema=public
              REDIS_HOST=redis
              REDIS_PORT=6379
              JWT_ISSUER=http://$PUBLIC_IP:3000/authentication_api/api/v1/auth
              APP_URL=https://d1f5n4355y8u52.cloudfront.net
              EMAIL_PROVIDER=ses
              EMAIL_FROM_ADDRESS=nao-responda@capcode.com.br
              EOT

              # 5. Subir os contêineres via Docker Compose
              docker compose up -d
              EOF

  tags = {
    Name = "auth-api-server"
  }
}

# 5. Outputs para visualizar os IPs no terminal
output "ec2_public_ip" {
  description = "IP Público da EC2"
  value       = aws_instance.app_server.public_ip
}

output "ec2_ssh_command" {
  description = "Comando para conectar via SSH"
  value       = "ssh ubuntu@${aws_instance.app_server.public_ip}"
}