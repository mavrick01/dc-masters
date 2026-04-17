-- DC-Masters Container Toolkit - PostgreSQL Initialization
-- Creates databases and schemas for embeddings

-- Enable pgvector extension in default database (litellm)
CREATE EXTENSION IF NOT EXISTS vector;

-- Create schema for general embeddings
CREATE SCHEMA IF NOT EXISTS embeddings;

-- General documents table for student projects
CREATE TABLE IF NOT EXISTS embeddings.documents (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    embedding vector(1536),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for vector similarity search
CREATE INDEX IF NOT EXISTS idx_embeddings_documents_vector
ON embeddings.documents USING ivfflat (embedding vector_cosine_ops);

-- Create separate database for AIRS documentation
CREATE DATABASE airs_embedding;

-- Connect to airs_embedding database and set up schema
\c airs_embedding;

-- Enable pgvector extension in airs_embedding database
CREATE EXTENSION IF NOT EXISTS vector;

-- Create schema for AIRS documents
CREATE SCHEMA IF NOT EXISTS airs;

-- AIRS documents table
CREATE TABLE IF NOT EXISTS airs.documents (
    id SERIAL PRIMARY KEY,
    source_url TEXT NOT NULL,
    document_name TEXT NOT NULL,
    page_number INTEGER,
    chunk_index INTEGER,
    content TEXT NOT NULL,
    embedding vector(1536),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(source_url, page_number, chunk_index)
);

-- Create index for vector similarity search
CREATE INDEX IF NOT EXISTS idx_airs_documents_vector
ON airs.documents USING ivfflat (embedding vector_cosine_ops);

-- Create index on source_url for filtering
CREATE INDEX IF NOT EXISTS idx_airs_documents_source
ON airs.documents(source_url);

-- Create index on document_name for filtering
CREATE INDEX IF NOT EXISTS idx_airs_documents_name
ON airs.documents(document_name);

-- Switch back to default database
\c litellm;
