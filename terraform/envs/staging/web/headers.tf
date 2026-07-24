# CZID-355 / CZID-365 (SSOT) - instantiate the shared CloudFront security-headers module instead of
# defining the policy inline per env. dev/staging/maintenance/zendesk reuse the SAME module (one
# definition, no per-env copies). The policy is created here for parity with prod and is consumed by
# the static-asset components in STATIC-002b; it is not yet attached to this env's web distribution.
module "security_headers" {
  source = "../../../modules/cloudfront-security-headers"
  env    = var.env
}
