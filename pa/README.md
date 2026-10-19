# Plausible Analytics (`pa`)

One Plausible Community Edition instance serves `pa.joshwel.co` and
`pa.scorchthinks.dev`. The primary URL is `https://pa.joshwel.co`; Caddy sends
tracking requests on both hostnames to `pa:8000` over the existing
`corepub_default` Docker network. Dashboard requests on `pa.scorchthinks.dev`
redirect to the primary hostname, keeping sessions and WebSocket origin
checks consistent with Plausible's single `BASE_URL`.
The databases remain on the stack's private default network. No host ports
are published.

## Deploy with Portainer

Deploy `/pettan/self/pa.compose.yaml` as a Docker Standalone stack named `pa`.
The absolute ClickHouse configuration paths refer to files on Pettan's host.
Portainer already mounts `/pettan/env` at `/etc/.env`.

Before deployment, create `/pettan/env/pa` with mode 600 containing:

```dotenv
SECRET_KEY_BASE=<generate a unique secret with openssl rand -base64 48>
```

Keep this file outside Git and include it in private backups. Optional SMTP
settings can also go there; SMTP is needed for reliable invitations and
password recovery. Registration defaults to invite-only; the first visit
creates the initial account. Use the primary hostname for dashboard login.
The secondary hostname also supports tracker requests directly.

Both DNS names are proxied CNAMEs targeting `forge.joshwel.co`, whose A record
is maintained by Pettan's existing DDNS container. This avoids a separate
static IP or another DDNS configuration entry.

## Manage from the host

The initial deployment was started through Compose. It appears in Portainer
as an external stack until imported there. The host has `/etc/.env` linked
to `/pettan/env`, so the same Compose file works from either environment:

```sh
docker compose -p pa -f /pettan/self/pa.compose.yaml up -d --wait
docker compose -p pa -f /pettan/self/pa.compose.yaml ps
```

After editing Caddy's config, validate it and reload from standard input:

```sh
docker exec -i proxy caddy validate --config - --adapter caddyfile < /pettan/self/Caddyfile
docker exec -i proxy caddy reload --config - --adapter caddyfile < /pettan/self/Caddyfile
```

Reading from standard input also works after Git replaces the host's
Caddyfile inode, before the container is next recreated.

The ClickHouse XML files are copied unchanged from
<https://github.com/plausible/community-edition/tree/v3.2.1/clickhouse>.
They reduce memory usage and log volume for a small instance.

## Backups and upgrades

Back up the secret file, this repository, a PostgreSQL dump, and a consistent
ClickHouse backup. Docker volumes for the `pa` project are `pa_db-data`,
`pa_event-data`, `pa_event-logs`, and `pa_plausible-data`. Do not remove volumes
when redeploying. The app image is pinned; review upstream upgrade notes and
back up both databases before changing versions.
