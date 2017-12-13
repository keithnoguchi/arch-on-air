# https://www.terraform.io/docs/providers/do/index.html
provider "digitalocean" {
  token = "${var.DO_API_TOKEN}"
}

# https://www.terraform.io/docs/providers/do/r/droplet.html
resource "digitalocean_droplet" "cloud" {
  count              = "${var.cloud_count}"
  image              = "ubuntu-16-04-x64"
  name               = "cloud${count.index}"
  region             = "${var.DO_REGION}"
  size               = "512mb"
  resize_disk        = false
  ipv6               = true
  private_networking = true
  ssh_keys           = ["${var.DO_FINGERPRINT}"]
  user_data          = "${var.DO_CLOUD_USER_DATA}"
}
