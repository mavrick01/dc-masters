-- DC-Masters Container Toolkit - PostgreSQL Initialization
-- Creates databases and schemas for embeddings

-- Note: This script runs in the default database specified by POSTGRES_DB (litellm)

-- Create additional databases
CREATE DATABASE n8n;

-- Enable pgvector extension in litellm database
CREATE EXTENSION IF NOT EXISTS vector;

-- Create embeddings schema in litellm db for general embeddings
CREATE SCHEMA IF NOT EXISTS embeddings;

-- General documents table for student projects
CREATE TABLE IF NOT EXISTS embeddings.documents (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    embedding vector(1536),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for vector similarity search (was using IVFFLAT, but switched to HNSW for better performance with larger datasets))
CREATE INDEX IF NOT EXISTS idx_embeddings_documents_vector
-- ON embeddings.documents USING ivfflat (embedding vector_cosine_ops);
ON embeddings.documents USING hnsw (embedding vector_cosine_ops);

-- Create an index on the metadata filename for faster lookups
CREATE INDEX IF NOT EXISTS idx_doc_metadata_filename ON embeddings.documents ((metadata->>'filename'));

-- Create an index on the metadata filehash for faster lookups
CREATE INDEX IF NOT EXISTS idx_doc_metadata_filehash ON embeddings.documents ((metadata->>'filehash'));

-- Create airs scheme in litellm db for AIRS documents
CREATE SCHEMA IF NOT EXISTS airs;

-- AIRS documents table
CREATE TABLE airs.documents (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,         -- This maps to n8n's 'Content Column'
    metadata JSONB,               -- This stores url, name, hash, etc.
    embedding VECTOR(768),        -- This maps to n8n's 'Vector Column'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for vector similarity search (was using IVFFLAT, but switched to HNSW for better performance with larger datasets))
CREATE INDEX IF NOT EXISTS idx_airs_documents_vector
-- ON airs.documents USING ivfflat (embedding vector_cosine_ops);
ON airs.documents USING hnsw (embedding vector_cosine_ops);

-- Create index on source_url for filtering
CREATE INDEX IF NOT EXISTS idx_airs_documents_source
ON airs.documents((metadata->>'source_url'));

-- Create index on document_name for filtering
CREATE INDEX IF NOT EXISTS idx_airs_documents_name
ON airs.documents((metadata->>'name'));

-- Troubleshooting tips:
-- 1. Check if the database and tables were created successfully:
--    \c litellm    -- Connect to the litellm database
--   \dt           -- List tables in the current database    
--   \d embeddings.documents   -- Describe the structure of the embeddings.documents table  (check the vector size matches your embedding dimensions)
--   \d airs.documents         -- Describe the structure of the airs.documents table (check the vector size matches your embedding dimensions)
--   \c n8n         -- Connect to the n8n database to verify it was created
-- 2. Check if the pgvector extension is enabled:
--    \dx pgvector     -- Check if pgvector is listed as an installed extension
-- 3. Check if the indexes were created:
--    \di idx_embeddings_documents_vector   -- Check if the index on embeddings.documents is created
--    \di idx_airs_documents_vector         -- Check if the index on airs.documents is created
-- 4. If you encounter issues with vector search performance, 
--    consider adjusting the index type (e.g., switching between IVFFLAT and HNSW) based on your dataset size and query patterns.