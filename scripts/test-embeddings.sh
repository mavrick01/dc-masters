#!/bin/bash

echo "Checking for embeddings in database..."

podman exec dc-masters-postgres psql -U dcmasters -d litellm << 'EOF'
-- Check if langchain table was created
\dt langchain*

-- Count embeddings
SELECT COUNT(*) as total_embeddings FROM langchain_documents;

-- Show sample embeddings
SELECT
    id,
    LEFT(content, 100) as content_preview,
    metadata,
    vector_dims(embedding) as embedding_dimensions
FROM langchain_documents
LIMIT 5;
EOF
