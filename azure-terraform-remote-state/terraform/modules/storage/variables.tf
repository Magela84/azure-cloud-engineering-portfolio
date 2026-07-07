variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "replication_type" {
  type    = string
  default = "LRS"
  validation {
    condition     = contains(["LRS", "GRS", "ZRS"], var.replication_type)
    error_message = "replication_type must be LRS, GRS, or ZRS."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
