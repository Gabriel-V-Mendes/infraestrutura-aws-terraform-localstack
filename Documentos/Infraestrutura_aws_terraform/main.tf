module "networking" {
  source      = "./modules/networking"
  environment = "dev"
}


module "compute" {
  source          = "./modules/compute"
  environment     = "dev"
  
  vpc_id          = module.networking.vpc_id
  public_subnets  = module.networking.public_subnets
  private_subnets = module.networking.private_subnets
}


module "database" {
  source                = "./modules/database"
  environment           = "dev"
  
  vpc_id                = module.networking.vpc_id
  private_subnets       = module.networking.private_subnets
  
  ec2_security_group_id = module.compute.ec2_security_group_id
}