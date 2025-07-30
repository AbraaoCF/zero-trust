# Zero Trust Architecture for Microservices: Policy Engine and Log Analysis Approaches

This repository presents two complementary access control approaches for implementing Zero Trust principles in microservices architectures. The work addresses cybersecurity challenges introduced by dynamic network perimeters, expanded attack surfaces, and complex communications that invalidate traditional static perimeter-based security models.

# Estrutura do readme.md

Este repositório está organizado da seguinte forma:

```
├── policy-engine/          # Implementação baseada em Open Policy Agent (OPA)
│   ├── opa-policies/       # Políticas de controle de acesso
│   ├── envoy-service/      # Configuração do Envoy Proxy
│   └── assets/            # Diagramas de arquitetura
├── logs-engine/           # Implementação baseada em análise de logs OpenSearch
│   ├── opensearch/        # Configuração do OpenSearch
│   ├── envoy-service/     # Configuração do Envoy Proxy
│   └── assets/           # Diagramas de arquitetura
├── commons/              # Componentes compartilhados
│   ├── certs/           # Certificados CA para TLS
│   ├── service/         # Serviço upstream simulado
│   └── state-storage/   # Armazenamento de estado (Redis + Webdis)
└── tests/               # Valores de teste e ativos para avaliação
```

# Selos Considerados

Os selos considerados são: **Disponíveis** e **Funcionais**. Ambas as implementações (Policy Engine e Log Analysis) são completamente funcionais e podem ser executadas independentemente para demonstrar os princípios de Zero Trust em diferentes cenários.

# Informações básicas

## Requisitos de Hardware
- **CPU**: Mínimo 4 cores (recomendado 8 cores para testes de performance)
- **RAM**: Mínimo 8GB (recomendado 16GB)
- **Armazenamento**: Mínimo 10GB de espaço livre
- **Rede**: Conexão com internet para download de imagens Docker

## Requisitos de Software
- **Sistema Operacional**: Linux (Ubuntu 20.04+), macOS (10.15+), ou Windows 10+ com WSL2
- **Docker**: Versão 20.10+ 
- **Docker Compose**: Versão 2.0+
- **Certificados TLS**: Necessários para comunicação segura entre componentes

## Componentes do Sistema

### Policy Engine (OPA-based)
- **OPA (Open Policy Agent)**: Engine de políticas para decisões de autorização
- **OPAL**: Camada de administração para atualizações em tempo real
- **Envoy Proxy**: Proxy de comunicação com extensão external authorization
- **Usage Tracker**: Serviço de rastreamento de uso para rate limiting

### Log Analysis Engine (OpenSearch-based)
- **OpenSearch**: Plataforma de análise de logs e alertas
- **Fluent Bit**: Coleta e processamento de logs
- **Envoy Proxy**: Proxy com scripts Lua para controle de acesso
- **Redis + Webdis**: Armazenamento de estado para penalidades

# Dependências

## Imagens Docker Utilizadas
- **openpolicyagent/opa:0.57.0-envoy** - OPA com suporte Envoy
- **permitio/opal-server:latest** - Servidor OPAL para gerenciamento de políticas
- **permitio/opal-client:latest** - Cliente OPAL para sincronização
- **opensearchproject/opensearch:2.11.0** - OpenSearch para análise de logs
- **opensearchproject/opensearch-dashboards:2.11.0** - Dashboard OpenSearch
- **fluent/fluent-bit:2.1.10** - Processamento de logs
- **redis:7-alpine** - Armazenamento de estado
- **envoyproxy/envoy:v1.27.0** - Proxy de comunicação

## Benchmarks e Ferramentas de Teste
As ferramentas de benchmark estão localizadas no diretório `tests/` e incluem:
- Scripts de geração de carga para teste de rate limiting
- Certificados SPIFFE para autenticação
- Configurações de teste para diferentes cenários de uso

# Preocupações com segurança

## Certificados TLS
**IMPORTANTE**: O sistema utiliza certificados TLS para comunicação segura entre todos os componentes. Os certificados de teste estão incluídos no repositório apenas para demonstração. **NÃO utilize estes certificados em produção**.

## Isolamento de Containers
Todos os componentes executam em containers Docker isolados com:
- Redes definidas para comunicação restrita entre serviços
- Volumes mapeados apenas para diretórios necessários
- Usuários não-root quando possível

## Dados Sensíveis
- Logs podem conter informações sensíveis - configure adequadamente em produção
- Políticas de acesso podem revelar estrutura do sistema
- Configure adequadamente os dashboards OpenSearch para acesso restrito

# Instalação

## 1. Preparação dos Certificados

```bash
cd commons/certs
# Execute o script de geração de certificados
./generate-certs.sh
```

## 2. Instalação - Policy Engine

```bash
cd policy-engine
# Inicie todos os serviços
docker-compose up --build -d
```

