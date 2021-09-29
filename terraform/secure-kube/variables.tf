variable "toolchain_name" {
  type        = string
  description = "Name of the Compliance CI toolchain. NOTE: The <timestamp> will be in the format YYYYMMDDhhmm."
  default     = "compliance-ci-toolchain-<timestamp>"
}

variable "sm_name" {
  description = "Name of the Secrets Manager tool integration (Ex. my-secrets-manager)"
  default     = "sm-compliance-secrets"
}

variable "sm_service_name" {
  description = "Name of the Secrets Manager service. NOTE: Only 1 Secrets Manager instance is allowed. If you already have a Secrets Manager service provisioned, please override this value to its name."
  default     = "compliance-ci-secrets-manager"
}

variable "cos_url" {
  type        = string
  description = "URL endpoint to Cloud Object Storage Bucket"
  default     = "s3.private.us-south.cloud-object-storage.appdomain.cloud"
}

variable "cos_instance_name" {
  type        = string
  description = "Name of the Cloud Object Storage instance. NOTE: The <timestamp> will be in the format YYYYMMDDhhmm."
  default     = "cos-compliance-instance-<timestamp>"
}

variable "cos_bucket_name" {
  type        = string
  description = "Name of the Cloud Object Storage bucket. NOTE: The <timestamp> will be in the format YYYYMMDDhhmm."
  default     = "cos-compliance-bucket-<timestamp>"
}

variable "regional_loc" {
  description = "Region where the COS bucket will exist"
  default     = "us-south"
}

variable "storage" {
  description = "Storage class for the COS bucket"
  default     = "standard"
}

variable "app_name" {
  type        = string
  description = "Name of the Compliance CI application. NOTE: The <timestamp> will be in the format YYYYMMDDhhmm."
  default     = "compliance-app-<timestamp>"
}

variable "region" {
  type        = string
  description = "IBM Cloud region where your application will be deployed (to view your current targeted region `ibmcloud cr region`)"
  default     = "us-south"
}

variable "registry_namespace" {
  type        = string
  description = "Container registry namespace to save images (`ibmcloud cr namespaces`). NOTE: The namespace must already exist, or be a unique value."
}

variable "resource_group" {
  type        = string
  description = "Resource group where the resources will be created (`ibmcloud resource groups`)"
  default     = "default"
}

variable "cluster_name" {
  type        = string
  description = "Name of the Kubernetes cluster where your application is deployed. If you use the default value, a new cluster is provisioned. If you override the default value with a different cluster name, that cluster must already exist."
  default     = "compliance-cluster"
}

variable "cluster_namespace" {
  type        = string
  description = "Namespace in Kubernetes cluster where your application will be deployed. If the namespace does not exist, it will be created."
  default     = "default"
}

variable "datacenter" {
  type        = string
  description = "Zone from `ibmcloud ks zones --provider classic`"
  default     = "dal12"
}

variable "default_pool_size" {
  default     = "1"
  description = "Number of worker nodes for the new Kubernetes cluster"
}

variable "machine_type" {
  default     = "b3c.4x16"
  description = "Name of machine type from `ibmcloud ks flavors --zone <ZONE>`"
}
variable "hardware" {
  default     = "shared"
  description = "The level of hardware isolation for your worker node. Use 'dedicated' to have available physical resources dedicated to you only, or 'shared' to allow physical resources to be shared with other IBM customers. For IBM Cloud Public accounts, the default value is shared. For IBM Cloud Dedicated accounts, dedicated is the only available option."
}

variable "kube_version" {
  default     = "1.20.8"
  description = "Version of Kubernetes to apply to the new Kubernetes cluster (Run: `ibmcloud ks versions` to see available versions)"
}

variable "public_vlan_num" {
  type        = string
  description = "Number for public VLAN from `ibmcloud ks vlans --zone <ZONE>`"
  default     = "1911479"
}

variable "private_vlan_num" {
  type        = string
  description = "Number for private VLAN from `ibmcloud ks vlans --zone <ZONE>`"
  default     = "1891999"
}

variable "branch" {
  type        = string
  description = "Branch for Compliance CI toolchain template repo"
  default     = "master"
}

variable "ibmcloud_api_key" {
  type        = string
  description = "The IAM API Key for IBM Cloud access (https://cloud.ibm.com/iam/apikeys)"
}

variable "gitlab_token" {
  type        = string
  description = "A GitLab Personal Access Token (Ex. https://us-south.git.cloud.ibm.com/-/profile/personal_access_tokens NOTE: Make sure to create your token in the same region as your toolchain, or 'region' variable.)"
}
