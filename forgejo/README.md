# Forgejo analytics

The custom header adds pageviews, outbound-link clicks and file-download
clicks from logged-out browsing to the shared `joshwel.co` Plausible site.
Filter by **Hostname = forge.joshwel.co** to inspect only the forge; use
**Hostname = joshwel.co** for the homepage alone. The dashboard site ID does
not replace each event's actual hostname.

Signed-in pages are excluded by the server-rendered `.IsSigned` condition.
Direct Git, API and binary-download requests do not render HTML or run the
browser script. Download events describe clicks on supported file links,
not confirmed completed downloads.

## Apply

Forgejo's custom path is `/data/gitea` inside the container, backed by
`/mnt/md0/forge/data/gitea` on Pettan. Preserve all other existing templates.
After updating this repository on Pettan:

```sh
docker cp /pettan/self/forgejo/templates/custom/header.tmpl forgejo:/data/gitea/templates/custom/header.tmpl
docker exec forgejo chmod 644 /data/gitea/templates/custom/header.tmpl
docker restart forgejo
```

The file lives in persistent host storage and survives container recreation.
Reapply it after changing this tracked source file. Check the custom template
against the deployed Forgejo version before upgrading. For rollback, remove
only `templates/custom/header.tmpl` from the custom path and restart Forgejo.
