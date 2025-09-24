#!/bin/bash

# Script para iniciar os servidores de monitoramento
# Autor: Sistema de Monitoramento
# Data: $(date)

echo "🚀 Iniciando Servidores de Monitoramento..."
echo "=========================================="

# Função para configurar módulo Go
setup_module() {
    local module_path=$1
    local module_name=$2
    
    if [ -d "$module_path" ]; then
        echo "🔧 Configurando módulo $module_name..."
        cd "$module_path"
        if [ ! -f "go.mod" ]; then
            echo "   ❌ go.mod não encontrado em $module_path"
            return 1
        fi
        echo "   ✅ Módulo $module_name configurado"
        cd - > /dev/null
        return 0
    else
        echo "   ❌ Diretório $module_path não encontrado"
        return 1
    fi
}

# Configurar módulos
echo "🔧 Verificando configuração dos módulos..."
setup_module "monitoracao-dados/grpc" "gRPC" || exit 1
setup_module "monitoracao-dados/rest" "REST" || exit 1
setup_module "monitoracao-dados/websocket" "WebSocket" || exit 1

# Verificar se o Go está instalado
if ! command -v go &> /dev/null; then
    echo "❌ Go não está instalado. Instale o Go 1.23.0 ou superior."
    exit 1
fi

# Verificar se os módulos Go estão configurados
if [ ! -f "monitoracao-dados/grpc/go.mod" ]; then
    echo "❌ Arquivo go.mod do gRPC não encontrado."
    exit 1
fi

if [ ! -f "monitoracao-dados/rest/go.mod" ]; then
    echo "❌ Arquivo go.mod do REST não encontrado."
    exit 1
fi

if [ ! -f "monitoracao-dados/websocket/go.mod" ]; then
    echo "❌ Arquivo go.mod do WebSocket não encontrado."
    exit 1
fi

# Função para verificar se uma porta está em uso
check_port() {
    local port=$1
    if lsof -i :$port > /dev/null 2>&1; then
        echo "⚠️  Porta $port já está em uso"
        return 1
    else
        echo "✅ Porta $port está livre"
        return 0
    fi
}

# Verificar portas
echo "🔍 Verificando portas..."
check_port 8080 || {
    echo "   Processo usando porta 8080:"
    lsof -i :8080
    read -p "Deseja matar o processo? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        lsof -ti :8080 | xargs kill -9
        echo "✅ Processo morto"
    else
        echo "❌ Não é possível iniciar o servidor REST"
        exit 1
    fi
}

check_port 50051 || {
    echo "   Processo usando porta 50051:"
    lsof -i :50051
    read -p "Deseja matar o processo? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        lsof -ti :50051 | xargs kill -9
        echo "✅ Processo morto"
    else
        echo "❌ Não é possível iniciar o servidor gRPC"
        exit 1
    fi
}

check_port 8081 || {
    echo "   Processo usando porta 8081:"
    lsof -i :8081
    read -p "Deseja matar o processo? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        lsof -ti :8081 | xargs kill -9
        echo "✅ Processo morto"
    else
        echo "❌ Não é possível iniciar o servidor WebSocket"
        exit 1
    fi
}

# Função para iniciar servidor REST
start_rest() {
    echo "📡 Iniciando servidor REST na porta 8080..."
    cd monitoracao-dados/rest
    # Verificar e baixar dependências se necessário
    if [ ! -d "vendor" ]; then
        echo "   📦 Baixando dependências..."
        go mod download
        go mod tidy
    fi
    go run rest-monitor.go
}

# Função para iniciar servidor gRPC
start_grpc() {
    echo "🔌 Iniciando servidor gRPC na porta 50051..."
    cd monitoracao-dados/grpc
    # Verificar e baixar dependências se necessário
    if [ ! -d "vendor" ]; then
        echo "   📦 Baixando dependências..."
        go mod download
        go mod tidy
    fi
    go run grpc-monitor.go monitor/
}

# Função para iniciar servidor WebSocket
start_websocket() {
    echo "🔌 Iniciando servidor WebSocket na porta 8081..."
    cd monitoracao-dados/websocket
    # Verificar e baixar dependências se necessário
    if [ ! -d "vendor" ]; then
        echo "   📦 Baixando dependências..."
        go mod download
        go mod tidy
    fi
    go run websocket-monitor.go
}

# Função para verificar se Docker está instalado
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker não está instalado. Instale o Docker primeiro."
        return 1
    fi
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo "❌ Docker Compose não está instalado. Instale o Docker Compose primeiro."
        return 1
    fi
    return 0
}

