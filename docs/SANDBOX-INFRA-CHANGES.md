# Getting infra changes into a preview sandbox

For contributors who need more than code in their per-PR preview sandbox --
extra S3 access, a new Parameter Store value, a permission the app doesn't have
by default.

## First, the one thing that surprises everyone

**The preview sandbox IAM role is SHARED across every `seqtoid-pr-*` sandbox.**
There is no per-PR role. One IRSA role, `seqtoid-web-preview`
(`terraform/envs/dev/web/eks-irsa-preview.tf`), is assumed by the `seqtoid-web`
service account in *every* preview namespace, matched by a `StringLike` on
`seqtoid-pr-*`.

So "add a permission to my sandbox" is really "add a permission to the role every
sandbox shares." That is fine -- it is how the sandboxes work -- but it means:

- The change is a **Terraform change**, reviewed and applied like any other, not a
  self-serve toggle.
- It affects **all** current and future sandboxes, so keep grants tight and
  scoped to specific bucket/prefix ARNs, never `*`.

The role is deliberately **tighter** than the dev app role (platform-overhaul
#618/#619): S3 writes are scoped to the `seqtoid-sandbox` bucket, and it cannot
touch the dev samples buckets. That fail-closed boundary is a feature -- a bug in a
sandbox must not be able to write real data. Widen it only with intent.

## Adding S3 permissions

1. Edit the role's inline policy in
   `terraform/envs/dev/web/eks-irsa-preview.tf`. Add the specific
   `arn:aws:s3:::<bucket>` and `arn:aws:s3:::<bucket>/<prefix>/*` ARNs and the
   exact actions you need (e.g. `s3:GetObject`, `s3:PutObject`). Do not broaden to
   whole buckets or `*` -- the reviewer will bounce it.
2. Open a PR into `integration` like any other change.
3. After merge, an admin applies it via the **reviewer-gated targeted-apply**
   workflow (`.github/workflows/targeted-apply.yml`):
   - `environment`: `dev`
   - `component`: `web`
   - `targets`: the resource address(es), e.g.
     `aws_iam_role_policy.seqtoid_web_preview_s3` (whatever your edit touches)
   - `reason`: a one-line audit note
   IAM changes need admin credentials (CI is blocked from self-modifying IAM by
   `DenyCIIdentitySelfModification`), so ping the infra owner to run the apply --
   you cannot run it yourself. Confirm the plan is **adds/changes only, no
   destroys** before it is approved.
4. Re-provision or restart your sandbox pods so they pick up the widened role
   (the role is assumed at pod start).

## Adding Parameter Store values (API keys, config)

A sandbox reads its config from SSM under `/idseq-sandbox-pr-<N>-web/*`. That path
is **seeded at provision time** by `rake sandbox:provision`, which copies the
source chamber service (`idseq-dev-web`) into the sandbox path. So there are two
ways in, depending on scope:

- **Shared config (every sandbox should have it):** add it to the source service
  with `chamber write idseq-dev-web <KEY> <value>`. It propagates into each
  sandbox the next time that sandbox is provisioned. Use this for anything that is
  really shared dev config.
- **Just your sandbox (a one-off key):** write it directly to your sandbox path,
  `chamber write idseq-sandbox-pr-<N>-web <KEY> <value>`, or the equivalent
  `aws ssm put-parameter --name /idseq-sandbox-pr-<N>-web/<KEY> --type SecureString`.

**Secrets never go in the repo or a PR.** API keys, tokens, and credentials are
put in by hand through chamber/SSM by someone with access. Do not paste them into
`.tf`, values files, or a PR description. If you do not have chamber access to
write them, hand the key names + values to the infra owner to set.

The preview role can already **read** `/idseq-sandbox-pr-*-web/*` and decrypt with
the sandbox KMS key, so once the value is in the path, the app sees it via
`chamber exec` on the next pod start -- no IAM change needed for reads within that
path.

## Lifecycle reminder

- A sandbox is created when the PR is labelled `preview`
  (`seqtoid-pr-<N>`, served at `pr-<N>.dev.seqtoid.org`), with its own DB schema,
  SSM path, and S3 prefix.
- Teardown on PR close drops the schema + user and **deletes the sandbox SSM
  path**. Anything you wrote directly to `/idseq-sandbox-pr-<N>-web/` goes with it
  -- which is correct for a throwaway env, but means a directly-written key does
  not survive a teardown/re-provision. Shared keys (in `idseq-dev-web`) do survive,
  because they are re-seeded each provision.

## Who to ask

- **S3 / IAM widening:** infra owner runs the targeted apply (admin-gated).
- **SSM writes you cannot do:** infra owner, with the key names + values handed
  over securely -- never in a ticket or PR.
