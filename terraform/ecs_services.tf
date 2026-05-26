module "ecs_service" {
  for_each = { for svc in var.ecs_services : svc.key => svc }
  source   = "./modules/ecs-fargate-service"

  name = join(var.delimiter, [each.value.key, var.environment])
  image = coalesce(
    try(each.value.image, null),
    "${module.ecr_repository[each.value.ecr_repository_key].repository_url}:${each.value.image_tag}"
  )
  container_port = each.value.container_port
  cpu            = each.value.cpu
  memory         = each.value.memory
  desired_count  = each.value.desired_count
  enable_alb     = each.value.enable_alb
  tags           = merge(try(each.value.tags, {}), { environment = var.environment })
}
