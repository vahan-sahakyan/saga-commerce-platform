variable "cluster_name" {
  description = "name of the k3d cluster"
  type        = string
  default     = "saga-platform"
}

variable "argocd_version" {
  description = "ArgoCD helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "redpanda_replicas" {
  description = "number of Redpanda replicas"
  type        = number
  default     = 1
}
