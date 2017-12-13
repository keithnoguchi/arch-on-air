variable "DO_API_TOKEN" {}
variable "DO_FINGERPRINT" {}

variable "DO_CLOUD_USER_DATA" {
  description = "cloud-init user data for the droplet"
  default     = <<EOF
#!/bin/bash
apt update && apt install -y python nmap iperf3
EOF
}

variable "cloud_count" {
  description = "The number of guest droplets"
  default     = 1
}

variable "DO_REGION" {
  description = "The slug of the DO region, e.g. nyc3"
  default     = "nyc3"
}
