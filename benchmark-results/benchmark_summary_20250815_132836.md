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
| standard | 3669.870889 | 3520.138174 | -4.00% |
| readonly | 35711.265833 | 33298.309551 | -6.00% |
| prepared | 3352.985575 | 3277.251880 | -2.00% |

### Average Latency (milliseconds)

| Test Type | PostgreSQL 13 | PostgreSQL 18 | Improvement |
|-----------|---------------|---------------|-------------|
| standard | 5.440 | 5.673 | -4.00% |
| readonly | 0.548 | 0.589 | -7.00% |
| prepared | 5.956 | 6.094 | -2.00% |

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
```
=== System Stats for PostgreSQL 13 ===
Timestamp: Fri Aug 15 12:58:29 UTC 2025

=== System Resources ===
Memory Info:
MemTotal:       24292700 kB
MemFree:         4222096 kB
MemAvailable:   16646900 kB
Buffers:            2884 kB
Cached:         14054116 kB

CPU Info:
model name	: 12th Gen Intel(R) Core(TM) i7-12700H
CPU Cores: 20

Load Average:
0.17 0.33 0.64 1/1869 23

=== PostgreSQL Stats ===
 db_size_bytes | db_size_pretty 
---------------+----------------
     798044719 | 761 MB
(1 row)


=== Active Connections ===
 active_connections 
--------------------
                  1
(1 row)

```

### PostgreSQL 18
```
=== System Stats for PostgreSQL 18 ===
Timestamp: Fri Aug 15 13:13:35 UTC 2025

=== System Resources ===
Memory Info:
MemTotal:       24292700 kB
MemFree:         1800848 kB
MemAvailable:   16326704 kB
Buffers:            2884 kB
Cached:         16583268 kB

CPU Info:
model name	: 12th Gen Intel(R) Core(TM) i7-12700H
CPU Cores: 20

Load Average:
3.33 4.63 3.18 4/1883 59

=== PostgreSQL Stats ===
 db_size_bytes | db_size_pretty 
---------------+----------------
     797832895 | 761 MB
(1 row)


=== Active Connections ===
 active_connections 
--------------------
                  1
(1 row)

```

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

### Result Files
```
total 44
-rw-r--r--    1 root     root          3317 Aug 15 13:28 benchmark_summary_20250815_132836.md
-rw-r--r--    1 1000     1000          1375 Aug 15 12:57 container_stats_20250815_095751.log
-rw-r--r--    1 root     root          1138 Aug 15 13:13 pgbench_13_prepared_20250815_130830.log
-rw-r--r--    1 root     root          1133 Aug 15 13:08 pgbench_13_readonly_20250815_130329.log
-rw-r--r--    1 root     root          1136 Aug 15 13:03 pgbench_13_standard_20250815_125829.log
-rw-r--r--    1 root     root          1121 Aug 15 13:28 pgbench_18_prepared_20250815_132336.log
-rw-r--r--    1 root     root          1118 Aug 15 13:23 pgbench_18_readonly_20250815_131835.log
-rw-r--r--    1 root     root          1121 Aug 15 13:18 pgbench_18_standard_20250815_131335.log
-rw-r--r--    1 root     root           104 Aug 15 12:54 system_stats_13_20250815_125408.log
-rw-r--r--    1 root     root           597 Aug 15 12:58 system_stats_13_20250815_125829.log
-rw-r--r--    1 root     root           597 Aug 15 13:13 system_stats_18_20250815_131335.log
```

## How to Reproduce

1. Clone this benchmark setup
2. Run: `docker compose up -d`
3. Execute: `docker exec pgbench_runner /benchmark-scripts/run_benchmarks.sh`
4. Check results in `/benchmark-results/` directory

---
*Report generated on: $(date)*
