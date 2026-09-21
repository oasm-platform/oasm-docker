# OASM Platform — Docker Deployment

Self-hosted [Open Attack Surface Management](https://github.com/oasm-platform) stack: web console, core API, scan workers, PostgreSQL, Redis, RustFS object storage, and a GeoIP service.

> For authorized security testing only. Scan only systems you own or have written permission to test.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new/oasm-platform/oasm-docker?skip_quickstart=true&machine=standardLinux32gb&repo=1080874592&ref=main)

## Requirements

| Item | Minimum |
| --- | --- |
| Docker Engine | 24+ with Compose v2 |
| GNU Make | any (optional, convenience wrapper) |
| CPU | 4 cores |
| RAM | 4 GB (8 GB recommended) |
| Disk | 20 GB free |

The worker mounts `/var/run/docker.sock` and spawns connector containers on the host daemon, so the host must expose a working Docker daemon to the worker container.

## Quick start

```bash
cp .env.example .env   # then edit secrets
make                   # pull latest commit + pull images + start
```

Without Make:

```bash
docker compose pull
docker compose up -d
```

## Access

| Service | URL |
| --- | --- |
| Web console | http://localhost:6276 |
| Core API | http://localhost:16276 |
| Worker connector gRPC | localhost:26276 (internal, dialed by spawned connectors) |

Check readiness:

```bash
docker compose ps
curl -f http://localhost:6276/api/health
```

## Services

| Container | Image | Role |
| --- | --- | --- |
| `oasm-console` | `oasm/oasm-console` | nginx serving the UI, proxies `/api/` to `core-api` |
| `oasm-api` | `oasm/oasm-api` | Core API + gRPC, port `16276` |
| `oasm-migration` | `oasm/oasm-api` | One-shot TypeORM migration, must exit 0 before API starts |
| `oasm-worker` | `oasm/oasm-worker` | Scan orchestration in `node` mode; spawns connector containers |
| `oasm-postgres` | `postgres:17` | Primary database |
| `oasm-redis` | `redis:alpine` | Queue, cache, rate limiting |
| `oasm-rustfs` | `rustfs/rustfs` | S3-compatible object storage |
| `geo-ip-database` | `ghcr.io/l1ttps/geoip-proxy` | GeoIP lookups, `linux/amd64` only |

Named volumes: `pgdata`, `redis-data`, `geoip-data`, `rustfs-data`, `worker-tools-cache`.

## Configuration

All settings come from `.env` (created from `.env.example`).

| Variable | Default | Notes |
| --- | --- | --- |
| `IMAGE_TAG` | `latest` | Image tag for all `oasm/*` images |
| `OASM_CLOUD_APIKEY` | `change_me` | Cloud API key; also used as `WORKER_API_KEY` |
| `POSTGRES_HOST` | `postgres` | |
| `POSTGRES_USERNAME` | `postgres` | |
| `POSTGRES_PASSWORD` | `postgres` | Change before exposing anything |
| `POSTGRES_PORT` | `5432` | |
| `POSTGRES_DB` | `open_asm` | |
| `POSTGRES_SSL` | `false` | Set `true` for managed Postgres |
| `PORT` | `6277` | Core API listen port inside the container network |
| `REDIS_URL` | `redis://:open_asm@redis:6379/0` | Must match `REDIS_PASSWORD` |
| `REDIS_PASSWORD` | `open_asm` | |
| `ENCRYPTION_KEYS` | `super_secret_key` | Comma-separated KEKs; **last key encrypts**, earlier keys decrypt only |
| `GEO_IP_URL` | `geo-ip-database:4360` | |
| `RUSTFS_ENDPOINT` | `http://rustfs:9000` | |
| `RUSTFS_ACCESS_KEY` | `rustfsadmin` | |
| `RUSTFS_SECRET_KEY` | `rustfssecret` | |

Notes:

- `ENCRYPTION_KEYS` is a secret store of last resort: losing every key makes stored credentials unrecoverable. Keep a backup outside this host.
- Rotating: append the new key at the end, restart, then drop old keys only after re-encryption.
- The compose file's `POSTGRES_*` and Redis defaults apply only when a variable is unset; `.env` always wins.

## Operations

### Make targets

| Target | Action |
| --- | --- |
| `make` / `make all` | `git pull` + `docker compose pull` + `up -d` |
| `make pull` | Pull images |
| `make run` | Start services without pulling |
| `make update` | Pull latest commit, pull images, recreate services |
| `make pull-latest-commit` | `git pull` only |
| `make update-main` | Pull and recreate main services |
| `make down` | `docker compose down --remove-orphans` |

### Common commands

```bash
docker compose logs -f                 # all logs
docker compose logs -f core-api        # one service
docker compose up -d --force-recreate  # apply .env changes
docker compose down                    # stop, keep data
docker compose down -v                 # stop and DELETE all volumes
```

Plain `docker compose down` keeps data. `down -v` destroys databases, object storage, GeoIP data, and the tool cache irreversibly.

### Upgrades

```bash
make update        # or: docker compose pull && docker compose up -d
```

The `migration` service runs on every start and is idempotent. If it exits non-zero the API will not start — inspect `docker compose logs migration`.

### Backup

State lives in named volumes. Back up Postgres at minimum:

```bash
docker compose exec postgres pg_dump -U postgres open_asm > backup.sql
```

## Networking

- Private bridge network `oasm_net`; only `6276`, `16276`, and `26276` are published.
- The console proxies `/api/` to `core-api:${PORT}` (see `nginx.conf`) — change `PORT` and the console upstream must change with it.
- Spawned connector containers run on the host daemon and dial back via `host.docker.internal:26276` (`WORKER_CONNECTOR_ADDR`). Keep that port published and do not point it at `0.0.0.0` or a container IP.
- `oasm-worker` is single-instance by design: it owns the host-published `26276`. To scale, give each replica its own connector port and `WORKER_CONNECTOR_ADDR`.

## Security

- `/var/run/docker.sock` is mounted into `oasm-worker` and is root-equivalent on the host. Run only trusted images and treat the worker as privileged.
- The image runs as uid/gid `1000`; `group_add: ['0']` grants socket access. On a host with a dedicated `docker` group, use that gid instead.
- Change every default in `.env` — Postgres password, Redis password, RustFS keys, and `ENCRYPTION_KEYS` — before exposing the stack beyond localhost.
- The GeoIP image is pinned to `linux/amd64`; on ARM hosts it runs under emulation or not at all.
