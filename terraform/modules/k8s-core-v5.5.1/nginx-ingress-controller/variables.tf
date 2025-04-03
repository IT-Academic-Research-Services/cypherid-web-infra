variable "namespace" {
  type        = string
  description = "The namespace to deploy the nginx ingress controller into"
}


variable "nginx_version" {
  type        = string
  description = "The version of the nginx ingress controller to deploy"
}
  