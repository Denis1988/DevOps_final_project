terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.0" }
  }
}

# You will pass these variables from Jenkins
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

# Generate SSH Key Pair for Ansible to login
resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/k8s-key.pem"
  file_permission = "0400"
}

# Get Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Create Virtual Cloud Network (VCN)
resource "oci_core_vcn" "free_vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "seyoawe-vcn"
  cidr_block     = "10.0.0.0/16"
}

# Create Internet Gateway
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.free_vcn.id
  display_name   = "seyoawe-igw"
  enabled        = true
}

# Default Route Table
resource "oci_core_default_route_table" "default_rt" {
  manage_default_resource_id = oci_core_vcn.free_vcn.default_route_table_id
  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# Default Security List (Allow SSH and HTTP)
resource "oci_core_default_security_list" "default_sl" {
  manage_default_resource_id = oci_core_vcn.free_vcn.default_security_list_id
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options { max = 22 }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { max = 80 }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options { max = 6443 } # Kubernetes API
  }
}

# Create Public Subnet
resource "oci_core_subnet" "public_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.free_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "seyoawe-subnet"
  route_table_id    = oci_core_default_route_table.default_rt.id
  security_list_ids = [oci_core_default_security_list.default_sl.id]
}

# Fetch latest Ubuntu 22.04 Image
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Create the Always Free Compute Instance
resource "oci_core_instance" "free_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "seyoawe-free-tier"
  shape               = "VM.Standard.E2.1.Micro" # Always Free Tier shape [cite:240][cite:244]

  create_vnic_details {
    subnet_id        = oci_core_subnet.public_subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  metadata = {
    ssh_authorized_keys = tls_private_key.k8s_key.public_key_openssh
  }
}

output "public_ip" {
  value = oci_core_instance.free_instance.public_ip
}