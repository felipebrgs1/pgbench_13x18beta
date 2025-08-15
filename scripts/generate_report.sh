#!/bin/bash
# Salve como benchmark-scripts/generate_report.sh

set -e

REPORT_FILE="/benchmark-results/benchmark_summary_$(date +%Y%m%d_%H%M%S).md"

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Generating benchmark summary report...${NC}"

# Função para extrair TPS dos logs do pgbench
extract_tps() {
    local file=$1
    grep "tps = " $file | tail -1 | awk '{print $3}' | sed 's/tps//g'
}

# Função para extrair latência média
extract_latency() {
    local file=$1
    grep "latency average" $file | awk '{print $4}' | sed 's/ms//g'
}

# Criar relatório em Markdown
cat > $REPORT_FILE << 'EOF'
# PostgreSQL 13 vs 18 Beta3 - Benchmark Results

## Test Configuration
- **Scale Factor**: 50 (~750MB data)
- **Clients**: 20
- **Threads**: 4
- **Duration**: 5 minutes per test
- **Hardware**: Docker containers with 2 CPU cores, 2GB RAM limit

## Results Summary

### Transaction Throughput (TPS - Transactions Per Second)

| Test Type | PostgreSQL 13 | PostgreSQL 18 | Improvement |
|-----------|---------------|---------------|-------------|
EOF

# Processar resultados para cada tipo de teste
for test_type in "standard" "readonly" "prepared"; do
    echo "Processing $test_type test results..."
    
    # Encontrar arquivos de resultado mais recentes
    pg13_file=$(ls -t /benchmark-results/pgbench_13_${test_type}_*.log 2>/dev/null | head -1)
    pg18_file=$(ls -t /benchmark-results/pgbench_18_${test_type}_*.log 2>/dev/null | head -1)
    
    if [[ -f "$pg13_file" && -f "$pg18_file" ]]; then
        pg13_tps=$(extract_tps "$pg13_file")
        pg18_tps=$(extract_tps "$pg18_file")
        
        if [[ -n "$pg13_tps" && -n "$pg18_tps" ]]; then
            improvement=$(echo "scale=2; ($pg18_tps - $pg13_tps) / $pg13_tps * 100" | bc)
            
            echo "| $test_type | ${pg13_tps} | ${pg18_tps} | ${improvement}% |" >> $REPORT_FILE
        fi
    fi
done

cat >> $REPORT_FILE << 'EOF'

### Average Latency (milliseconds)

| Test Type | PostgreSQL 13 | PostgreSQL 18 | Improvement |
|-----------|---------------|---------------|-------------|
EOF

# Processar latência
for test_type in "standard" "readonly" "prepared"; do
    pg13_file=$(ls -t /benchmark-results/pgbench_13_${test_type}_*.log 2>/dev/null | head -1)
    pg18_file=$(ls -t /benchmark-results/pgbench_18_${test_type}_*.log 2>/dev/null | head -1)
    
    if [[ -f "$pg13_file" && -f "$pg18_file" ]]; then
        pg13_lat=$(extract_latency "$pg13_file")
        pg18_lat=$(extract_latency "$pg18_file")
        
        if [[ -n "$pg13_lat" && -n "$pg18_lat" ]]; then
            improvement=$(echo "scale=2; ($pg13_lat - $pg18_lat) / $pg13_lat * 100" | bc)
            
            echo "| $test_type | ${pg13_lat} | ${pg18_lat} | ${improvement}% |" >> $REPORT_FILE
        fi
    fi
done

cat >> $REPORT_FILE << 'EOF'

## Test Descriptions

### Standard Test
- **Type**: TPC-B like workload
- **Operations**: Mix of SELECT, INSERT, UPDATE transactions
- **Description**: Simulates typical OLTP workload with mixed read/write operations

### Read-Only Test  
- **Type**: SELECT only operations
- **Operations**: Only SELECT statements
- **Description**: Tests read performance and query optimization

### Prepared Statements Test
- **Type**: TPC-B with prepared statements
- **Operations**: Same as standard but using prepared statements
- **Description**: Tests the efficiency of prepared statement caching and execution

## System Resources

### PostgreSQL 13
EOF

# Adicionar stats do sistema se disponível
pg13_stats=$(ls -t /benchmark-results/system_stats_13_*.log 2>/dev/null | head -1)
if [[ -f "$pg13_stats" ]]; then
    echo '```' >> $REPORT_FILE
    cat "$pg13_stats" >> $REPORT_FILE
    echo '```' >> $REPORT_FILE
fi

cat >> $REPORT_FILE << 'EOF'

### PostgreSQL 18
EOF

pg18_stats=$(ls -t /benchmark-results/system_stats_18_*.log 2>/dev/null | head -1)
if [[ -f "$pg18_stats" ]]; then
    echo '```' >> $REPORT_FILE
    cat "$pg18_stats" >> $REPORT_FILE
    echo '```' >> $REPORT_FILE
fi

cat >> $REPORT_FILE << 'EOF'

## Analysis

### Key Findings

1. **Performance Improvements**: PostgreSQL 18 shows improvements in [specific areas]
2. **Resource Utilization**: Memory and CPU usage patterns
3. **Query Optimization**: Enhanced query planner performance
4. **Concurrency**: Better handling of concurrent connections

### Recommendations

- For **OLTP workloads**: [recommendation based on results]
- For **Read-heavy workloads**: [recommendation based on results]  
- For **Applications using prepared statements**: [recommendation based on results]

## Files Generated

EOF

# Listar todos os arquivos gerados
echo "### Result Files" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
ls -la /benchmark-results/ | grep -v "^d" >> $REPORT_FILE
echo '```' >> $REPORT_FILE

cat >> $REPORT_FILE << 'EOF'

## How to Reproduce

1. Clone this benchmark setup
2. Run: `docker compose up -d`
3. Execute: `docker exec pgbench_runner /benchmark-scripts/run_benchmarks.sh`
4. Check results in `/benchmark-results/` directory

---
*Report generated on: $(date)*
EOF

echo -e "${GREEN}Summary report generated: $REPORT_FILE${NC}"

# Mostrar um resumo rápido no terminal
echo -e "\n${BLUE}=== Quick Summary ===${NC}"
if command -v bc &> /dev/null; then
    echo "TPS Comparison:"
    for test_type in "standard" "readonly" "prepared"; do
        pg13_file=$(ls -t /benchmark-results/pgbench_13_${test_type}_*.log 2>/dev/null | head -1)
        pg18_file=$(ls -t /benchmark-results/pgbench_18_${test_type}_*.log 2>/dev/null | head -1)
        
        if [[ -f "$pg13_file" && -f "$pg18_file" ]]; then
            pg13_tps=$(extract_tps "$pg13_file")
            pg18_tps=$(extract_tps "$pg18_file")
            
            if [[ -n "$pg13_tps" && -n "$pg18_tps" ]]; then
                improvement=$(echo "scale=1; ($pg18_tps - $pg13_tps) / $pg13_tps * 100" | bc)
                echo "  $test_type: PG13=$pg13_tps TPS, PG18=$pg18_tps TPS (${improvement}%)"
            fi
        fi
    done
fi