terraform {
  required_version = ">= 1.6.0"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "staging"
}

locals {
  common_tags = {
    service = "quicklook-demo"
    owner   = "platform"
  }
}

resource "random_pet" "service" {
  length    = 2
  separator = "-"
}

output "service_name" {
  value = "${var.environment}-${random_pet.service.id}"
}
