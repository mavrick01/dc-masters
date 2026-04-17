DC-Masters Container Toolkit - Sandbox Directory
=================================================

This directory is accessible to the MCP Filesystem Server and N8N workflows.

Directory Structure:
--------------------
/import/  - Drop files here for automatic embedding (Workflow 1 watches this directory)
/shared/  - General file storage for your experiments

How to Use:
-----------
1. Place text files in /import/ to have them automatically embedded into the vector database
2. The embedding workflow runs every 5 minutes and processes new files
3. After processing, files are moved to /shared/ directory
4. You can then query these documents using the AI agent workflows (Workflows 2 & 3)

Example:
--------
1. Create a file: echo "Machine learning is a subset of artificial intelligence." > import/ml-basics.txt
2. Wait 5 minutes (or manually trigger Workflow 1 in N8N)
3. Query via webhook: curl -X POST http://localhost:5678/webhook/ai-agent -d '{"question": "What is machine learning?"}'

Security Note:
--------------
- The MCP Filesystem Server has read/write access to this entire sandbox directory
- Do not store sensitive information here
- This directory is isolated from your host system

Happy learning!
