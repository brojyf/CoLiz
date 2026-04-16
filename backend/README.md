# Backend Operations Quick Reference
```bash
# Start services (initializes DB if empty)
./deploy.sh prod up

# Stop services (keeps data intact)
./deploy.sh prod down

# Check status
./deploy.sh prod status

# View logs
./deploy.sh prod logs <api|worker|mysql|redis>

# Rebuild & Restart 
./deploy.sh prod build && ./deploy.sh prod restart

# Manual Key Rotation
./deploy.sh prod rotate
```

### Requirements
- Docker Engine 24+
- Docker Compose v2
- port 8080 free
- `prod.env` must be configured before starting


### Data Storage
- **MySQL DB:** `storage/data/mysql/`
- **Redis AOF:** `storage/data/redis/`
- **Avatars:** `storage/avatars/`
- **Runtime Secrets:** `runtime/rotation.env`

*Note: Data perfectly persists across restarts. If you need a complete clean slate, run `./deploy.sh prod down` and `rm -rf storage/data`.*


### Docker Architecture
```text
Host Machine
├── backend/
│   ├── storage/
│   │   ├── avatars/     ← Avatars & static files
│   │   └── data/
│   │       ├── mysql/   ← Persisted MySQL data
│   │       └── redis/   ← Persisted Redis AOF
│   ├── runtime/         ← Secret rotation files (rotation.env)
│   └── prod.env         ← Credentials

Docker Compose Services
├── mysql         — MySQL 8.0 (internal)
├── redis         — Redis 7 (internal)
├── api           — Go HTTP service (Port 8080)
├── worker        — Go email consumer
├── dlq_cleaner   — DLQ scheduled cleanup
└── rotation      — Secret rotation job
```

*All services use the default Docker Compose bridge network. Only the `api` service exposes port 8080 externally.*