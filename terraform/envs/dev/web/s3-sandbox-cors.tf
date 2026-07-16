# CORS for the per-PR preview sandbox samples bucket (#697/#616).
#
# WHY: sample upload goes BROWSER -> S3 directly (the app-owned ResumableUpload, seqtoid-web #47),
# so S3 must return CORS headers for the sandbox's origin or the browser blocks the request before
# IAM is ever consulted. `seqtoid-sandbox` had NO CORS configuration at all
# (NoSuchCORSConfiguration) -- the bucket was created for the sandbox work and never got the CORS
# its dev counterpart has -- so EVERY upload from a sandbox failed with "All uploads failed",
# regardless of the (correct) s3:PutObject grant on the preview role. Caught by running a real
# upload in pr-23 on 2026-07-16.
#
# Mirrors the upload rule on dev's samples bucket (idseq-samples-dev-491013321714):
#   methods [POST,GET,DELETE,PUT], headers [*], expose [ETag, x-amz-checksum-sha256]
# ExposeHeaders is load-bearing, not decoration: the multipart/resumable path reads ETag per part
# and x-amz-checksum-sha256 to verify them, and a browser cannot see either header unless S3
# exposes it -- so an upload can pass preflight and still fail on completion without these.
#
# ORIGIN: one wildcard entry, because PR numbers are unbounded and the allowlist cannot enumerate
# them (same constraint as the Auth0 callback, cypherid-web-infra #22). S3 permits a single `*` in
# AllowedOrigins; `https://*.dev.seqtoid.org` matches pr-<N>.dev.seqtoid.org and nothing outside
# that zone.
#
# DEV ONLY, and narrower than it looks: this grants no access -- CORS only tells a browser which
# origins may READ a response it already had permission to make. Every actual permission still
# comes from the preview IRSA role, which is scoped to seqtoid-sandbox/* and can never touch dev's
# samples bucket. Do NOT copy a wildcard origin onto a bucket holding real data.
#
# NOTE: the `seqtoid-sandbox` bucket itself is NOT terraform-managed (nothing declares it; it has
# no tags). This resource deliberately manages ONLY the CORS config of an existing bucket rather
# than adopting it -- importing an unmanaged, hand-created bucket is a separate change that should
# not ride along with an upload fix. Tracked separately.
resource "aws_s3_bucket_cors_configuration" "seqtoid_sandbox" {
  bucket = "seqtoid-sandbox"

  cors_rule {
    allowed_methods = ["POST", "GET", "DELETE", "PUT"]
    allowed_origins = ["https://*.${local.env_fqdn}"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag", "x-amz-checksum-sha256"]
    max_age_seconds = 3600
  }
}
