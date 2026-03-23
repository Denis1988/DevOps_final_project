terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    tls   = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.0" }
  }
  # Note: Consider adding an S3 or OCI backend here for Jenkins state persistence
}

# --- Variables ---
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}
variable "compartment_ocid" {}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# --- SSH Key Generation ---
resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/k8s-key.pem"
  file_permission = "0400"
}

# --- Network Resources ---
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

resource "oci_core_vcn" "free_vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "seyoawe-vcn"
  cidr_block     = "10.0.0.0/16"
  dns_label      = "seyoawe"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.free_vcn.id
  display_name   = "seyoawe-igw"
  enabled        = true
}

resource "oci_core_default_route_table" "default_rt" {
  manage_default_resource_id = oci_core_vcn.free_vcn.default_route_table_id
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_default_security_list" "default_sl" {
  manage_default_resource_id = oci_core_vcn.free_vcn.default_security_list_id
  
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 22, max = 22 }
  }

  # HTTP
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 80, max = 80 }
  }

  # K8s API
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { min = 6443, max = 6443 }
  }
}

resource "oci_core_subnet" "public_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.free_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "seyoawe-subnet"
  route_table_id    = oci_core_default_route_table.default_rt.id
  security_list_ids = [oci_core_default_security_list.default_sl.id]
  dns_label         = "public"
}

# --- Compute Resources ---

# Fetch Ubuntu 24.04 Minimal
data "oci_core_images" "ubuntu_minimal" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  # Filtering for Minimal specifically
  filter {
    name   = "display_name"
    values = ["^.*-Minimal-.*$"]
    regex  = true
  }
  shape      = "VM.Standard.E2.1.Micro"
  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}

resource "oci_core_instance" "free_instance" {
  # Note: Some regions require a specific AD for Always Free. 
  # If this fails, try index [1] or [2] depending on your region's free tier assignment.
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "seyoawe-free-tier"
  shape               = "VM.Standard.E2.1.Micro"

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu_minimal.images[0].id
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.k8s_key.public_key_openssh
  }
}

# --- Outputs ---
output "public_ip" {
  value = oci_core_instance.free_instance.public_ip
}

output "ssh_private_key_path" {
  value = local_file.private_key.filename
}