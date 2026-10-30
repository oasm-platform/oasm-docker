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
cp .env.example .env   # then edit secrets; BETTER_AUTH_SECRET is required
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
| Worker connector gRPC | :26276 on the `oasm_connectors` network (internal, not published) |

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
| `oasm-postgres` | `postgres:18` | Primary database |
| `oasm-redis` | `redis:alpine` | Queue, cache, rate limiting |
| `oasm-rustfs` | `rustfs/rustfs` | S3-compatible object storage |
| `geo-ip-database` | `ghcr.io/oasm-platform/dbip` | GeoIP lookups, `linux/amd64` only |

Named volumes: `pgdata18`, `redis-data`, `geoip-data`, `rustfs-data`, `worker-tools-cache`.

## Configuration

All settings come from `.env` (created from `.env.example`).

| Variable | Default | Notes |
| --- | --- | --- |
| `IMAGE_TAG` | `latest` | Image tag for all `oasm/*` images |
| `OASM_CLOUD_APIKEY` | `change_me` | Cloud API key; also used as `WORKER_API_KEY` |
| `WORKER_REPLICAS` | `3` | Number of `oasm-worker` replicas started by `make` |
| `POSTGRES_HOST` | `postgres` | |
| `POSTGRES_USERNAME` | `postgres` | |
| `POSTGRES_PASSWORD` | `postgres` | Change before exposing anything |
| `POSTGRES_PORT` | `5432` | |
| `POSTGRES_DB` | `open_asm` | |
| `POSTGRES_SSL` | `false` | Set `true` for managed Postgres |
| `PORT` | `6277` | Core API listen port inside the container network |
| `REDIS_URL` | `redis://:open_asm@redis:6379/0` | Must match `REDIS_PASSWORD` |
| `REDIS_PASSWORD` | `open_asm` | |
| `BETTER_AUTH_SECRET` | — | **Required.** Signs sessions and email verification links; a random value of 32+ characters (`openssl rand -base64 32`). Newer images won't start without it |
| `BASE_URL` | — | Public URL of the console, origin only (e.g. `https://cloud.oasm.io`); used for email verification links and the Telegram webhook |
| `ENCRYPTION_KEYS` | — | **Required.** Comma-separated keys; **last key encrypts**, earlier keys decrypt only. core-api won't start unless the last key is random and 32+ characters (`openssl rand -base64 32`) |
| `GEO_IP_URL` | `geo-ip-database:4360` | |
| `RUSTFS_ENDPOINT` | `http://rustfs:9000` | |
| `RUSTFS_ACCESS_KEY` | `rustfsadmin` | |
| `RUSTFS_SECRET_KEY` | `rustfssecret` | |

Notes:

- `BETTER_AUTH_SECRET` must stay private and stable: anyone who knows it can forge sessions and verification links, and changing it signs every user out.
- `ENCRYPTION_KEYS` is a secret store of last resort: losing every key makes stored credentials unrecoverable. Keep a backup outside this host.
- Rotating: append the new key at the end and restart; core-api re-encrypts stored secrets with it at boot. Drop an old key only once the core-api log says no stored secret needs it.
- Stacks set up before `ENCRYPTION_KEYS` reached core-api stored credentials under a built-in default key, whatever `.env` said. Set a new key and restart: that data stays readable and is re-encrypted with the new key.
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

#### PostgreSQL 17 → 18

> **Experimental** — first tested on OASM **v0.91**. Back up before you start.

Postgres now runs on `postgres:18` with a new volume, `pgdata18`, mounted at `/var/lib/postgresql` (the 18 image keeps its data in `/var/lib/postgresql/18/docker`). The old PG17 volume `<project>_pgdata` is not mounted any more and is never modified. PG18 cannot read PG17 data files, so after updating the stack comes up with an **empty** database until you restore the old data into it.

The steps below work whether or not you have already updated, because they dump straight from the old volume using a temporary PG17 container.

```bash
# 0. Update to the PG18 compose file and let the stack start once
#    (creates pgdata18 and an empty open_asm schema)
make update

# 1. Find the old PG17 volume (usually <project>_pgdata, e.g. oasm-docker_pgdata)
docker volume ls | grep pgdata
OLD_VOLUME=oasm-docker_pgdata

# 2. Dump open_asm from the old volume with a temporary PG17 container
docker run -d --name pg17-restore -e POSTGRES_PASSWORD=x \
  -v "$OLD_VOLUME":/var/lib/postgresql/data postgres:17
until docker exec pg17-restore pg_isready -U postgres -q; do sleep 1; done
docker exec pg17-restore pg_dump -U postgres -Fc open_asm > open_asm_pg17.dump
docker rm -f pg17-restore

# 3. (optional) Back up the current PG18 database
docker compose exec -T postgres pg_dump -U postgres -Fc open_asm > open_asm_pg18.dump

# 4. Stop everything that writes to the database
docker compose stop console core-api oasm-worker

# 5. Replace open_asm in PG18 with the PG17 data
docker compose exec -T postgres psql -U postgres -d postgres \
  -c "DROP DATABASE open_asm WITH (FORCE)" -c "CREATE DATABASE open_asm"
docker compose exec -T postgres pg_restore -U postgres -d open_asm --no-owner < open_asm_pg17.dump

# 6. Start the stack again; migration should report "No migrations are pending"
docker compose up -d
docker compose logs migration --tail 5
```

Notes:

- Replace `postgres` / `open_asm` if you changed `POSTGRES_USERNAME` / `POSTGRES_DB` in `.env`.
- On Windows Git Bash, prefix the `docker run` in step 2 with `MSYS_NO_PATHCONV=1` so the volume path is not rewritten.
- Check the data is back, e.g. `docker compose exec -T postgres psql -U postgres -d open_asm -c "select count(*) from assets"`, then reload the console.
- Keep the old volume for a few days. Once you are satisfied: `docker volume rm "$OLD_VOLUME"`. To roll back instead, revert to `postgres:17` with the `pgdata:/var/lib/postgresql/data` mount — the old volume is unchanged.

### Backup

State lives in named volumes. Back up Postgres at minimum:

```bash
docker compose exec postgres pg_dump -U postgres open_asm > backup.sql
```

## Networking

- Private bridge network `oasm_net`; only `6276` and `16276` are published.
- The console proxies `/api/` to `core-api:${PORT}` (see `nginx.conf`) — change `PORT` and the console upstream must change with it.
- Spawned connector containers join the separate `oasm_connectors` network (`WORKER_CONNECTOR_NETWORK`) and dial the worker replica that started them on its own IP, port `26276`. They are not on `oasm_net`, so they cannot reach postgres or redis.
- `oasm-worker` runs `WORKER_REPLICAS` replicas (default `3`), so `make` / `docker compose up -d` starts three workers. Override once with `docker compose up -d --scale oasm-worker=N`. Nothing is published per replica, so they never collide. `WORKER_MAX_CONCURRENCY` applies per replica — lower it (or set `cpus`/`mem_limit`) when several share one host.

## Security

- `/var/run/docker.sock` is mounted into `oasm-worker` and is root-equivalent on the host. Run only trusted images and treat the worker as privileged.
- The image runs as uid/gid `1000`; `group_add: ['0']` grants socket access. On a host with a dedicated `docker` group, use that gid instead.
- Change every default in `.env` — Postgres password, Redis password and RustFS keys — and set `ENCRYPTION_KEYS` and `BETTER_AUTH_SECRET` before exposing the stack beyond localhost.
- The GeoIP image is pinned to `linux/amd64`; on ARM hosts it runs under emulation or not at all.
