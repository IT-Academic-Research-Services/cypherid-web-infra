# `_terraform-owned/` — reference only, NOT synced by Argo

These Argo `Application` manifests describe cluster infra addons that are **already
installed and owned by the eks Terraform module** (the SSOT for shared infra). They
live here **for reference / a future full-GitOps migration only**. They are **not**
under any root app's path and must **not** be added to one.

## Why they are not Argo-managed

On `czid-dev-eks-v2` these are live Helm releases:

| Addon | Ownership |
|-------|-----------|
| aws-load-balancer-controller | chart **1.7.1** (app v2.7.1), `kube-system` -- installed by the eks module (IRSA via `terraform/modules/lb-controller-irsa`). NOTE: the install mechanism was not re-verified during 783; if it too was a bare `helm install`, adopt it the same way argo-rollouts was. |
| argo-rollouts | chart **2.41.0**, `argo-rollouts` -- **now a real Terraform `helm_release`** at `terraform/envs/dev/eks-v2/argo-rollouts.tf` (platform-overhaul 783). It was originally a bare `helm install` that NO IaC owned; 783 adopted it (import block) so its values -- including the 782 ping-pong knobs `--aws-verify-target-group` + the IRSA SA annotation -- are managed. The old `argo-rollouts.yaml` reference Application here was removed (it was never applied and became misleading once the helm_release owned the release). |
| cert-manager, external-dns, karpenter, aws-efs-csi-driver, metrics-server | eks module |

If a root app synced these, Argo would contend with Terraform for the same resources
and **selfHeal would fight every `terraform apply`**. Concretely, the LBC Application
here pins chart **1.8.1** — syncing it would upgrade dev's ALB controller out from
under Terraform and risk ingress.

## Ownership boundary (see #493)

- **Terraform = SSOT for infra addons** (this dir).
- **Argo = app layer** (`../apps/<env>/`) + deliberate apps (`../_deliberate/`).

Going full-GitOps (Argo owns addons) is a separate, larger effort: import each Helm
release into Argo, reconcile chart versions/values exactly, and remove the
`helm_release` resources from Terraform state. Do not do it piecemeal.
