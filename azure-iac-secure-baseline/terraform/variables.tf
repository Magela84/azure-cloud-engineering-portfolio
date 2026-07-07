variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Short environment tag."
  type        = string
  default     = "lab"
}

variable "name_prefix" {
  description = "Short lowercase prefix (3-8 chars)."
  type        = string
  default     = "azlab01"
}
