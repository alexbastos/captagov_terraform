# Subnet Group para Bancos de Dados
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "redis-subnet-group"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

# Security Group para PostgreSQL (Atualizado para aceitar conexões externas)
resource "aws_security_group" "db_sg" {
  name        = "rds-postgres-sg"
  description = "Acesso ao Postgres"
  vpc_id      = aws_vpc.main.id

  # Regra de entrada: Libera a porta 5432 para qualquer máquina na internet (Testes)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 👈 ALTERADO (Substituiu 10.0.0.0/16)
  }

  # Regra de saída: Permite retorno de tráfego do banco
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group para Redis
resource "aws_security_group" "redis_sg" {
  name        = "redis-sg"
  description = "Acesso ao Redis"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

# 1. Amazon RDS PostgreSQL (Configurado com Acesso Público para testes)
resource "aws_db_instance" "postgres" {
  identifier             = "auth-postgres-dev"
  allocated_storage      = 20
  max_allocated_storage  = 20
  db_name                = "authdb"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  username               = "adminuser"
  password               = "SenhaSuperSegura123!"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = true # 👈 ADICIONADO (Torna o IP do banco acessível fora da AWS)
  skip_final_snapshot    = true
}

# 2. Amazon ElastiCache Redis (Configurado no Free Tier)
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "auth-redis-cache"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis_sg.id]
}