# CaptaGov - Infraestrutura AWS com Terraform

Este repositório contém os scripts do Terraform responsáveis por provisionar a infraestrutura do projeto na AWS. O ambiente é voltado para testes/desenvolvimento (`dev`), e provisiona desde a rede básica até banco de dados, servidores de aplicação, API Gateway e hospedagem estática de frontend.

## Arquitetura e Recursos Provisionados

Abaixo está o detalhamento de todos os recursos da AWS que são criados por este projeto:

### 1. Rede e Conectividade (VPC) - `vpc.tf`
- **VPC (`vpc-microservices-dev`)**: Rede virtual isolada com bloco CIDR `10.0.0.0/16`.
- **Internet Gateway**: Para permitir acesso à internet para os recursos da VPC.
- **Subnets Públicas**: Duas subnets públicas (`10.0.1.0/24` e `10.0.2.0/24`) em zonas de disponibilidade diferentes para alta disponibilidade.
- **Tabela de Roteamento (Route Table)**: Configurada para direcionar o tráfego externo para o Internet Gateway, permitindo que instâncias e bancos de dados (quando configurados) acessem a internet.

### 2. Bancos de Dados e Cache - `databases.tf`
- **RDS PostgreSQL (`auth-postgres-dev`)**:
  - Instância `db.t3.micro` com 20GB de armazenamento.
  - Banco de dados inicial: `authdb`.
  - Configurado como **publicamente acessível** (para facilitar testes) e protegido por um Security Group que libera a porta `5432` para qualquer IP (`0.0.0.0/0`).
- **ElastiCache Redis (`auth-redis-cache`)**:
  - Cluster com 1 nó do tipo `cache.t3.micro` rodando Redis 7.0.
  - Security Group permite acesso na porta `6379` originado apenas de dentro da VPC (`10.0.0.0/16`).

### 3. Computação (EC2) - `ec2.tf`
- **Instância EC2 (`auth-api-server`)**: 
  - Máquina `t3.small` (adequada para rodar múltiplos contêineres Docker) utilizando Ubuntu 22.04 LTS e disco de 20GB SSD (`gp3`).
  - **Automação de Inicialização (User Data)**: A instância é iniciada com um script que:
    1. Instala o Docker e Docker Compose.
    2. Clona o repositório da API de Autenticação (`alexbastos/authentication_api`).
    3. Cria o arquivo `.env` injetando dinamicamente as credenciais e o host do banco de dados RDS recém-criado, além do host do Redis.
    4. Sobe os contêineres da aplicação através do `docker compose`.
  - **Chave SSH (`auth-api-key`)**: Utiliza a chave pública localizada em `~/.ssh/id_rsa.pub` para acesso.
  - **Security Group (`ec2-app-sg`)**: Libera tráfego de entrada para SSH (22), HTTP (80), HTTPS (443) e porta da API (3000) para qualquer IP.

### 4. API Gateway - `api_gateway.tf` e `main1.tf`
- **HTTP API Gateway (`api-gateway-dev`)**: Atua como o ponto de entrada principal para as requisições, com rotas configuradas para serviços de autenticação e microsserviços.
- **CORS Configurado**: Permite origens, métodos (`GET`, `POST`, `PUT`, `DELETE`) e cabeçalhos padrão.
- **Integrações e Rotas**:
  - Configuração de proxy reverso HTTP para direcionar requisições públicas (ex: `/authentication_api/api/v1/auth`) para o serviço de autenticação hospedado na EC2.
  - Configuração de rotas protegidas (ex: `/authentication_api/api/v1/users`) que exigem validação de token através de um Authorizer.
- **JWT Authorizer (Opcional/Configurável)**: Valida tokens JWT via endpoints JWKS para proteger as rotas internas, garantindo que só requisições autenticadas cheguem aos microsserviços protegidos.

### 5. Hospedagem de Frontend (S3 + CloudFront) - `frontend_s3_cloudfront.tf`
- **Amazon S3 (`captagov-s3`)**: Bucket privado designado para armazenar os arquivos estáticos compilados do frontend (React/Vue/Angular). O acesso público direto ao bucket é totalmente bloqueado.
- **Amazon CloudFront**: CDN global distribuindo o conteúdo do S3 de forma rápida e segura com protocolo HTTPS.
- **Origin Access Control (OAC)**: Garante que apenas o CloudFront possua permissão de leitura dos objetos do bucket S3.
- **Suporte a SPA (Single Page Application)**: Configurações de redirecionamento de erros 404 e 403 para a raiz (`index.html`), requisito essencial para o funcionamento do roteamento interno de frameworks de frontend no navegador.

---

## Como Executar

### Pré-requisitos
- Conta configurada na AWS e AWS CLI instalada e autenticada.
- Chave SSH gerada no seu computador (por padrão, espera que o arquivo exista em `~/.ssh/id_rsa.pub`).

### Comandos Básicos

```bash
# Valide sua identidade AWS atual
aws sts get-caller-identity

# Inicializa o backend do Terraform e baixa os provedores
terraform init

# Formata o código para os padrões do Terraform
terraform fmt

# Valida se a sintaxe e as referências entre os recursos estão corretas
terraform validate

# Exibe o plano de execução e o que será criado
terraform plan

# Aplica as configurações e cria os recursos na AWS
terraform apply
```

### Para Destruir a Infraestrutura
Lembre-se de destruir os recursos após o uso (especialmente os bancos de dados e a instância EC2) para evitar cobranças na sua conta AWS:

```bash
terraform destroy
```
