# Meu Primeiro Laboratório de IaC: AWS 3-Tier com Terraform & LocalStack

Este repositório foi criado com o objetivo de registrar meus estudos iniciais na cultura DevOps, focando em **Infraestrutura como Código (IaC)** e **Arquitetura de Nuvem Segura**. 

O projeto consiste no design e provisionamento automatizado de uma infraestrutura em 3 camadas (Rede, Computação e Banco de Dados), utilizando o **Terraform** e emulando o ambiente da AWS localmente com o **LocalStack** em ambiente Linux (Ubuntu).

## 🎯 Objetivos de Estudo

A proposta deste laboratório foi exercitar conceitos praticos como:

1.  **Isolamento de Rede (VPC e Subnets):** Entender a diferença prática entre expor um recurso na internet (Subnet Pública) e trancar recursos críticos (Subnet Privada).
2.  **Roteamento e Fluxo de Dados:** Configurar como as máquinas conversam entre si e com o mundo externo usando Internet Gateway e NAT Gateway.
3.  **Segurança Baseada no Menor Privilégio:** Criar firewalls virtuais (Security Groups) que bloqueiam todo o tráfego por padrão e liberam acessos apenas para origens específicas através de "crachás" de segurança.
4.  **Gerenciamento de Estado Remoto (State & Locking):** Compreender a importância do arquivo `.tfstate`, configurando um backend seguro com S3 e travas de concorrência nativas para evitar corrupção de código.

## 🧠 Desafios Práticos & Debugging

Mais do que apenas escrever o código, o grande valor deste estudo foi aprender a ler logs e solucionar problemas reais de ambiente.

## 📁 Estrutura Modular do Projeto

Para seguir as boas práticas de mercado, a infraestrutura foi dividida em blocos independentes e reutilizáveis (módulos):

```text
├── backend-setup/            # Configuração isolada que cria o balde S3 para o estado do Terraform
│   ├── main.tf
│   └── provider.tf
├── modules/                  # Módulos encapsulados e paralelos
│   ├── networking/           # Criação da VPC, Subnets Públicas/Privadas e Gateways
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── compute/              # Servidor de Aplicação (EC2 público) e regras de firewall web
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── database/             # Servidor de Banco de Dados (EC2 trancado na rede privada)
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── backend.tf                # Ativação do travamento de estado (S3 + use_lockfile)
├── main.tf                   # Arquivo mestre que orquestra e passa variáveis entre os módulos
├── provider.tf               # Direcionamento das chamadas da API AWS para o LocalStack local
└── .gitignore                # Proteção essencial para não subir arquivos de estado (.tfstate) ao Git
