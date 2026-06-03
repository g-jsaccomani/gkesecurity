variable "project_id" {
  type        = string
  description = "The target Google Cloud Project ID for the Greenfield Cloud Migration"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Target GCP deployment region"
}

variable "vpc_id" {
  type        = string
  description = "The VPC network ID hosting GKE and GCVE resources"
}

variable "subnet_id" {
  type        = string
  description = "The subnetwork ID for the GKE CDE environment"
}

variable "folder_id" {
  type        = string
  description = "The Organization Folder ID for aggregated SIEM logging"
}
