# CopeRO machine-specific settings and Git updates

Source branch: `codex/rathena-update-20261031`.
The configured origin is `https://github.com/BlackMoreCode/rathena.git`.
Confirm the intended CopeRO remote before using it for production updates.
The official upstream remote is for incoming rAthena changes, not CopeRO deployment.

## What Git updates

Track server source, YAML databases including `db/import`, NPC scripts, packet
version, and `db/import/map_cache.dat`. Do not ignore the whole `conf` folder:
upstream adds and updates configuration documentation/defaults there.

`conf/import` is already ignored and loaded after the main configuration files.
Keep machine-specific network settings, SQL credentials and private credentials
in the appropriate import files. Existing inter-server and SQL settings may also
exist in tracked legacy configs; the new network helper does not migrate them or
certify this repository as free of secrets. Review before publishing a new remote.
Never commit private configuration or a database dump to make deployment easier.

## Configure each machine once

Run PowerShell from this repository:

```powershell
.\tools\Set-CopeNetwork.ps1 -Profile Local
# On the production server only:
.\tools\Set-CopeNetwork.ps1 -Profile Production -PublicAddress 213.243.188.36
# If another service uses 8889, first verify a free API port and specify it:
.\tools\Set-CopeNetwork.ps1 -Profile Production -PublicAddress 213.243.188.36 -WebPort 8890
```

The helper writes ignored `conf/import/cope-network/{login,char,map,web}.conf`
and adds their includes LAST in the respective ignored import files. Existing
non-network settings remain. It does not change SQL credentials or firewall/router
settings and does not restart anything. Re-running replaces only its generated
network values. Back up existing imports before adopting it on another machine.

Production: bind 0.0.0.0; advertise the supplied address for char/map; keep the
login-to-char-to-map internal connection on 127.0.0.1. Standard game ports
6900/6121/5121 and web API 8889 unless -WebPort overrides it. Production nginx
was subsequently confirmed to occupy 8889; use a separately verified free port
for rAthena (8890 is the candidate), and update the client GameWebUrl and router
forwarding together. Do not stop the existing nginx to free its port.
Configure the real server LAN target in the router.
The latest deployment plan uses the existing nginx port 12000 and `/api/`:
run the API on a verified-free `127.0.0.1:8893` with
`-WebPort 8893 -WebBindAddress 127.0.0.1`, and proxy `/api/` to it.
The production client GameWebUrl is then `http://213.243.188.36:12000/api/`.
Neither 8889 nor 8890 is free on production; both are occupied by nginx.
Do not forward 8893 publicly when using this loopback backend.
An existing DB audit/backup/migration remains required before first startup.

## Subsequent updates

Stop the game servers and back up the production database and machine config.
Check the incoming commit range for SQL migrations and configuration changes.
With a clean worktree on the intended branch:

```powershell
git pull --ff-only origin codex/rathena-update-20261031
```

If this fails because of local changes or branch divergence, inspect and merge
deliberately. Do not use reset --hard or git clean to hide the problem. The ignored
machine import files stay in place across ordinary pulls. Tracked source config
defaults can still change; the final import overrides are what preserve the IP.

Build `rAthena.sln`, Release x64, using Visual Studio 2022/MSBuild. Runtime EXEs
are Git-ignored; `git pull` alone does not update them. Either build on the server
or separately deliver binaries built from the same commit. A fresh clone may also
need the matching x64 runtime DLLs (libmysql/pcre8/zlib), private DB configs and
Windows C++ runtime. SQL state is separate from Git and is never migrated by pull.

Start visible consoles with the tracked helper:

```powershell
.\tools\Start-CopeServer.ps1
Get-NetTCPConnection -State Listen | Where-Object LocalPort -In 6900,6121,5121,8889
```

The existing `runserver.bat` is ignored and therefore not supplied by a fresh clone.
The new Start helper skips already-running EXEs at this exact path; it does not stop
processes and does not replace a proper shutdown/backup before an update.

Launcher source, client GRFs, Warpgate, SQL data and the separate RoDocu folder are
outside this server Git repository. This workflow does not distribute them. Client
updates use the separate hash-manifest patch service.
