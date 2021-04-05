variable "cf_username" {
  type        = string
  description = "Cloud foundry username"
}

variable "cf_password" {
  type        = string
  description = "Cloud foundry password"
}

variable "cf_api" {
  default     = "https://api.eu1.phsdp.com"
  type        = string
  description = "Cloud foundry API endpoint (region specific)"
}

variable "cf_org" {
  type        = string
  description = "Cloud foundry ORG name"
}

variable "cf_space" {
  type        = string
  description = "Cloud foundry space to provision Kafdrop in"
}

variable "cf_region" {
  type        = string
  default     = "eu-west"
  description = "Cloud foundry region"
}

variable "cf_domain" {
  type        = string
  default     = "eu-west.philips-healthsuite.com"
  description = "Default Cloud foundry domain to use for apps"
}

variable "name_postfix" {
  type        = string
  default     = ""
  description = "Optional postfix to append in routes"
}

variable "workers_size" {
  type        = number
  default     = 3
  description = "The number of workers for the spark server"
}

variable "spark_docker_image" {
  type        = string
  default     = "skprasad/spark:v0.0.1"
  description = "Spark image to be used"
}

variable "docker_username" {
  type        = string
  description = "docker registry username"
  default     = ""
}

variable "docker_password" {
  type        = string
  description = "Docker registry password"
  default     = ""
}
