LITELLM_URL="${LITELLM_URL:-http://localhost:4000}"
MASTER_KEY="${LITELLM_MASTER_KEY:-sk-1234-changeme}"

models_response=$(curl -s -X GET "$LITELLM_URL/model/info" \
    -H "Authorization: Bearer $MASTER_KEY")

models_json=$(python3 config/litellm/parse-models.py config/litellm/config.yaml 2>/dev/null || echo "[]")

MODEL_NAMES=()
while IFS= read -r model_name; do
    MODEL_NAMES+=("$model_name")
done < <(echo "$models_json" | python3 -c "
import sys, json
try:
    models = json.load(sys.stdin)
    for model in models:
        print(model['model_name'])
except:
    pass
" 2>/dev/null)

for model_name in "${MODEL_NAMES[@]}"; do
    model_id=$(echo "$models_response" | grep -o "\"model_name\":\"$model_name\"" -A 20 | grep -o '"model_id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$model_id" ]; then
        echo "Removing model: $model_name (ID: $model_id)"
    fi
done

