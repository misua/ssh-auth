provider "aws" {
  region = var.aws_region
}

# Create a VPC for our resources
module "vpc" {
  source = "./modules/vpc"
  name   = var.environment_name
  cidr   = var.vpc_cidr
}

# Deploy logging infrastructure (Loki + Grafana)
module "logging" {
  source       = "./modules/logging"
  environment  = var.environment_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
  key_name     = var.ssh_key_name
}

# Deploy Vault server
module "vault" {
  source          = "./modules/vault"
  name            = "${var.environment_name}-vault"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  instance_type   = var.vault_instance_type
  key_name        = var.ssh_key_name
  environments    = var.environments
  logging_server_ip = module.logging.private_ip
}

# Deploy jumpbox hosts
module "jumpbox" {
  source             = "./modules/jumpbox"
  name               = "${var.environment_name}-jumpbox"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  instance_type      = var.jumpbox_instance_type
  key_name           = var.ssh_key_name
  vault_ip           = module.vault.private_ip
  vault_ca_pub_key   = module.vault.ssh_ca_public_key
  environments       = var.environments
  logging_server_ip  = module.logging.private_ip
}
