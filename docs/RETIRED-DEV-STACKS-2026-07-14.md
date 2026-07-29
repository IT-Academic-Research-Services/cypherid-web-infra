# Retired dev stacks (2026-07-14) -- the pre-EKS-v2 world

`terraform/envs/dev/{eks,k8s-core,happy,otel}` were REMOVED. Why, and what to know:

## eks (v1)
The `czid-dev-eks` cluster **no longer exists**:

    $ aws eks list-clusters --region us-west-2
    { "clusters": [ "czid-dev-eks-v2" ] }
    $ aws eks describe-cluster --name czid-dev-eks
    ResourceNotFoundException: No cluster found for name: czid-dev-eks

It was deleted during the EKS-v2 migration, but the terraform was never removed. Because
terraform apply had never actually run (apply_all had zero successful runs before 2026-07-13),
nothing surfaced the drift. Its state still tracked helm/k8s resources on a cluster that was
gone, which is why every `eks` apply failed on the aws-auth ConfigMap.

## k8s-core + happy
Both read `remote_state.eks` (the dead v1 cluster) for their kubernetes provider, so both failed
to PLAN. Neither could have been doing anything -- they pointed at a cluster that did not exist.
- `happy` = CZI's Happy deployment platform. Argo CD owns deployments now; superseded.
- `k8s-core` = nodelocaldns + a gp3 encrypted storage class + priority classes. czid-dev-eks-v2
  has run without them for weeks. Deliberately NOT repointed at v2: installing them on the live
  cluster should be a reviewed improvement, not a side-effect of cleanup. Tracked separately.

## otel
The OTel collector is an ECS service, and dev's ECS cluster was torn down at the EKS migration,
so it fails with ClusterNotFoundException. It needs an EKS migration; tracked separately.

## Left behind (deliberately, tracked)
Deleting these stacks does NOT delete their orphaned AWS resources. The v1 cluster's leftovers --
IAM roles/policies, karpenter SQS queues, KMS keys, security groups -- still exist, and their
terraform state remains in S3. Cleaning them up needs `terraform state rm` (for the vanished
k8s/helm resources) followed by a targeted destroy. Not required for correctness; tracked.

staging / prod / sandbox keep their own eks, k8s-core and happy stacks. Untouched.
