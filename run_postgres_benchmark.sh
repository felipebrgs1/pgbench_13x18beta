#!/bin/bash
# Salve como run_postgres_benchmark.sh
# Script principal para executar o benchmark completo

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    PostgreSQL 13 vs 18 Beta3 Benchmark                      ║"
echo "║                                                                              ║"
echo "║  Este script irá comparar a performance entre PostgreSQL 13 e 18 Beta3      ║"
echo "║  usando pgbench, monitoramento com Prometheus e análise detalhada           ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Comando de compose (pode ser 'docker compose' ou 'docker compose')
COMPOSE_CMD="docker compose"

# Verificar dependências
check_dependencies() {
    echo -e "${YELLOW}Verificando dependências...${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker não encontrado. Instale o Docker primeiro.${NC}"
        exit 1
    fi
    # Detectar forma disponível do Compose: prefer 'docker compose', cair para 'docker compose'
    if command -v docker compose &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        # testar se 'docker compose' está disponível
        if docker compose version &> /dev/null; then
            COMPOSE_CMD="docker compose"
        else
            echo -e "${RED}Docker Compose não encontrado (procure por 'docker compose' ou 'docker compose'). Instale o Compose primeiro.${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}Dependências verificadas com sucesso!${NC}"
}

# Criar estrutura de diretórios
setup_directories() {
    echo -e "${YELLOW}Criando estrutura de diretórios...${NC}"
    
    mkdir -p benchmark-results
    mkdir -p benchmark-scripts
    mkdir -p init-scripts
    
    # Tornar scripts executáveis
    chmod +x benchmark-scripts/*.sh 2>/dev/null || true
    
    echo -e "${GREEN}Diretórios criados com sucesso!${NC}"
}



# Iniciar serviços
start_services() {
    echo -e "${YELLOW}Iniciando serviços Docker...${NC}"
    
    $COMPOSE_CMD up -d
    
    echo -e "${YELLOW}Aguardando serviços ficarem prontos...${NC}"
    sleep 60
    
    # Verificar se os serviços estão saudáveis
    for service in postgres13 postgres18; do
        echo -e "${YELLOW}Verificando saúde do $service...${NC}"
        for i in {1..30}; do
            if $COMPOSE_CMD exec -T $service pg_isready -U benchmark_user -d benchmark_db; then
                echo -e "${GREEN}$service está pronto!${NC}"
                break
            else
                echo "Tentativa $i/30 - Aguardando $service..."
                sleep 10
            fi
        done
    done
}

# Coletar estatísticas dos containers
collect_container_stats() {
    echo -e "${YELLOW}Coletando estatísticas dos containers...${NC}"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local stats_file="benchmark-results/container_stats_${timestamp}.log"
    
    {
        echo "=== Container Statistics ==="
        echo "Timestamp: $(date)"
        echo ""
        
        echo "=== Docker Stats ==="
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" postgres13_benchmark postgres18_benchmark pgbench-runner_benchmark || true
        echo ""
        
        echo "=== Container Resource Usage ==="
        for container in postgres13_benchmark postgres18_benchmark; do
            echo "--- $container ---"
            docker exec $container ps aux 2>/dev/null || true
            echo ""
        done
        
    } > "$stats_file"
    
    echo -e "${GREEN}Estatísticas dos containers salvas em: $stats_file${NC}"
}

# Executar benchmarks
run_benchmarks() {
    echo -e "${BLUE}Executando benchmarks...${NC}"
    
    # Coletar estatísticas iniciais dos containers
    collect_container_stats
    
    $COMPOSE_CMD exec -T pgbench-runner /benchmark-scripts/run_benchmarks.sh
    
    # Coletar estatísticas finais dos containers
    collect_container_stats
}

# Coletar métricas adicionais
collect_additional_metrics() {
    echo -e "${YELLOW}Coletando métricas adicionais...${NC}"
    
    # Estatísticas de tabelas
    for version in 13 18; do
        host=$([[ $version == "13" ]] && echo "postgres13" || echo "postgres18")
        
        echo -e "Coletando estatísticas detalhadas do PostgreSQL $version..."
        
    $COMPOSE_CMD exec -T pgbench-runner psql -h $host -p 5432 -U benchmark_user -d benchmark_db -c "
            SELECT 
                schemaname,
                tablename,
                attname,
                inherited,
                null_frac,
                avg_width,
                n_distinct,
                most_common_vals,
                most_common_freqs,
                histogram_bounds
            FROM pg_stats 
            WHERE tablename IN ('pgbench_accounts', 'pgbench_branches', 'pgbench_tellers', 'pgbench_history')
            ORDER BY tablename, attname;
        " > benchmark-results/table_stats_pg${version}_$(date +%Y%m%d_%H%M%S).log 2>&1
        
    $COMPOSE_CMD exec -T pgbench-runner psql -h $host -p 5432 -U benchmark_user -d benchmark_db -c "
            SELECT 
                query,
                calls,
                total_time,
                mean_time,
                rows,
                100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
            FROM pg_stat_statements 
            ORDER BY total_time DESC 
            LIMIT 20;
        " > benchmark-results/query_stats_pg${version}_$(date +%Y%m%d_%H%M%S).log 2>&1 || true
    done
    
    echo -e "${GREEN}Métricas adicionais coletadas!${NC}"
}

# Gerar relatório final
generate_final_report() {
    echo -e "${YELLOW}Gerando relatório final...${NC}"
    
    $COMPOSE_CMD exec -T pgbench-runner /benchmark-scripts/generate_report.sh
    
    echo -e "${GREEN}Relatório final gerado em benchmark-results/${NC}"
}

# Mostrar URLs de monitoramento
show_monitoring_urls() {
    echo -e "${BLUE}URLs de Monitoramento:${NC}"
    echo -e "${GREEN}Prometheus: http://localhost:9090${NC}"
    echo -e "${GREEN}PostgreSQL 13 Metrics: http://localhost:9187/metrics${NC}"
    echo -e "${GREEN}PostgreSQL 18 Metrics: http://localhost:9188/metrics${NC}"
    echo ""
    echo -e "${YELLOW}Para acessar Prometheus e visualizar métricas em tempo real:${NC}"
    echo "1. Abra http://localhost:9090"
    echo "2. Vá para Status > Targets para verificar se os exporters estão funcionando"
    echo "3. Use queries como: rate(pg_stat_database_xact_commit_total[5m])"
}

# Função principal
main() {
    echo -e "${BLUE}Iniciando benchmark PostgreSQL 13 vs 18 Beta3...${NC}"
    
    check_dependencies
    setup_directories
    start_services
    show_monitoring_urls
    
    echo -e "${YELLOW}Pressione Enter para iniciar os benchmarks ou Ctrl+C para cancelar...${NC}"
    read -r
    
    run_benchmarks
    collect_additional_metrics
    generate_final_report
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           BENCHMARK CONCLUÍDO                               ║"
    echo "║                                                                              ║"
    echo "║  Resultados salvos em: benchmark-results/                                   ║"
    echo "║  Relatório principal: benchmark-results/benchmark_summary_*.md              ║"
    echo "║                                                                              ║"
    echo "║  Para parar os serviços: $COMPOSE_CMD down                                ║"
    echo "║  Para limpar tudo: $COMPOSE_CMD down -v                                   ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Tratamento de sinais
trap 'echo -e "\n${RED}Benchmark interrompido pelo usuário${NC}"; exit 1' SIGINT SIGTERM

# Verificar se é execução direta
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi