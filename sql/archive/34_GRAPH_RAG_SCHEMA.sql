-- ============================================================================
-- INSURE Graph RAG Schema Setup
-- Purpose: Create GRAPH schema for insurance clause and data dependency graphs
-- Date: 2026-04-09
-- ============================================================================

-- Create GRAPH schema if not exists
CREATE SCHEMA IF NOT EXISTS INSURE_DB.GRAPH
COMMENT = 'Graph RAG structures for INSURE insurance policy clauses and data dependencies';

-- ============================================================================
-- GRAPH_NODES Table: Graph nodes (Clauses, Data, Rules, ML Models)
-- ============================================================================
CREATE OR REPLACE TABLE INSURE_DB.GRAPH.GRAPH_NODES (
    node_id VARCHAR(10) PRIMARY KEY,
    node_type VARCHAR(20) NOT NULL COMMENT 'CLAUSE | DATA | RULE | MODEL',
    name VARCHAR(255) NOT NULL COMMENT 'Node display name',
    description VARCHAR(1000),
    chapter VARCHAR(100) COMMENT 'For CLAUSE: 총칙, 보험금지급, 보험료, 보험계약, 품목별보장한도, 분쟁해결',
    schema_name VARCHAR(100) COMMENT 'For DATA: schema name (INSURE_DB.MART, INSURE_DB.RAW, etc.)',
    table_name VARCHAR(255) COMMENT 'For DATA: actual table/view name',
    rule_version VARCHAR(20) COMMENT 'For RULE: version string',
    model_type VARCHAR(100) COMMENT 'For MODEL: Cortex ML, Agent, etc.',
    metadata VARIANT COMMENT 'Additional metadata as JSON',
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- GRAPH_EDGES Table: Relationships between nodes
-- ============================================================================
CREATE OR REPLACE TABLE INSURE_DB.GRAPH.GRAPH_EDGES (
    edge_id VARCHAR(20) PRIMARY KEY,
    source_node_id VARCHAR(10) NOT NULL,
    target_node_id VARCHAR(10) NOT NULL,
    edge_type VARCHAR(30) NOT NULL COMMENT 'REFERENCES | CALCULATES | COVERS | LIMITS | APPLIES | PREDICTS',
    weight FLOAT DEFAULT 0.5 COMMENT 'Edge weight: 0.0 ~ 1.0 (importance/strength)',
    description VARCHAR(1000),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (source_node_id) REFERENCES INSURE_DB.GRAPH.GRAPH_NODES(node_id),
    FOREIGN KEY (target_node_id) REFERENCES INSURE_DB.GRAPH.GRAPH_NODES(node_id)
);

-- Create indexes for graph traversal performance
CREATE INDEX IF NOT EXISTS IDX_EDGES_SOURCE ON INSURE_DB.GRAPH.GRAPH_EDGES(source_node_id);
CREATE INDEX IF NOT EXISTS IDX_EDGES_TARGET ON INSURE_DB.GRAPH.GRAPH_EDGES(target_node_id);
CREATE INDEX IF NOT EXISTS IDX_EDGES_TYPE ON INSURE_DB.GRAPH.GRAPH_EDGES(edge_type);
CREATE INDEX IF NOT EXISTS IDX_NODES_TYPE ON INSURE_DB.GRAPH.GRAPH_NODES(node_type);

-- ============================================================================
-- GRAPH_PATHS Table: Cached paths for query optimization
-- ============================================================================
CREATE OR REPLACE TABLE INSURE_DB.GRAPH.GRAPH_PATHS (
    path_id VARCHAR(30) PRIMARY KEY,
    source_node_id VARCHAR(10) NOT NULL,
    target_node_id VARCHAR(10) NOT NULL,
    hop_count INT,
    path_nodes ARRAY COMMENT 'Sequence of node IDs',
    path_edges ARRAY COMMENT 'Sequence of edge types',
    total_weight FLOAT COMMENT 'Product of edge weights',
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- GRAPH_TRAVERSAL_LOG Table: Track graph query patterns
-- ============================================================================
CREATE OR REPLACE TABLE INSURE_DB.GRAPH.GRAPH_TRAVERSAL_LOG (
    log_id VARCHAR(50) PRIMARY KEY DEFAULT UUID_STRING(),
    query_type VARCHAR(100) COMMENT 'clause_references, backward_lookup, path_search, etc.',
    source_node_id VARCHAR(10),
    target_node_id VARCHAR(10),
    hops INT,
    result_count INT,
    execution_time_ms INT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    query_text VARCHAR(2000)
);

-- ============================================================================
-- Grants for roles
-- ============================================================================
GRANT USAGE ON SCHEMA INSURE_DB.GRAPH TO ROLE ANALYTICS_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA INSURE_DB.GRAPH TO ROLE ANALYTICS_ROLE;
GRANT INSERT, UPDATE ON TABLE INSURE_DB.GRAPH.GRAPH_NODES TO ROLE ANALYTICS_ROLE;
GRANT INSERT, UPDATE ON TABLE INSURE_DB.GRAPH.GRAPH_EDGES TO ROLE ANALYTICS_ROLE;
GRANT INSERT ON TABLE INSURE_DB.GRAPH.GRAPH_TRAVERSAL_LOG TO ROLE ANALYTICS_ROLE;

COMMENT ON TABLE INSURE_DB.GRAPH.GRAPH_NODES IS 'All nodes in the INSURE Graph RAG: 14 clauses, 11 data sources, 4 rules, 2 ML models';
COMMENT ON TABLE INSURE_DB.GRAPH.GRAPH_EDGES IS 'Relationships between graph nodes with edge types and weights';
