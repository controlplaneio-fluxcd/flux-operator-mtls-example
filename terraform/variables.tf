variable "cluster_name" {
  description = "Kind cluster name."
  type        = string
  default     = "flux-mtls"
}

variable "git_ref" {
  description = "Git ref Flux syncs from, e.g. refs/heads/main or refs/pull/1/merge."
  type        = string
  default     = "refs/heads/main"
}

variable "receiver_token" {
  description = "Token for the notification-controller webhook Receiver."
  type        = string
  sensitive   = true
}

variable "revision" {
  description = "Bump to re-run the bootstrap Job without changing its inputs."
  type        = number
  default     = 1
}

variable "debug_on_failure" {
  description = "Relay the bootstrap Job logs on failure. Needs kubectl with the kind cluster as the current context."
  type        = bool
  default     = false
}
