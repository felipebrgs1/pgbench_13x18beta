-- Salve como init-scripts/01_init.sql
-- Script de inicialização para benchmark

-- Habilitar extensões úteis para benchmark
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_buffercache;

-- Configurar pg_stat_statements
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
-- ALTER SYSTEM SET pg_stat_statements.track = 'all';  -- This parameter doesn't exist in PG13
-- ALTER SYSTEM SET pg_stat_statements.max = 10000;  -- This parameter doesn't exist in PG13, using defaults

-- Criar uma tabela adicional para testes personalizados
CREATE TABLE IF NOT EXISTS benchmark_test (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    value INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data JSONB,
    UNIQUE(name, value)
);

-- Criar índices para teste
CREATE INDEX IF NOT EXISTS idx_benchmark_name ON benchmark_test(name);
CREATE INDEX IF NOT EXISTS idx_benchmark_value ON benchmark_test(value);
CREATE INDEX IF NOT EXISTS idx_benchmark_created ON benchmark_test(created_at);
CREATE INDEX IF NOT EXISTS idx_benchmark_jsonb ON benchmark_test USING GIN(data);

-- Inserir dados de exemplo
INSERT INTO benchmark_test (name, value, data) 
SELECT 
    'test_' || (i % 1000),
    i,
    jsonb_build_object(
        'category', 'cat_' || (i % 10),
        'metadata', jsonb_build_object('score', random() * 100, 'active', i % 2 = 0)
    )
FROM generate_series(1, 10000) i
ON CONFLICT (name, value) DO NOTHING;

-- Criar uma função para teste de performance
CREATE OR REPLACE FUNCTION benchmark_heavy_query(p_limit INTEGER DEFAULT 1000)
RETURNS TABLE(
    name VARCHAR,
    avg_value NUMERIC,
    count_records BIGINT,
    max_created TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bt.name,
        AVG(bt.value)::NUMERIC(10,2) as avg_value,
        COUNT(*)::BIGINT as count_records,
        MAX(bt.created_at) as max_created
    FROM benchmark_test bt
    WHERE bt.value > (SELECT AVG(value) FROM benchmark_test) * 0.5
    GROUP BY bt.name
    HAVING COUNT(*) > 5
    ORDER BY avg_value DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;