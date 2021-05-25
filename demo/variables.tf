variable "do_token" {
  type        = string
  description = "The DO API token."
}

variable "region" {
  type    = string
  default = "ams3"
}

variable "ip_range" {
  type    = string
  default = "10.10.10.0/24"
}

variable "ssh_key" {
  type        = string
  description = "Fingerprint of the SSH key. To retrieve this info, use a tool such as curl with the DigitalOcean API, to retrieve them"
}

variable "image" {
  type    = string
  default = ""
}