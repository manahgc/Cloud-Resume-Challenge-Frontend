variable "aws_region" {
    description = "Aws Region"
    type = string
}

variable "bucket_name" {
    description = "Name of Website Bucket"
    type = string  
}

variable "access_log_bucket_name" {
    description = "Name of access_log bucket"
    type = string
  
}

variable "domain_name" {
    description = "Registered domain name"
    type = string
}

variable "s3_origin_id" {
    description = "s3 website endpoint"
    type = string
  
}

variable "hosted_zone_id" {
    type = string
    description = "hosted zone id"
  
}

variable "access_log_bucket_domain_name" {
    type = string
    description = "Access log bucket domain name"
}