# Função para iniciar containers Docker
start_docker_containers() {
    echo "🐳 Iniciando containers Docker..."
    cd monitoracao-dados || {
        echo "❌ Diretório monitoracao-dados não encontrado"
        return 1
    }
    if docker compose ps | grep -q "Up"; then
        echo "⚠️  Containers já estão rodando"
        docker compose ps
        return 0
    fi
    docker compose up -d
    echo "⏳ Aguardando inicialização dos containers..."
    sleep 10
    echo "✅ Containers iniciados:"
    docker compose ps
    echo ""
    echo "📊 URLs disponíveis:"
    echo "   REST API: http://localhost:8080"
    echo "   gRPC: localhost:50051"
    echo "   WebSocket: ws://localhost:8081/ws"
    echo "   Grafana: http://localhost:3000 (admin/admin123)"
    echo "   InfluxDB: http://localhost:8086"
}

# Função para executar testes K6 automaticamente
run_k6_tests_auto() {
    echo "🧪 Executando testes K6..."
    # Verificar se estamos no diretório correto
    if [ -d "testes" ]; then
        cd testes
    elif [ -d "monitoracao-dados/testes" ]; then
        cd monitoracao-dados/testes
    else
        echo "❌ Diretório de testes não encontrado"
        echo "Verificando estrutura de diretórios:"
        ls -la
        return 1
    fi
    
    # Verificar se K6 está instalado
    if ! command -v k6 &> /dev/null; then
        echo "❌ K6 não está instalado. Instale o K6 primeiro."
        echo "   curl -L https://github.com/grafana/k6/releases/latest/download/k6-linux-amd64.tar.gz | tar xz"
        echo "   sudo mv k6 /usr/local/bin/"
        return 1
    fi
    
    # Verificar se os servidores estão rodando
    if ! curl -s http://localhost:8080/ > /dev/null; then
        echo "❌ Servidor REST não está respondendo"
        return 1
    fi
    
    echo "✅ Servidores verificados"
    echo "🧪 Executando teste REST Leve (2 minutos)..."
    k6 run --duration 2m teste-rest.js
    
    echo ""
    echo "📈 Visualize os resultados em: http://localhost:3000"
    echo "   Usuário: admin"
    echo "   Senha: admin123"
}

# Função para executar testes K6
run_k6_tests() {
    echo "🧪 Executando testes K6..."
    # Verificar se estamos no diretório correto
    if [ -d "testes" ]; then
        cd testes
    elif [ -d "monitoracao-dados/testes" ]; then
        cd monitoracao-dados/testes
    else
        echo "❌ Diretório de testes não encontrado"
        echo "Verificando estrutura de diretórios:"
        ls -la
        return 1
    fi
    
    # Verificar se K6 está instalado
    if ! command -v k6 &> /dev/null; then
        echo "❌ K6 não está instalado. Instale o K6 primeiro."
        echo "   curl -L https://github.com/grafana/k6/releases/latest/download/k6-linux-amd64.tar.gz | tar xz"
        echo "   sudo mv k6 /usr/local/bin/"
        return 1
    fi
    
    # Verificar se os servidores estão rodando
    if ! curl -s http://localhost:8080/ > /dev/null; then
        echo "❌ Servidor REST não está respondendo"
        return 1
    fi
    
    echo "✅ Servidores verificados"
    echo ""
    echo "🎯 Escolha um teste:"
    echo "1. Teste REST - Leve (2 minutos)"
    echo "2. Teste REST - Médio (5 minutos)"
    echo "3. Teste REST - Pesado (10 minutos)"
    echo "4. Teste gRPC - Leve (2 minutos)"
    echo "5. Teste gRPC - Médio (5 minutos)"
    echo "6. Teste gRPC - Pesado (10 minutos)"
    echo "7. Teste Comparativo (REST vs gRPC)"
    echo ""
    
    read -p "Escolha um teste (1-7): " test_choice
    
    case $test_choice in
        1)
            echo "🧪 Executando teste REST Leve..."
            k6 run --duration 2m teste-rest.js
            ;;
        2)
            echo "🧪 Executando teste REST Médio..."
            k6 run --duration 5m teste-rest.js
            ;;
        3)
            echo "🧪 Executando teste REST Pesado..."
            k6 run --duration 10m teste-rest.js
            ;;
        4)
            echo "🧪 Executando teste gRPC Leve..."
            k6 run --duration 2m teste-grpc.js
            ;;
        5)
            echo "🧪 Executando teste gRPC Médio..."
            k6 run --duration 5m teste-grpc.js
            ;;
        6)
            echo "🧪 Executando teste gRPC Pesado..."
            k6 run --duration 10m teste-grpc.js
            ;;
        7)
            echo "🧪 Executando teste comparativo..."
            echo "📊 Teste REST..."
            k6 run --duration 2m teste-rest.js &
            REST_PID=$!
            sleep 5
            echo "📊 Teste gRPC..."
            k6 run --duration 2m teste-grpc.js &
            GRPC_PID=$!
            wait $REST_PID $GRPC_PID
            ;;
        *)
            echo "❌ Opção inválida"
            return 1
            ;;
    esac
    
    echo ""
    echo "📈 Visualize os resultados em: http://localhost:3000"
    echo "   Usuário: admin"
    echo "   Senha: admin123"
}

