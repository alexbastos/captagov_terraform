# CaptaGov - Infraestrutura AWS com Terraform

Este repositório contém os scripts do Terraform responsáveis por provisionar a infraestrutura do projeto na AWS. O ambiente provisiona desde a rede básica até banco de dados, servidores de aplicação, API Gateway, serviços de email (SES) e hospedagem estática/frontend.

## Arquitetura e Recursos Provisionados

Abaixo está o detalhamento de todos os recursos da AWS que são criados por este projeto:

### 1. Computação (EC2) - `ec2.tf`
- **Instância EC2 (`auth-api-server`)**: 
  - Máquina `t3.micro` (elegível ao Free Tier) utilizando Ubuntu 22.04 LTS e disco de 20GB SSD (`gp3`).
  - **Automação de Inicialização (User Data)**: A instância é iniciada com um script que:
    1. Instala o Docker e Docker Compose.
    2. Clona o repositório da API de Autenticação (`alexbastos/authentication_api`).
    3. Cria o arquivo `.env` injetando credenciais do banco e configurações.
    4. Sobe os contêineres da aplicação backend, banco de dados (PostgreSQL) e cache (Redis) através do `docker compose`.
  - **Chave SSH (`auth-api-key`)**: Utiliza a chave pública localizada em `~/.ssh/id_rsa.pub` para acesso remoto seguro.
  - **Security Group (`ec2-app-sg`)**: Libera tráfego de entrada para SSH (22), HTTP (80), HTTPS (443), Backend (3000) e Frontend (3001).
  - **Perfil IAM**: A instância possui permissão nativa para enviar emails utilizando o Amazon SES via Roles.

### 2. Frontend em EC2 - `frontend_ec2_deploy.tf`
- **Deploy automatizado do Next.js via SSH**: 
  - O script acessa a EC2 e cria um arquivo de **Swap de 2GB** para evitar travamentos de OOM (Out of Memory).
  - Clona ou atualiza automaticamente o repositório do frontend (`alexbastos/captagov_frontend`).
  - Cria o `.env` com a URL correta do API Gateway.
  - Constrói (build) a imagem Docker e sobe o contêiner do frontend na porta `3001` da mesma instância.

### 3. API Gateway - `api_gateway.tf`
- **HTTP API Gateway**: Atua como o ponto de entrada principal e seguro para as requisições web.
- **Integrações e Rotas**:
  - Configuração de proxy reverso HTTP para direcionar requisições públicas (ex: `/authentication_api/api/v1/auth`) para o serviço na porta `3000` da EC2.
  - Integrações nativas com configurações de CORS para permitir chamadas seguras oriundas do frontend.

### 4. Email (SES) - `ses.tf`
- **Amazon SES (Simple Email Service)**: 
  - Configuração de domínio verificado (ex: `capcode.com.br`) e geração de chaves DKIM (DomainKeys Identified Mail) para garantir a reputação e a entrega dos e-mails.
  - Verificação de e-mails remetentes individuais.

### 5. Rede e Conectividade (VPC) - `vpc.tf`
- **VPC (`vpc-microservices-dev`)**: Rede virtual isolada com bloco CIDR `10.0.0.0/16`.
- **Internet Gateway**: Para permitir tráfego da internet aos recursos da VPC.
- **Subnets Públicas**: Duas subnets públicas (`10.0.1.0/24` e `10.0.2.0/24`) em diferentes zonas de disponibilidade para alta disponibilidade.
- **Tabela de Roteamento**: Roteamento padrão enviando tráfego não local para a internet.

### 6. Armazenamento Estático (S3 + CloudFront) - `frontend_s3_cloudfront.tf`
- **Amazon S3**: Buckets privados criados para armazenamento. Acesso público totalmente bloqueado.
- **Amazon CloudFront**: CDN global configurada para distribuir de forma rápida conteúdo estático armazenado no S3 via HTTPS.
- **Origin Access Control (OAC)**: Restringe que apenas a CDN tenha acesso direto aos buckets.

### 7. Gestão de Custos - `cost_management.tf`
- **AWS Budgets**: Configuração de orçamento/alarme financeiro para monitorar custos e enviar um alerta por e-mail caso os gastos previstos ultrapassem uma quantia simbólica (ex: $5 dólares mensais).

---

## Como Executar

### Pré-requisitos
- Conta configurada na AWS e `aws-cli` configurado (`aws configure`).
- Chave SSH gerada no seu computador (por padrão, o script espera que o arquivo exista em `~/.ssh/id_rsa.pub`).

### Comandos Básicos

```bash
# Inicializa o backend do Terraform e baixa os plugins/provedores
terraform init

# Formata o código para os padrões do Terraform
terraform fmt

# Exibe o plano de execução com todas as alterações que serão feitas
terraform plan

# Aplica as configurações e cria (ou atualiza) os recursos na AWS
terraform apply
```

### Para Destruir a Infraestrutura
Lembre-se de destruir os recursos após o uso (para evitar cobranças prolongadas na AWS):

```bash
terraform destroy
```
