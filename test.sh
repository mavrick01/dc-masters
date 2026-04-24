N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJlMjQ1OGEwYS0wZTBjLTQzODItYTE5OS02Y2E5OGQyOWFjZDciLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiZTY1NGRmYWQtZDgxZS00OTExLWEwZTgtODdmMmFiZDQ4MWFhIiwiaWF0IjoxNzc2OTQxMTU2LCJleHAiOjE3Nzk0NTg0MDB9.CHXGD498GI6F_a98njnQ5AMYPsxJdMbfAbT5qD4uitA"

cred_data=$(cat credentials/google_credentials.json | jq -c '{
        email: .client_email,
        privateKey: .private_key,
        inpersonate: false,
        httpNode: false
    }')


cred_name="Google Cloud - Vertex AI"
cred_type="googleApi"

payload=$(jq -n \
        --arg name "$cred_name" \
        --arg type "$cred_type" \
        --argjson data "$cred_data" \
        '{
            name: $name,
            type: $type,
            data: $data,
            isGlobal: true,
            isResolvable: false
        }')

printf '%s\n' "payload data: $payload"
response=$(curl -s -X POST "$N8N_URL/api/v1/credentials" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload")

printf '%s\n' "response: $response"
if echo "$response" | grep -q "id"; then
    cred_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    echo  "  ✓ Created credential: $cred_name (ID: $cred_id)"
    echo "$cred_id"
    return 0
else
    echo "  ✗ Failed to create credential: $cred_name"
    echo "    Response: $response"
    return 1
fi
