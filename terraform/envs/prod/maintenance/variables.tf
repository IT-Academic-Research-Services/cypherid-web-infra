variable "notify_email" {
  description = "Email address to receive new signup notifications (must be SES-verified)."
  type        = string
  default     = "seqtoid@ucsf.edu"
}

variable "from_email" {
  description = "SES-verified sender address for notification emails."
  type        = string
  default     = "seqtoid@ucsf.edu"
}

variable "allowed_origins" {
  description = "Comma-separated list of allowed CORS origins."
  type        = string
  default     = "https://seqtoid.org,https://maintenance.seqtoid.org"
}

variable "rate_limit_threshold" {
  description = "Maximum number of requests allowed per IP per 5-minute window before WAF blocks them."
  type        = number
  default     = 20
}
