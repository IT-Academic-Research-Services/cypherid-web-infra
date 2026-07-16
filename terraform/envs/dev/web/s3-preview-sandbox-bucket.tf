# =============================================================================
# Dedicated S3 bucket for per-PR preview sandbox sample uploads (#697/#616).
#
# WHY THIS EXISTS: previews were pointed at `seqtoid-sandbox`, which -- despite the name -- is
# NOT a throwaway. It is a hand-created, un-terraformed bucket holding ~4.8 TB / 55k objects of
# the team's research data (validation-08-18-2025/, time-trials-*, mmseqs-gpu-time-trials-*,
# taxid_indexes/, host_read_survival/, jsims/ ...), and its backup status is unknown. The preview
# IRSA role granted s3:PutObject + s3:DeleteObject across ALL of it, with per-PR prefix isolation
# resting only on the pod's SAMPLES_BUCKET_NAME config value -- so any bug in a sandbox could
# write or delete research data, and sandbox uploads were accumulating in it with nothing to
# clean them up (teardown drops the schema/user/SSM but never S3 objects).
#
# This gives sandboxes their OWN bucket so that isolation is enforced by IAM rather than by a
# config string. `seqtoid-sandbox` is deliberately NOT imported, NOT modified, and NOT touched --
# only the preview role's write/delete grant on it is withdrawn (eks-irsa-preview.tf).
#
# Posture mirrors what the live buckets already do: SSE-S3 + bucket keys, all public access
# blocked, ACLs disabled (BucketOwnerEnforced). No versioning: sandbox uploads are disposable by
# definition, and versioning would defeat the lifecycle expiry below by retaining noncurrent
# copies.
# =============================================================================

variable "preview_samples_expiration_days" {
  description = "Days after which per-PR sandbox uploads are expired by S3. Sandboxes are capped at 7 days by the ttl-reaper, so anything older is orphaned; this is the floor that holds even when every hook fails."
  type        = number
  default     = 14
}

locals {
  # NEW name for a NEW bucket (nothing is being renamed). Account-suffixed because the S3
  # namespace is global, matching the existing idseq-samples-<env>-<account> convention.
  preview_samples_bucket = "seqtoid-preview-samples-${var.env}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "preview_samples" {
  # VERSIONING IS DELIBERATELY OFF, and this is the one skip here that is a design decision rather
  # than scope. Versioning would defeat the entire point of this bucket: noncurrent versions
  # survive the 14-day expiry rule unless a separate noncurrent-expiration is added, so deleted
  # sandbox uploads would linger as versions -- exactly the retention hole this bucket exists to
  # close. Sandbox uploads are disposable test data with a 7-day sandbox lifetime; there is nothing
  # here worth recovering, and "recoverable" is the opposite of what we want for it.
  # checkov:skip=CKV_AWS_21:versioning would retain noncurrent versions past the lifecycle expiry, defeating the retention guarantee this bucket exists to provide
  #
  # SSE-S3 (AES256) + bucket keys, matching dev's samples bucket and seqtoid-sandbox. A CMK would
  # add per-request KMS charges on multi-GB sample uploads and key administration, to protect
  # disposable dev test data that is deleted after 14 days.
  # checkov:skip=CKV_AWS_145:SSE-S3 matches the other samples buckets; a CMK adds cost + key admin for disposable 14-day dev data
  #
  # No access logging: this is dev-only, ephemeral test data with no audit requirement, and a log
  # target would itself need a bucket + lifecycle. Revisit if sandboxes ever hold anything real.
  # checkov:skip=CKV_AWS_18:dev-only ephemeral test data, no audit requirement; revisit if sandboxes ever hold real data
  #
  # No cross-region replication for data that is deliberately deleted after 14 days.
  # checkov:skip=CKV_AWS_144:replicating data that is intentionally expired after 14 days is pointless
  #
  # No event notifications: nothing consumes upload events for sandboxes.
  # checkov:skip=CKV2_AWS_62:no consumer exists for sandbox upload events
  bucket = local.preview_samples_bucket

  # This bucket is disposable, but a `count = 0` or a rename in a future refactor would silently
  # destroy it mid-review. Deleting it must be a deliberate, explicit act.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    env       = var.env
    service   = "seqtoid-web"
    component = "preview-sandbox"
    owner     = "platform"
    # Says out loud what the name implies, so nobody mistakes this one for durable storage the
    # way `seqtoid-sandbox` was mistaken for a throwaway.
    retention = "ephemeral-${var.preview_samples_expiration_days}d"
  }
}

