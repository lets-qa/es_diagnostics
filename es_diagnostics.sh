#!/usr/bin/env bash


function show_help() {
  cat <<EOF
Usage: $0 [--env FILE] [--run TAG1,TAG2,...]

Options:
  --env FILE       Path to .env file with configuration variables.
  --run TAGS       Comma-separated list of diagnostic checks to run.
                   Available TAGS: health, stats, nodes, pending, indexstats, shards, indices, catnodes, threadpool
  -h, --help       Display this help message.

Examples:
  $0 --env dev.env
  $0 --env prod.env --run health,nodes
EOF
}
# === CLI Argument Parsing ===
ENV_FILE=".env"
RUN_ALL=true
RUN_KEYS=()

while [[ $# -gt 0 ]]; do
    -h|--help)
      show_help
      exit 0
      ;;

  case "$1" in
    --env)
      ENV_FILE="$2"
      shift 2
      ;;
    --run)
      IFS=',' read -r -a RUN_KEYS <<< "$2"
      RUN_ALL=false
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Usage: $0 [--env path/to/envfile] [--run health,stats,nodes,...]"
      exit 1
      ;;
  esac
done

# === Load .env File ===
if [ -f "$ENV_FILE" ]; then
  echo "📄 Loading environment from: $ENV_FILE"
  source "$ENV_FILE"
else
  echo "❌ Environment file '$ENV_FILE' not found."
  exit 1
fi

# === Configuration ===
ES_HOST=${ES_HOST:-"http://localhost:9200"}
MODE=${MODE:-"pretty"}  # Options: pretty | json

# === Determine Authentication Method ===
AUTH=()
if [[ -n "$ES_USER" && -n "$ES_PASS" ]]; then
  AUTH=(--user "$ES_USER:$ES_PASS")
  AUTH_MODE="basic"
elif [[ -n "$AUTH_TOKEN" ]]; then
  AUTH=(-H "Authorization: Bearer $AUTH_TOKEN")
  AUTH_MODE="bearer"
else
  AUTH_MODE="none"
fi

# === File Output Setup ===
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_PRETTY="es_diagnostics_$TIMESTAMP.log"
LOG_JSON="es_diagnostics_$TIMESTAMP.json"

echo "📊 Elasticsearch Diagnostics Script"
echo "🕒 Timestamp: $TIMESTAMP"
echo "🔗 Target: $ES_HOST"
echo "🔐 Auth Mode: $AUTH_MODE"
echo "📁 Output Mode: $MODE"
echo "----------------------------------------"

declare -A RESPONSES

function should_run() {
  $RUN_ALL && return 0
  local key="$1"
  for r in "${RUN_KEYS[@]}"; do
    [[ "$r" == "$key" ]] && return 0
  done
  return 1
}

function run_check() {
  local key="$1"
  local url="$2"
  local desc="$3"
  should_run "$key" || return
  echo -e "\n🔍 $desc"
  local result
  result=$(curl -s "${AUTH[@]}" "$ES_HOST$url")
  if [[ "$MODE" == "json" ]]; then
    RESPONSES["$key"]="$result"
  else
    echo "👉 GET $url" >> "$LOG_PRETTY"
    echo "$result" | jq . | tee -a "$LOG_PRETTY"
  fi
}

run_check "health" "/_cluster/health" "Cluster Health"
run_check "stats" "/_cluster/stats" "Cluster Stats"
run_check "nodes" "/_nodes/stats/jvm,os,process,fs,indices" "Node Stats (JVM, OS, FS, etc)"
run_check "pending" "/_cluster/pending_tasks" "Pending Tasks"
run_check "indexstats" "/_stats" "Index Stats"
run_check "shards" "/_cat/shards?format=json" "Shard Allocation"
run_check "indices" "/_cat/indices?format=json" "Index Summary"
run_check "catnodes" "/_cat/nodes?format=json" "Node Summary"
run_check "threadpool" "/_nodes/stats/thread_pool" "Thread Pool Stats"

if [[ "$MODE" == "json" ]]; then
  {
    echo "{"
    count=0
    for key in "${!RESPONSES[@]}"; do
      ((count++))
      comma=","
      [[ $count -eq ${#RESPONSES[@]} ]] && comma=""
      echo "  \"$key\": ${RESPONSES[$key]}$comma"
    done
    echo "}"
  } > "$LOG_JSON"
  echo -e "\n✅ Structured JSON written to $LOG_JSON"
else
  echo -e "\n✅ Diagnostics complete. Pretty log saved to $LOG_PRETTY"
fi
