# Gauntlet candidate elements

This directory is the **git-directory generator** source for the `seqtoid-web-gauntlet-candidate`
ApplicationSet (`../apps/dev/seqtoid-gauntlet-candidate-appset.yaml`). Each `*.yaml` file here renders
exactly one isolated, staging-shaped candidate env in the **dev** cluster for the staging gauntlet.

**Do not hand-edit these.** `seqtoid-web/bin/gauntlet_env` manages them:

- `gauntlet_env up <envName> <imageTag>` — writes `<envName>.yaml`, commits it → the ApplicationSet
  renders `seqtoid-<envName>`; the script waits until it is Healthy/Synced.
- `gauntlet_env down <envName>` — removes `<envName>.yaml`, commits it → Argo deletes the Application;
  its finalizer + the chart PostDelete hook reap the namespace, DB schema, and SSM path.

A TTL reaper (mirroring `../appsets/seqtoid-preview-ttl-reaper.yaml`) removes orphaned element files
whose gauntlet run died without a `down`, so a crashed CI job can never leak a candidate forever.

## Element file schema (all fields required)

```yaml
envName:        gauntlet-abc12345                 # DNS-safe; drives the Application + namespace name
imageTag:       sha-abc12345                      # the promotable dev seqtoid-web tag being vetted
gitRevision:    abc12345...                        # the commit to render the chart at (matches the image)
host:           gauntlet-abc12345.dev.seqtoid.org  # candidate ingress host
chamberService: idseq-gauntlet-abc12345-web        # this candidate's OWN SSM/chamber path (DB isolation)
dbName:         idseq_gauntlet_abc12345            # this candidate's OWN schema (underscores; valid DB name)
```

Only ever `<env>.dev.seqtoid.org` hosts and dev-account resources — a candidate must never resolve to
`env-staging.seqtoid.org` (the real staging) or `staging.seqtoid.org` (Jay's legacy).
