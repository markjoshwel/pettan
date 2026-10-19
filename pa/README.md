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

The live stack is managed by Portainer as stack ID `115` on environment `2`:
<http://100.84.210.91:9000/#!/2/docker/stacks/pa?id=115&type=2&regular=true&orphaned=false&orphanedRunning=false>.
Its Git source is `https://github.com/markjoshwel/pettan.git`, reference
`refs/heads/main`, Compose path `pa.compose.yaml`. Use Portainer's Git
redeploy action after updating the repository. Automatic updates are not
enabled. Management is restricted to administrators.

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

Portainer adopted the initial Compose deployment without replacing the
containers or volumes. Prefer Portainer for redeployment. The host has
`/etc/.env` linked to `/pettan/env`, so the same Compose file also works for
diagnostics or recovery from the host:

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
