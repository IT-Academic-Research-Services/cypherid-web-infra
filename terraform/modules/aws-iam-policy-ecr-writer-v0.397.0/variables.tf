variable "role_name" {
  type    = string
  default = null
}

variable "ecr_repository_arns" {
  type = list(string)
}

variable "policy_path" {
  type    = string
  default = "/"
}

variable "policy_name" {
  type    = string
  default = ""
}

variable "project" {
  type = string
}

variable "env" {
  type = string
}

variable "service" {
  type = string
}

variable "owner" {
  type = string
}

variable "user_name" {
  type    = string
  default = null
}
