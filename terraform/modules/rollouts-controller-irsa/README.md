# rollouts-controller-irsa

Shared SSOT module for the **Argo Rollouts controller** IRSA role (platform-overhaul
782). One definition; every EKS env instantiates it with its own cluster name + OIDC
provider.

## Why

Zero-downtime cutovers on an AWS ALB require the ping-pong (canary + weighted target
group) rollout strategy plus the controller flag `--aws-verify-target-group`. That flag
makes the Argo Rollouts controller call the read-only `elbv2 Describe*` APIs to confirm
the new color's target group is healthy **before** the old color is scaled down. The
controller needs AWS credentials to do that -- this role, assumed via IRSA by the
`argo-rollouts:argo-rollouts` service account, provides them.

Without this role the verification step fails (no creds) and the controller cannot
guarantee the new target group is healthy before scale-down.

## Scope

Read-only by design: `DescribeTargetGroups`, `DescribeTargetHealth`,
`DescribeLoadBalancers`, `DescribeListeners`, `DescribeRules`, `DescribeTags`. All
mutating ALB/target-group actions remain with the AWS Load Balancer Controller and its
own IRSA role (`../lb-controller-irsa`).

The permission set is vendored in-tree as `iam-policy.json` (no registry module, no
network at init, one source of truth), matching the `lb-controller-irsa` convention.

## Bootstrap

After apply, take `role_arn` and set it on the argo-rollouts Argo CD Application's
`controller.serviceAccount.annotations."eks.amazonaws.com/role-arn"` (and add
`--aws-verify-target-group` to `controller.extraArgs`). The role name is deterministic
(`<cluster_name>-argo-rollouts`) so the annotation can also be pre-filled.

## Usage

```hcl
module "rollouts_controller_irsa" {
  source = "../../../modules/rollouts-controller-irsa"

  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks-cluster.oidc_provider_arn
  oidc_issuer_url   = module.eks-cluster.cluster_oidc_issuer_url
  tags              = local.tags
}
```
