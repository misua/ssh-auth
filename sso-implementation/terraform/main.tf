provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"
  name   = "${var.environment_name}-vpc"
  cidr   = var.vpc_cidr
}

module "vault" {
  source             = "./modules/vault"
  name               = "${var.environment_name}-vault"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  instance_type      = var.vault_instance_type
  key_name           = var.ssh_key_name
  environments       = var.environments
  enable_auto_unseal = var.enable_auto_unseal
}

module "jumpbox" {
  source           = "./modules/jumpbox"
  name             = "${var.environment_name}-jumpbox"
  vpc_id           = module.vpc.vpc_id
  subnet_ids       = module.vpc.public_subnet_ids
  instance_type    = var.jumpbox_instance_type
  key_name         = var.ssh_key_name
  vault_addr       = module.vault.private_endpoint
  environments     = var.environments
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

module "logging" {
  source    = "./modules/logging"
  name      = "${var.environment_name}-logging"
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.private_subnet_ids[0]
  vault_id  = module.vault.instance_id
  jumpbox_ids = module.jumpbox.instance_ids
}