Serviços disponíveis:
- OPA Service: `localhost:8181` (API) e `localhost:9002` (gRPC)
- OPAL Server: `localhost:7002`
- Usage Tracker: interno

## 3. Instalação - Log Analysis Engine

```bash
cd logs-engine

# Inicie OpenSearch
cd opensearch
docker compose up -d

# Inicie o serviço upstream
cd ../commons/service
docker compose up -d

# Inicie Envoy
cd ../envoy-service
docker compose up -d

# Inicie armazenamento de estado
cd ../commons/state-storage
docker compose up -d
```

Serviços disponíveis:
- OpenSearch: `localhost:9200`
- OpenSearch Dashboard: `localhost:5601`
- Envoy Proxy: `localhost:8000`

# Teste mínimo

## Policy Engine - Teste Básico

```bash
# Teste de autorização básica
curl -X POST localhost:8181/v1/data/allow \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "subject": "spiffe://example.org/user1",
      "path": "/api/items",
      "method": "GET"
    }
  }'
```

Resultado esperado: `{"result": true}` indicando acesso autorizado.

## Log Analysis Engine - Teste Básico

```bash
# Teste de acesso através do Envoy
curl --cacert commons/certs/ca.crt \
     --cert commons/certs/normal.crt \
     --key commons/certs/normal.key \
     "https://localhost:8000/items"
```

Resultado esperado: 
- Resposta 200 OK do serviço upstream
- Log gerado no OpenSearch
- Dashboard mostrando métricas de acesso

## Verificação dos Serviços

```bash
# Verifique se todos os containers estão executando
docker ps

# Verifique logs em caso de problemas
docker-compose logs [service-name]
```

# Experimentos

## Experimento 1: Rate Limiting com Quotas por Usuário (Policy Engine)

**Objetivo**: Demonstrar o controle de acesso baseado em quotas de CPU por usuário e custo de endpoints.

**Configuração**: 
- Usuário com quota de 100 CPU coins
- Endpoint `/expensive` com custo de 50 coins
- Endpoint `/cheap` com custo de 10 coins
- Janela de tempo: 60 segundos

**Execução**:
```bash
cd policy-engine/tests
./test-rate-limiting.sh
```

**Tempo esperado**: 5 minutos
**Recursos necessários**: 2GB RAM, 1GB Disk
**Resultado esperado**: 
- Primeiras 2 chamadas para `/expensive` são aceitas
- Terceira chamada é negada (quota excedida)
- Chamadas para `/cheap` continuam funcionando até quota se esgotar

## Experimento 2: Análise de Logs e Sistema de Penalidades (Log Analysis Engine)

**Objetivo**: Demonstrar detecção de comportamento anômalo através de análise de logs e aplicação de penalidades.

**Configuração**:
- Monitor de alta duração de requisições (>100ms)
- Monitor de muitas requisições por segundo (>10/s)
- Penalidade: bloqueio por 60 segundos

**Execução**:
```bash
cd logs-engine/tests
./test-anomaly-detection.sh
```

**Tempo esperado**: 10 minutos
**Recursos necessários**: 4GB RAM, 2GB Disk
**Resultado esperado**:
- Detecção de comportamento anômalo nos logs
- Geração de alerta no OpenSearch
- Aplicação automática de penalidade via Envoy
- Bloqueio temporário do usuário

## Experimento 3: Modo Noturno e Quotas Dinâmicas (Policy Engine)

**Objetivo**: Demonstrar ajuste dinâmico de quotas baseado em horário de funcionamento.

**Configuração**:
- Horário comercial: 09:00-18:00 (quota padrão)
- Modo noturno: 18:00-09:00 (quota reduzida/aumentada conforme configuração)

**Execução**:
```bash
cd policy-engine/tests
./test-night-mode.sh
```

**Tempo esperado**: 15 minutos
**Recursos necessários**: 2GB RAM, 1GB Disk
**Resultado esperado**:
- Quotas ajustadas automaticamente conforme horário
- Comportamento diferente durante período noturno
- Logs mostrando decisões baseadas em contexto temporal

## Experimento 4: Integração com Detecção Externa de Anomalias

**Objetivo**: Demonstrar integração entre os dois sistemas para resposta coordenada a ameaças.

**Configuração**:
- Log Analysis Engine detecta anomalia
- Policy Engine recebe alerta externo
- Ajuste dinâmico de políticas baseado em alertas

**Execução**:
```bash
cd tests/integration
./test-cross-system-integration.sh
```

**Tempo esperado**: 20 minutos
**Recursos necessários**: 6GB RAM, 3GB Disk
**Resultado esperado**:
- Detecção coordenada entre sistemas
- Resposta automática a ameaças
- Demonstração de arquitetura Zero Trust resiliente

# LICENSE

Este repositório está licenciado sob a Licença MIT. Consulte o arquivo [LICENSE](LICENSE) para mais informações.
