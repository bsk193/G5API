# Deploying G5API on Railway

G5API runs as a Docker service on Railway and talks to a **MariaDB** and a
**Redis** service in the same Railway project (over the private network). The
CS2/game server itself stays on your external machine and only needs to reach
this API's public URL.

```
 external CS2 server ──▶  G5API (Railway, this repo)  ──┬──▶ MariaDB (Railway)
        G5V (Railway)  ──▶  G5API                       └──▶ Redis   (Railway)
```

## 1. Create the data services

In your Railway project add two databases (**+ New → Database**):

- **MariaDB** (or MySQL)
- **Redis**

Note the service names you give them — they're used in the reference variables
below (this guide assumes `MariaDB` and `Redis`).

## 2. Create the G5API service

**+ New → GitHub Repo** → pick this repo. Railway auto-detects `railway.json`
and builds from the `Dockerfile`. No start command needed — the image already
runs migrations and launches the app with `pm2-runtime`.

## 3. Set the variables

In the G5API service **Variables** tab, paste from [`.env.example`](./.env.example).
The values that reference the data services use Railway's reference syntax:

| Variable        | Value                                   |
| --------------- | --------------------------------------- |
| `SQLUSER`       | `${{MariaDB.MYSQLUSER}}`                 |
| `SQLPASSWORD`   | `${{MariaDB.MYSQLPASSWORD}}`             |
| `SQLHOST`       | `${{MariaDB.MYSQLHOST}}`                 |
| `SQLPORT`       | `${{MariaDB.MYSQLPORT}}`                 |
| `DATABASE`      | `${{MariaDB.MYSQLDATABASE}}`             |
| `REDISURL`      | `${{Redis.REDIS_URL}}`                   |

Set the rest manually:

- `NODE_ENV=production`
- `HOSTNAME` / `APIURL` → this service's public URL (see step 4), no `/api` suffix.
- `CLIENTHOME` → the G5V public URL.
- `DBKEY` → exactly 32 chars (`openssl rand -hex 16`).
- `SHAREDSECRET` → long random string (`openssl rand -hex 32`).
- `STEAMAPIKEY` → your Steam Web API key.
- `USEREDIS=true`, `REDISTTL=86400`, `QUEUETTL=3600`, `SERVERPINGTO=5000`.
- `UPLOADDEMOS=true`, `LOCALLOGINS=false`, `SERVERPROVIDER=local`.
- `ADMINS` / `SUPERADMINS` → comma-separated Steam IDs.

> **Do not set `PORT`.** Railway provides it at runtime and the config reads it.
> `USEREDIS`, `REDISTTL`, `QUEUETTL`, `SERVERPINGTO` are written into JSON
> unquoted, so they must stay numeric/boolean (no quotes, no empty values).

## 4. Generate the public domain

Service **Settings → Networking → Generate Domain**. Put that URL into
`HOSTNAME` and `APIURL`, then redeploy so the values take effect.

## 5. Persisting demos (optional)

`UPLOADDEMOS=true` writes demo/backup files under `public/`, which is ephemeral
on Railway. To keep them across deploys, attach a **Volume** mounted at
`/Get5API/public`.

## Notes / gotchas

- **Migrations run on every boot.** `db:create` is allowed to fail (Railway
  pre-creates the database and the app user usually can't `CREATE DATABASE`);
  `migrate-prod-upgrade` then builds/updates the tables in the existing DB.
- **Cross-domain login.** Because G5API and G5V sit on different Railway
  domains, the app now sets `trust proxy` and issues the session cookie as
  `SameSite=None; Secure` in production (see `app.ts`). Steam login won't keep a
  session without this. `CLIENTHOME` must exactly match the G5V origin for CORS.
- Private networking between Railway services is enabled automatically; the
  `MYSQLHOST` / `REDIS_URL` references resolve to the internal addresses.
