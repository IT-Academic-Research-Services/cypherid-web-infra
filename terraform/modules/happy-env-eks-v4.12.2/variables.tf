
variable "tags" {
  description = "Standard tags. Typically generated by fogg"
  type = object({
    env : string,
    owner : string,
    project : string,
    service : string,
    managedBy : string,
  })
}

# variable "base_zone_id" {
#   description = "The base zone all happy stacks and infrastructure will build on top of"
#   type        = string
# }

variable "ecr_repos" {
  description = "Map of ECR repositories to create. These should map exactly to the service names of your docker-compose"
  type = map(object({
    name           = string,
    read_arns      = optional(list(string), []),
    write_arns     = optional(list(string), []),
    tag_mutability = optional(bool, true),
    scan_on_push   = optional(bool, false),
  }))
  default = {}
}

variable "rds_dbs" {
  description = "Map of DB's to create for your happy applications. If an engine_version is not provided, the default_db_engine_version is used"
  type = map(object({
    engine_version : string,
    instance_class : string,
    username : string,
    name : string,
    rds_cluster_parameters : optional(list(
      map(any)), []
    ),
  }))
  default = {}
}

variable "s3_buckets" {
  description = "Map of S3 buckets to create for your happy applications"
  type = map(object(
    {
      name   = string
      policy = optional(string, "")
  }))
  default = {}
}

variable "additional_secrets" {
  description = "Any extra secret key/value pairs to make available to services"
  type        = any
  default     = {}
}

variable "default_db_engine_version" {
  description = "The default Aurora Postgres engine version if one is not specified in rds_dbs"
  type        = string
  default     = "14.3"
}

variable "cloud-env" {
  type = object({
    public_subnets        = list(string)
    private_subnets       = list(string)
    database_subnets      = list(string)
    database_subnet_group = string
    vpc_id                = string
    vpc_cidr_block        = string
  })
}

variable "eks-cluster" {
  type = object({
    cluster_id : string,
    cluster_arn : string,
    cluster_endpoint : string,
    cluster_ca : string,
    cluster_oidc_issuer_url : string,
    cluster_version : string,
    worker_iam_role_name : string,
    worker_security_group : string,
    oidc_provider_arn : string,
  })
  description = "eks-cluster module output"
}

variable "github_actions_roles" {
  description = "Roles to be used by Github Actions to perform Happy CI."
  type = set(object({
    name = string
    arn  = string
  }))
  default = []
}

variable "ops_genie_owner_team" {
  description = "The name of the Opsgenie team that will own the alerts for this happy environment"
  type        = string
  default     = "Core Infra Eng"
}

# deprecated, use OIDC config instead to specify okta teams
variable "okta_teams" {
  type        = set(string)
  description = "The set of Okta teams to give access to the Okta app"
  default     = null
}

variable "hapi_base_url" {
  type        = string
  description = "The base URL for HAPI"
  default     = "https://hapi.hapi.prod.si.czi.technology"
}

variable "waf_arn" {
  type        = string
  description = "A regional WAF ARN to attach to the happy ingress."
  default     = null
}

variable "oidc_config" {
  type = object({
    login_uri                  = optional(string, ""),
    grant_types                = optional(set(string), ["authorization_code", "refresh_token"])
    redirect_uris              = optional(set(string), []),
    teams                      = optional(set(string), []),
    app_type                   = optional(string, "web"),
    token_endpoint_auth_method = optional(string, "client_secret_basic"),
  })
  default     = {}
  description = "OIDC configuration for the happy stacks in this environment."
}
