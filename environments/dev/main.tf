module "network" {
  source = "../../modules/network"

  name                 = "${var.project_name}-${var.environment}"
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "alb" {
  source = "../../modules/alb"

  name              = "${var.project_name}-${var.environment}"
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  target_port       = var.api_container_port
  health_check_path = var.health_check_path
}

module "ecs" {
  source = "../../modules/ecs"

  name                   = "${var.project_name}-${var.environment}-api"
  aws_region             = var.aws_region
  private_subnet_ids     = module.network.private_subnet_ids
  vpc_id                 = module.network.vpc_id
  alb_security_group_id  = module.alb.alb_security_group_id
  target_group_arn       = module.alb.target_group_arn
  image                  = var.api_image
  container_port         = var.api_container_port
  cpu                    = var.api_cpu
  memory                 = var.api_memory
  desired_count          = var.api_desired_count
  mongodb_uri_secret_arn = var.mongodb_uri_secret_arn
}

module "frontend" {
  source = "../../modules/frontend"

  name        = "${var.project_name}-${var.environment}"
  price_class = var.frontend_price_class
}

module "monitoring" {
  source = "../../modules/monitoring"

  name             = "${var.project_name}-${var.environment}"
  alb_arn_suffix   = module.alb.alb_arn_suffix
  ecs_cluster_name = module.ecs.cluster_name
  ecs_service_name = module.ecs.service_name
  alarm_email      = var.alarm_email
}
