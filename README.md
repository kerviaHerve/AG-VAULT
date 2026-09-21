# AG-VAULT

Ultra-fast multi-agent secrets vault. **One Go binary**: REST API + MCP server + embedded WebUI.

- SQLite embedded (pure Go, no CGO), AES-256-GCM at rest
- Per-agent API keys (Argon2id), per-vault grants, immutable versioning, append-only audit
- 51 credential templates (OpenAI, PostgreSQL, SMTP, Cloudflare, GitHub…)
- Security by design — AGPL-3.0

## Quick start

```bash
# generate the master key
openssl rand -hex 32

# generate the admin password hash
docker build -t ag-vault .
docker run --rm ag-vault hashpw 'your-admin-password'

# configure
cat > .env <<EOF
AGENTVAULT_MASTER_KEY=<hex from step 1>
AGENTVAULT_ADMIN_HASH=<hash from step 2>
EOF

# run
docker compose up -d
# webui: http://localhost:8321/ui/ (login with the admin password)
```

## Configuration (environment)

| Variable | Required | Default | Description |
|---|---|---|---|
| `AGENTVAULT_MASTER_KEY` | ✅ | — | 64 hex chars (32 bytes). Server refuses to boot without it. |
| `AGENTVAULT_ADMIN_HASH` | ✅ | — | bcrypt hash of the webui admin password (`agentvault hashpw`). |
| `AGENTVAULT_LISTEN` | | `127.0.0.1:8321` | listen address. |
| `AGENTVAULT_DB` | | `/var/lib/agentvault/agentvault.db` | SQLite path. |
| `AGENTVAULT_RATE_PER_MIN` | | `60` | requests/minute per API key. |

## REST API

Auth: `Authorization: Bearer av_<key>` — key is scoped to the granted vaults.

| Method | Path | Description |
|---|---|---|
| GET | `/v1/whoami` | identity + accessible vaults |
| GET | `/v1/vaults` | vaults |
| GET | `/v1/secrets?vault=<name>` | metadata (no values) |
| GET | `/v1/secrets/{id}` | decrypted value |
| POST | `/v1/secrets` | create — `{vault,key,value}` or `{vault,key,template,values}` |
| PATCH | `/v1/secrets/{id}` | update (new version) |
| DELETE | `/v1/secrets/{id}` | delete |
| GET | `/v1/templates` | all credential templates |
| GET | `/v1/templates/{key}` | one template |

Admin (`/admin/*`, session cookie from `POST /admin/login`): agents (create →
key shown once), vaults, grants, secrets, versions, audit.

## MCP (validated E2E — stdio + HTTP)

Two transports, the same agent-scoped key:

**stdio (OpenCode):**
```bash
opencode mcp add ag-vault --global \
  --env AGENTVAULT_API_KEY=av_... \
  --env AGENTVAULT_MASTER_KEY=<64 hex> \
  --env AGENTVAULT_ADMIN_HASH=<bcrypt> \
  --env AGENTVAULT_DB=/opt/agentvault/data/agentvault.db \
  -- /opt/agentvault/bin/agentvault --mcp-stdio
```

**HTTP (Hermes — any machine on the mesh, no binary needed):**
```yaml
mcp_servers:
  ag-vault:
    url: https://s-agvault.kervia.ch/mcp
    headers:
      Authorization: "Bearer av_..."
```

Tools: `list_vaults` · `list_secrets` · `get_secret` · `create_secret` ·
`update_secret` · `delete_secret` · `list_templates` · `whoami`.

Scoping enforced per tool (defense in depth): grants re-verified on
every operation; templated creates validated; templated reads return
structured `values` objects. Skill for agents: `docs/skills/ag-vault/`.
Agent distribution kit: `agvault-agent-kit.zip` (binary + skill + guide).

## Security model

| Threat | Mitigation |
|---|---|
| Key theft | 256-bit CSPRNG keys, Argon2id (m=64MB) stored hashed, constant-time verify, revocation |
| Tampering | AES-256-GCM tags, immutable versioning |
| Insider/eavesdropping | append-only audit log, secrets never in lists/logs, values revealed only on explicit action |
| Brute force | per-key rate limiting, failed logins audited |
| Escalation | grants re-verified in every handler (defense in depth), deny by default |

Threat model: no client-side E2E (self-hosted trust), TLS terminated by the
reverse proxy, encryption at rest protects DB file exfiltration.

## Development

```bash
go test -race ./...
gosec ./...
govulncheck ./...
```

Layout: `cmd/agentvault` · `internal/{crypto,store,auth,api,mcp,templates,web,model,config}` ·
`migrations` · `web` (embedded).

## License

AGPL-3.0 — see [LICENSE](LICENSE).