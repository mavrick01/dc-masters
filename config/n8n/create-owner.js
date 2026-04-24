#!/usr/bin/env node
// N8N Owner Account Creation Script
// This script creates the owner account by directly inserting into the database

const crypto = require('crypto');
const { Client } = require('pg');

async function createOwner() {
    const email = process.env.N8N_OWNER_EMAIL || 'admin@dcmasters.local';
    const password = process.env.N8N_OWNER_PASSWORD || 'changeme123';
    const firstName = process.env.N8N_OWNER_FIRST_NAME || 'Admin';
    const lastName = process.env.N8N_OWNER_LAST_NAME || 'User';

    // Connect to PostgreSQL
    const client = new Client({
        host: process.env.DB_POSTGRESDB_HOST || 'postgres',
        port: process.env.DB_POSTGRESDB_PORT || 5432,
        database: process.env.DB_POSTGRESDB_DATABASE || 'n8n',
        user: process.env.DB_POSTGRESDB_USER || 'dcmasters',
        password: process.env.DB_POSTGRESDB_PASSWORD || 'changeme123'
    });

    try {
        await client.connect();
        console.log('[N8N Setup] Connected to database');

        // Check if owner exists and has data
        const checkResult = await client.query(
            'SELECT id, email FROM public.user WHERE "roleSlug" = $1',
            ['global:owner']
        );

        if (checkResult.rows.length > 0 && checkResult.rows[0].email) {
            console.log(`[N8N Setup] Owner already exists: ${checkResult.rows[0].email}`);
            return;
        }

        // Import bcrypt for password hashing (N8N uses bcryptjs)
        const bcrypt = require('bcryptjs');
        const passwordHash = await bcrypt.hash(password, 10);

        // Update existing owner or create new one
        if (checkResult.rows.length > 0) {
            // Update existing empty owner
            await client.query(
                `UPDATE public.user
                 SET email = $1, "firstName" = $2, "lastName" = $3, password = $4,
                     settings = '{"userActivated": true}'::jsonb
                 WHERE id = $5`,
                [email, firstName, lastName, passwordHash, checkResult.rows[0].id]
            );
            console.log('[N8N Setup] Owner account updated successfully');
        } else {
            // Create new owner
            const id = crypto.randomUUID();
            await client.query(
                `INSERT INTO public.user
                 (id, email, "firstName", "lastName", password, "roleSlug", settings, disabled, "mfaEnabled", "createdAt", "updatedAt")
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW())`,
                [id, email, firstName, lastName, passwordHash, 'global:owner', '{"userActivated": true}', false, false]
            );
            console.log('[N8N Setup] Owner account created successfully');
        }

        console.log(`[N8N Setup] Login with: ${email} / ${password}`);
    } catch (error) {
        console.error('[N8N Setup] Error:', error.message);
        process.exit(1);
    } finally {
        await client.end();
    }
}

createOwner();
