variable "LOCATION_IQ_API_KEY" {
  type      = string
  sensitive = true
}

variable "MAPTILER_API_KEY" {
  type      = string
  sensitive = true
}

variable "MAP_STYLE_ID" {
  type    = string
  default = "base-v4"
}

# plan-on-PR smoke test (transient; safe to revert)