# S3 TRANSFER ACCELERATION -- required, not an optimisation.
#
# The browser upload path hardcodes `useAccelerateEndpoint: true` (seqtoid-web
# RemoteUploadProgressModal.tsx / LocalUploadProgressModal.tsx), so every PUT goes to
# <bucket>.s3-accelerate.amazonaws.com. With acceleration disabled that endpoint rejects the
# request before it ever emits CORS headers, and the browser reports it as:
#
#   Access to fetch at 'https://seqtoid-preview-samples-...s3-accelerate.amazonaws.com/...?x-id=PutObject'
#   ... blocked by CORS policy: Response to preflight request doesn't pass access control check:
#   No 'Access-Control-Allow-Origin' header is present on the requested resource.
#
# That message points at CORS, which is configured correctly and is NOT the problem -- the bucket
# simply does not answer on that hostname. dev's samples bucket has Status=Enabled, which is why
# uploads work there. Mirroring dev's SECURITY posture (encryption/ACLs/public-access) was not
# enough; this is part of its OPERATIONAL posture and the upload path depends on it.
resource "aws_s3_bucket_accelerate_configuration" "preview_samples" {
  bucket = aws_s3_bucket.preview_samples.id
  status = "Enabled"
}

# ACLs disabled. Matches seqtoid-sandbox and dev's samples bucket, and avoids the ACLs-disabled
# landmine that has already bitten an apply in this account.
resource "aws_s3_bucket_ownership_controls" "preview_samples" {
  bucket = aws_s3_bucket.preview_samples.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "preview_samples" {
  bucket                  = aws_s3_bucket.preview_samples.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "preview_samples" {
  bucket = aws_s3_bucket.preview_samples.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# THE RETENTION GUARANTEE. S3 expires these objects itself -- it does not depend on the teardown
# hook, the reaper, Argo, or the cluster being healthy. Teardown is best-effort by nature (its
# PostDelete hook can fail to render on a deleted branch, fail to pull an expired image, or wedge
# behind a finalizer), so uploaded sample data must have a floor that no broken hook can raise.
# Sandboxes are capped at 7 days by the ttl-reaper, so anything older than this is orphaned.
resource "aws_s3_bucket_lifecycle_configuration" "preview_samples" {
  bucket = aws_s3_bucket.preview_samples.id

  rule {
    id     = "expire-sandbox-uploads"
    status = "Enabled"

    filter {}

    expiration {
      days = var.preview_samples_expiration_days
    }

    # Multipart uploads that never completed still cost money and are invisible in the console.
    abort_incomplete_multipart_upload {
      days_after_initiation = 3
    }
  }
}

# CORS: sample upload goes BROWSER -> S3 directly (the app-owned ResumableUpload, seqtoid-web
# #47), so S3 must return CORS headers for the sandbox's origin or the browser blocks the request
# before IAM is ever consulted. Mirrors the upload rule on dev's samples bucket.
#
# ExposeHeaders is load-bearing, not decoration: the multipart path reads ETag per part and
# x-amz-checksum-sha256 to verify them, and a browser cannot see either header unless S3 exposes
# it -- so an upload can pass preflight and still fail on completion without these.
#
# One wildcard origin because PR numbers are unbounded and the list cannot enumerate them (same
# constraint as the Auth0 callback, #22). S3 permits a single `*` in AllowedOrigins;
# https://*.dev.seqtoid.org matches pr-<N>.dev.seqtoid.org and nothing outside that zone. CORS
# grants no access -- it only tells a browser which origins may read a response it already had
# permission to make; every real permission comes from the preview IRSA role.
resource "aws_s3_bucket_cors_configuration" "preview_samples" {
  bucket = aws_s3_bucket.preview_samples.id

  cors_rule {
    allowed_methods = ["POST", "GET", "DELETE", "PUT"]
    allowed_origins = ["https://*.${local.env_fqdn}"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag", "x-amz-checksum-sha256"]
    max_age_seconds = 3600
  }
}

output "preview_samples_bucket" {
  description = "Dedicated bucket for per-PR preview sandbox uploads; set preview.samplesBucket / SANDBOX_SAMPLES_BUCKET to this"
  value       = aws_s3_bucket.preview_samples.id
}
