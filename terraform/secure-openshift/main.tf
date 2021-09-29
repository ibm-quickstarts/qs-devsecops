terraform {
  required_version = ">= 0.14.0"
  required_providers {
    ibm = {
      source  = "ibm-cloud/ibm"
      version = ">= 1.27.0"
    }
  }
}

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
}

provider "null" {
}

data "ibm_resource_group" "cos_group" {
  name = var.resource_group
}

resource "ibm_resource_instance" "cos_instance" {
  count             = var.cos_instance_name == "cos-compliance-instance-<timestamp>" ? 1 : 0
  name              = "cos-compliance-instance-${formatdate("YYYYMMDDhhmm", timestamp())}"
  resource_group_id = data.ibm_resource_group.cos_group.id
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
}

resource "ibm_cos_bucket" "cos_bucket" {
  count                = var.cos_bucket_name == "cos-compliance-bucket-<timestamp>" ? 1 : 0
  bucket_name          = "cos-compliance-bucket-${formatdate("YYYYMMDDhhmm", timestamp())}"
  resource_instance_id = ibm_resource_instance.cos_instance[0].id
  region_location      = var.regional_loc
  storage_class        = var.storage
}

resource "ibm_iam_service_id" "cos_serviceID" {
  name = "cos_service_id"
}

resource "ibm_iam_service_api_key" "cos_service_api_key" {
  name           = "cos_service_api_key"
  iam_service_id = ibm_iam_service_id.cos_serviceID.iam_id
}

resource "ibm_iam_service_policy" "cos_policy" {
  iam_service_id = ibm_iam_service_id.cos_serviceID.id
  roles          = ["Reader", "Writer"]

  resources {
    service              = "cloud-object-storage"
    resource_instance_id = var.cos_instance_name == "cos-compliance-instance-<timestamp>" ? ibm_resource_instance.cos_instance[0].id : var.cos_instance_name
  }
}

data "ibm_resource_group" "group" {
  name = var.resource_group
}

resource "ibm_container_cluster" "cluster" {
  count             = var.cluster_name == "compliance-cluster" ? 1 : 0
  name              = var.cluster_name
  datacenter        = var.datacenter
  default_pool_size = var.default_pool_size
  machine_type      = var.machine_type
  hardware          = var.hardware
  kube_version      = var.kube_version
  public_vlan_id    = var.public_vlan_num
  private_vlan_id   = var.private_vlan_num
  resource_group_id = data.ibm_resource_group.group.id
}

resource "null_resource" "create_kubernetes_toolchain" {
  provisioner "local-exec" {
    command = "${path.cwd}/scripts/create-toolchain.sh"

    environment = {
      REGION                  = var.region
      TOOLCHAIN_TEMPLATE_REPO = "https://${var.region}.git.cloud.ibm.com/open-toolchain/compliance-ci-toolchain"
      APPLICATION_REPO        = "https://${var.region}.git.cloud.ibm.com/open-toolchain/hello-compliance-app"
      RESOURCE_GROUP          = var.resource_group
      API_KEY                 = var.ibmcloud_api_key
      CLUSTER_NAME            = var.cluster_name
      CLUSTER_NAMESPACE       = var.cluster_namespace
      REGISTRY_NAMESPACE      = var.registry_namespace
      TOOLCHAIN_NAME          = var.toolchain_name == "compliance-ci-toolchain-<timestamp>" ? "compliance-ci-toolchain-${formatdate("YYYYMMDDhhmm", timestamp())}" : var.toolchain_name
      PIPELINE_TYPE           = "tekton"
      BRANCH                  = var.branch
      APP_NAME                = var.app_name == "compliance-app-<timestamp>" ? "compliance-app-${formatdate("YYYYMMDDhhmm", timestamp())}" : var.app_name
      COS_BUCKET_NAME         = var.cos_bucket_name == "cos-compliance-bucket-<timestamp>" ? ibm_cos_bucket.cos_bucket[0].bucket_name : var.cos_bucket_name
      COS_URL                 = var.cos_url
      COS_API_KEY             = ibm_iam_service_api_key.cos_service_api_key.apikey
      SM_NAME                 = var.sm_name
      SM_SERVICE_NAME         = var.sm_service_name
      GITLAB_TOKEN            = var.gitlab_token
    }
  }
}
