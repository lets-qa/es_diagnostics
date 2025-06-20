# Elasticsearch Diagnostics Script

## Overview

This script collects and logs performance metrics from an Elasticsearch cluster.

### Features:
- Supports Basic Auth, Bearer Token, or No Auth
- Select specific diagnostics to run
- Outputs in either pretty `.log` or structured `.json`

## Usage

### Basic Example
```bash
./es_diagnostics.sh --env config/dev.env
```

### Run Specific Checks
```bash
./es_diagnostics.sh --env config/prod.env --run health,nodes,stats
```

### Auth Support
- `ES_USER` + `ES_PASS` → Basic Auth
- `AUTH_TOKEN` → Bearer Token
- None → No Auth

### Output Modes
Set in `.env`:
- `MODE=pretty` → Human-readable
- `MODE=json` → Structured machine-friendly format

### macOS Users
macOS ships with Bash 3.2 which lacks features required for JSON mode.
To fix:
```bash
brew install bash
```
Update script shebang to:
```bash
#!/usr/local/bin/bash
```

## Sample .env (dev.env)
```env
ES_HOST=http://localhost:9200
ES_USER=elastic
ES_PASS=changeme
MODE=pretty
```

## Sample .env (prod.env)
```env
ES_HOST=https://your-prod-es.example.com
AUTH_TOKEN=your-token-here
MODE=json
```


## Diagnostic Modes and Tags

Use the `--run` flag to selectively execute checks. Below is a list of available modes:

| Tag        | Description                        | Elasticsearch Endpoint |
|------------|------------------------------------|-------------------------|
| `health`   | Cluster health status              | `/_cluster/health`      |
| `stats`    | Cluster-wide statistics            | `/_cluster/stats`       |
| `nodes`    | Node-level JVM, CPU, FS stats      | `/_nodes/stats/jvm,os,process,fs,indices` |
| `pending`  | Cluster pending tasks              | `/_cluster/pending_tasks` |
| `indexstats` | Index stats (docs, store, etc.) | `/_stats`               |
| `shards`   | Shard allocation details           | `/_cat/shards?format=json` |
| `indices`  | Index summary information          | `/_cat/indices?format=json` |
| `catnodes` | Node summary (cat API)             | `/_cat/nodes?format=json` |
| `threadpool` | Thread pool metrics per node    | `/_nodes/stats/thread_pool` |

### Example:
```bash
./es_diagnostics.sh --env config/prod.env --run health,stats,threadpool
```
