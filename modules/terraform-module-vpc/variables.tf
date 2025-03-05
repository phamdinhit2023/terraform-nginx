variable "prefix" {
  type    = string
  default = ""
}

variable "separator" {
  type    = string
  default = "-"
}

variable "name" {
  type = string
}

variable "vpc_cidr_block" {
}

variable "first_private_subnet_cidr" {
}

# variable "second_private_subnet_cidr" {
# }

variable "first_public_subnet_cidr" {
}

# variable "second_public_subnet_cidr" {
# }
variable "https_port" {
  default = "443"
}
variable "http_port" {
  default = "80"
}
variable "ssh_port" {
  default = "22"
}