#!/bin/bash
# Salve como benchmark-scripts/run_benchmarks.sh

set -e

# Configurações
PG13_HOST="postgres13"
PG18_HOST="postgres18"
PG_PORT="5432"
PG_USER="benchmark_user"
PG_DB="benchmark_db"
SCALE_FACTOR=50  # Fator de escala para pgbench (50 = ~750MB de dados)
THREADS=4
CLIENTS=20
DURATION=300  # 5 minutos por teste

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== PostgreSQL 13 vs 18 Beta3 Benchmark ===${NC}"
echo "Scale Factor: $SCALE_FACTOR"
echo "Threads: $THREADS"
echo "Clients: $CLIENTS"
echo "Duration: ${DURATION}s"
echo "----------------------------------------"

# Função para executar benchmark
run_benchmark() {
    local version=$1
    local host=$2
    local test_name=$3
    local extra_options=$4
    
    echo -e "\n${YELLOW}Running $test_name on PostgreSQL $version...${NC}"
    
    local result_file="/benchmark-results/pgbench_${version}_${test_name}_$(date +%Y%m%d_%H%M%S).log"
    
    pgbench -h $host -p $PG_PORT -U $PG_USER -d $PG_DB \
        -c $CLIENTS -j $THREADS -T $DURATION $extra_options \
        --progress=30 --log --log-prefix="pg${version}_${test_name}" \
        2>&1 | tee $result_file
    
    echo -e "${GREEN}Results saved to: $result_file${NC}"
}

# Função para inicializar dados
initialize_pgbench() {
    local version=$1
    local host=$2
    
    echo -e "\n${YELLOW}Initializing pgbench data for PostgreSQL $version...${NC}"
    
    pgbench -h $host -p $PG_PORT -U $PG_USER -d $PG_DB \
        -i -s $SCALE_FACTOR --foreign-keys --quiet
    
    echo -e "${GREEN}Initialization complete for PostgreSQL $version${NC}"
}

# Função para coletar estatísticas do sistema
collect_system_stats() {
    local version=$1
    local container_name=$2
    local output_file="/benchmark-results/system_stats_${version}_$(date +%Y%m%d_%H%M%S).log"
    
    echo -e "\n${YELLOW}Collecting system stats for $version...${NC}"
    
    {
        echo "=== System Stats for PostgreSQL $version ==="
        echo "Timestamp: $(date)"
        echo ""
        
        echo "=== Container Stats ==="
        docker stats $container_name --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
        echo ""
        
        echo "=== PostgreSQL Stats ==="
        psql -h $(echo $container_name | cut -d'_' -f1) -p $PG_PORT -U $PG_USER -d $PG_DB -c "
            SELECT 
                pg_database_size('benchmark_db') as db_size_bytes,
                pg_size_pretty(pg_database_size('benchmark_db')) as db_size_pretty;
        "
        
        echo ""
        echo "=== Active Connections ==="
        psql -h $(echo $container_name | cut -d'_' -f1) -p $PG_PORT -U $PG_USER -d $PG_DB -c "
            SELECT count(*) as active_connections FROM pg_stat_activity WHERE state = 'active';
        "
        
    } > $output_file
    
    echo -e "${GREEN}System stats saved to: $output_file${NC}"
}

# Aguardar containers estarem prontos
echo -e "${YELLOW}Waiting for containers to be ready...${NC}"
sleep 30

# Executar benchmarks
echo -e "\n${BLUE}=== Starting Benchmarks ===${NC}"

# PostgreSQL 13
echo -e "\n${GREEN}=== POSTGRESQL 13 BENCHMARKS ===${NC}"
initialize_pgbench "13" $PG13_HOST
collect_system_stats "13" "postgres13_benchmark"

# Teste padrão TPC-B
run_benchmark "13" $PG13_HOST "standard" ""

# Teste somente leitura
run_benchmark "13" $PG13_HOST "readonly" "-S"

# Teste com prepared statements
run_benchmark "13" $PG13_HOST "prepared" "-M prepared"

# PostgreSQL 18
echo -e "\n${GREEN}=== POSTGRESQL 18 BENCHMARKS ===${NC}"
initialize_pgbench "18" $PG18_HOST
collect_system_stats "18" "postgres18_benchmark"

# Teste padrão TPC-B
run_benchmark "18" $PG18_HOST "standard" ""

# Teste somente leitura
run_benchmark "18" $PG18_HOST "readonly" "-S"

# Teste com prepared statements
run_benchmark "18" $PG18_HOST "prepared" "-M prepared"

echo -e "\n${BLUE}=== Benchmark Complete ===${NC}"
echo -e "${GREEN}Check /benchmark-results directory for detailed results${NC}"

# Gerar relatório resumido
echo -e "\n${YELLOW}Generating summary report...${NC}"
/benchmark-scripts/generate_report.sh