# Função para parar containers Docker
stop_docker_containers() {
    echo "🛑 Parando containers Docker..."
    cd monitoracao-dados || {
        echo "❌ Diretório monitoracao-dados não encontrado"
        return 1
    }
    docker compose down
    echo "✅ Containers parados"
}

# Função para limpar processos ao sair
cleanup() {
    echo ""
    echo "🛑 Parando servidores..."
    if [ ! -z "$REST_PID" ]; then
        kill $REST_PID 2>/dev/null
        echo "   Servidor REST parado (PID: $REST_PID)"
    fi
    if [ ! -z "$GRPC_PID" ]; then
        kill $GRPC_PID 2>/dev/null
        echo "   Servidor gRPC parado (PID: $GRPC_PID)"
    fi
    if [ ! -z "$WEBSOCKET_PID" ]; then
        kill $WEBSOCKET_PID 2>/dev/null
        echo "   Servidor WebSocket parado (PID: $WEBSOCKET_PID)"
    fi
    echo "✅ Servidores parados"
    exit 0
}

# Configurar trap para limpeza ao sair
trap cleanup SIGINT SIGTERM

echo ""
echo "🎯 Escolha uma opção:"
echo "1. Iniciar servidor REST apenas"
echo "2. Iniciar servidor gRPC apenas"
echo "3. Iniciar servidor WebSocket apenas"
echo "4. Iniciar todos os servidores (REST + gRPC + WebSocket)"
echo "5. Iniciar containers Docker (REST + gRPC + WebSocket + InfluxDB + Grafana)"
echo "6. Iniciar containers Docker + Executar testes K6"
echo "7. Executar testes K6 apenas (requer servidores rodando)"
echo "8. Parar todos os containers Docker"
echo "9. Sair"
echo ""

read -p "Escolha uma opção (1-9): " choice

case $choice in
    1)
        echo "📡 Iniciando apenas servidor REST..."
        start_rest
        ;;
    2)
        echo "🔌 Iniciando apenas servidor gRPC..."
        start_grpc
        ;;
    3)
        echo "🔌 Iniciando apenas servidor WebSocket..."
        start_websocket
        ;;
    4)
        echo "🚀 Iniciando todos os servidores..."
        
        # Iniciar servidor REST em background
        start_rest &
        REST_PID=$!
        echo "   Servidor REST iniciado (PID: $REST_PID)"
        
        # Aguardar um pouco para o REST inicializar
        sleep 2
        
        # Iniciar servidor gRPC em background
        start_grpc &
        GRPC_PID=$!
        echo "   Servidor gRPC iniciado (PID: $GRPC_PID)"
        
        # Aguardar um pouco para o gRPC inicializar
        sleep 2
        
        # Iniciar servidor WebSocket em background
        start_websocket &
        WEBSOCKET_PID=$!
        echo "   Servidor WebSocket iniciado (PID: $WEBSOCKET_PID)"
        
        echo ""
        echo "✅ Todos os servidores estão rodando!"
        echo "   REST: http://localhost:8080 (módulo: rest-monitor)"
        echo "   gRPC: localhost:50051 (módulo: grpc-monitor)"
        echo "   WebSocket: ws://localhost:8081/ws (módulo: websocket-monitor)"
        echo ""
        echo "🧪 Para testar:"
        echo "   curl http://localhost:8080/metrics"
        echo "   grpcurl -plaintext localhost:50051 monitor.SystemMonitor/GetAllMetrics"
        echo "   wscat -c ws://localhost:8081/ws"
        echo ""
        echo "📁 Estrutura dos módulos:"
        echo "   monitoracao-dados/grpc/ - Servidor gRPC (módulo: grpc-monitor)"
        echo "   monitoracao-dados/rest/ - Servidor REST (módulo: rest-monitor)"
        echo "   monitoracao-dados/websocket/ - Servidor WebSocket (módulo: websocket-monitor)"
        echo ""
        echo "🛑 Pressione Ctrl+C para parar os servidores"
        
        # Aguardar indefinidamente
        wait
        ;;
    5)
        echo "🐳 Iniciando containers Docker..."
        check_docker || exit 1
        start_docker_containers
        ;;
    6)
        echo "🚀 Iniciando containers Docker + testes K6..."
        check_docker || exit 1
        start_docker_containers
        echo ""
        echo "🧪 Aguardando inicialização completa..."
        sleep 15
        echo "🧪 Executando teste REST Leve automaticamente..."
        run_k6_tests_auto
        ;;
    7)
        echo "🧪 Executando testes K6..."
        run_k6_tests
        ;;
    8)
        echo "🛑 Parando containers Docker..."
        stop_docker_containers
        ;;
    9)
        echo "👋 Saindo..."
        exit 0
        ;;
    *)
        echo "❌ Opção inválida"
        exit 1
        ;;
esac
