output "cloud0_droplet_id" {
  value = "${digitalocean_droplet.cloud.0.id}"
}

output "cloud0_droplet_region" {
  value = "${digitalocean_droplet.cloud.0.region}"
}

output "cloud0_public_ipv4" {
  value = "${digitalocean_droplet.cloud.0.ipv4_address}"
}

output "cloud0_private_ipv4" {
  value = "${digitalocean_droplet.cloud.0.ipv4_address_private}"
}

output "cloud0_public_ipv6" {
  value = "${digitalocean_droplet.cloud.0.ipv6_address}"
}
