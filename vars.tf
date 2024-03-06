variable "AWS_REGION" {
    type = string
    default = "eu-west-3"
}

variable "AWS_AMIS" {
    type = map
    default = {
        "eu-west-3" = "ami-03f12ae727bb56d85"
  }
}

variable "PUBLIC_SUBNET_CIDRS" {
    type = list(string)
    description = "Public Subnet CIDR values"
    default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "PRIVATE_SUBNET_CIDRS" {
    type = list(string)
    description = "Private Subnet CIDR values"
    default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "AWS_AZS" {
    type = list(string)
    description = "Availability Zones"
    default = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
}