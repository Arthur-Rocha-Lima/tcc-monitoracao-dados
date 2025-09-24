# 🖥️ Sistema de Monitoramento de Servidor

Este projeto implementa um sistema de monitoramento de servidor com três interfaces: **REST API**, **gRPC API** e **WebSocket API**. Todas fornecem métricas em tempo real sobre CPU, memória, disco e rede.

## 🚀 Início Rápido

### 1. Iniciar os Servidores
```bash
cd docker-config
docker compose up -d --build
```

### 2. Executar Testes
```bash
cd testes

# Teste REST
k6 run taxa-fixa/teste-rest-taxa-fixa.js

# Teste gRPC
ghz --insecure --proto ../monitoracao-dados/api/grpc/proto/metrics.proto --call metrics.MetricService/GetMetrics -c 10 -r 5 -z 1m localhost:50051
```

### 3. Monitorar Recursos
```bash
python3 monitor-docker.py rest-monitor --duration 5
```

**Serviços disponíveis:**
- REST API: http://localhost:8080/metrics
- gRPC API: localhost:50051  
- WebSocket API: ws://localhost:8081/ws

## 🚀 Pré-requisitos

Para executar este projeto, você precisa ter instalado:

### Docker
- **Versão**: 20.10 ou superior
- **Instalação**: [docs.docker.com/get-docker](https://docs.docker.com/get-docker/)

**Verificar instalação:**
```bash
docker --version
docker compose version
```

### Python 3
- **Versão**: 3.8 ou superior
- **Instalação**: [python.org/downloads](https://www.python.org/downloads/)

**Verificar instalação:**
```bash
python3 --version
pip3 --version
```

### K6 (para testes de carga)
- **Instalação**: [k6.io](https://k6.io/)

**Verificar instalação:**
```bash
k6 version
```

### ghz (para testes gRPC)
- **Instalação**: [ghz.sh](https://ghz.sh/)

**Verificar instalação:**
```bash
ghz --version
```

## 🧪 Executando os Testes

### Navegação para a Pasta de Testes

```bash
cd testes
```

### Testes REST e WebSocket (K6)

Para executar os testes REST e WebSocket, use o comando:

```bash
k6 run nome-arquivo
```

#### Exemplos de Testes Disponíveis:

**Testes de Taxa Fixa:**
```bash
k6 run taxa-fixa/teste-rest-taxa-fixa.js
k6 run taxa-fixa/teste-websocket-taxa-fixa.js
```

**Testes de Pico:**
```bash
k6 run pico/teste-rest-pico.js
k6 run pico/teste-websocket-pico.js
```

**Testes de Carga Máxima:**
```bash
k6 run carga-maxima/teste-rest-carga-maxima.js
k6 run carga-maxima/teste-websocket-carga-maxima.js
```

### Testes gRPC (ghz)

Para executar os testes gRPC, use o comando:

```bash
ghz --insecure --proto ../monitoracao-dados/api/grpc/proto/metrics.proto --call metrics.MetricService/GetMetrics -c numero-vus -r numero-requisicoes-segundo -z 5m localhost:50051
```

#### Parâmetros do comando ghz:

- `--insecure`: Conecta sem TLS/SSL
- `--proto`: Caminho para o arquivo .proto
- `--call`: Método gRPC a ser chamado
- `-c`: Número de usuários virtuais (VUs)
- `-r`: Número de requisições por segundo
- `-z`: Duração do teste (ex: 5m = 5 minutos)

#### Exemplos de Testes gRPC:

**Teste Leve (10 VUs, 5 req/s, 1 minuto):**
```bash
ghz --insecure --proto ../monitoracao-dados/api/grpc/proto/metrics.proto --call metrics.MetricService/GetMetrics -c 10 -r 5 -z 1m localhost:50051
```

**Teste Médio (50 VUs, 20 req/s, 3 minutos):**
```bash
ghz --insecure --proto ../monitoracao-dados/api/grpc/proto/metrics.proto --call metrics.MetricService/GetMetrics -c 50 -r 20 -z 3m localhost:50051
```

**Teste Pesado (100 VUs, 50 req/s, 5 minutos):**
```bash
ghz --insecure --proto ../monitoracao-dados/api/grpc/proto/metrics.proto --call metrics.MetricService/GetMetrics -c 100 -r 50 -z 5m localhost:50051
```

## ⚙️ Personalizando os Testes

### Modificando Testes K6 (REST/WebSocket)

Para personalizar os testes K6, você pode editar os arquivos JavaScript na pasta `testes/` ou usar parâmetros de linha de comando.

#### Opção 1: Parâmetros de Linha de Comando

```bash
# Alterar número de VUs (usuários virtuais)
k6 run --vus 50 taxa-fixa/teste-rest-taxa-fixa.js

# Alterar duração do teste
k6 run --duration 5m taxa-fixa/teste-rest-taxa-fixa.js

# Combinar parâmetros
k6 run --vus 100 --duration 3m taxa-fixa/teste-rest-taxa-fixa.js
```

#### Opção 2: Editar Arquivo de Teste

Para modificar permanentemente um teste, edite o arquivo JavaScript:

```javascript
export let options = {
  scenarios: {
    rest_1rps_per_vu: {
      executor: 'constant-vus',
      vus: 50,        // ← Altere aqui o número de VUs
      duration: '3m', // ← Altere aqui a duração
    },
  }
};
```

#### Exemplos de Personalização:

**Teste com 25 VUs por 2 minutos:**
```bash
k6 run --vus 25 --duration 2m taxa-fixa/teste-rest-taxa-fixa.js
```

**Teste com 100 VUs por 5 minutos:**
```bash
k6 run --vus 100 --duration 5m taxa-fixa/teste-websocket-taxa-fixa.js
```
