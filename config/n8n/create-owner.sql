-- N8N Owner Account Creation SQL Script
-- This script creates or updates the owner account

-- Enable pgcrypto for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create or update owner account
DO $$
DECLARE
    owner_id UUID;
    owner_email TEXT := 'admin@dcmasters.local';
    owner_password TEXT := 'changeme123';
    owner_first_name TEXT := 'Admin';
    owner_last_name TEXT := 'User';
    password_hash TEXT;
BEGIN
    -- Generate bcrypt hash for password (cost factor 10)
    password_hash := crypt(owner_password, gen_salt('bf', 10));

    -- Check if owner exists
    SELECT id INTO owner_id FROM public.user WHERE "roleSlug" = 'global:owner';

    IF owner_id IS NOT NULL THEN
        -- Update existing owner if it has no email (empty placeholder)
        UPDATE public.user
        SET
            email = owner_email,
            "firstName" = owner_first_name,
            "lastName" = owner_last_name,
            password = password_hash,
            settings = '{"userActivated": true}'::jsonb,
            "updatedAt" = NOW()
        WHERE id = owner_id AND (email IS NULL OR email = '');

        IF FOUND THEN
            RAISE NOTICE '[N8N Setup] Owner account updated successfully';
            RAISE NOTICE '[N8N Setup] Login with: % / %', owner_email, owner_password;
        ELSE
            RAISE NOTICE '[N8N Setup] Owner already exists with email: %', (SELECT email FROM public.user WHERE id = owner_id);
        END IF;
    ELSE
        -- Create new owner
        owner_id := gen_random_uuid();
        INSERT INTO public.user (
            id, email, "firstName", "lastName", password, "roleSlug",
            settings, disabled, "mfaEnabled", "createdAt", "updatedAt"
        ) VALUES (
            owner_id, owner_email, owner_first_name, owner_last_name, password_hash, 'global:owner',
            '{"userActivated": true}'::jsonb, false, false, NOW(), NOW()
        );
        RAISE NOTICE '[N8N Setup] Owner account created successfully';
        RAISE NOTICE '[N8N Setup] Login with: % / %', owner_email, owner_password;
    END IF;
END $$;
