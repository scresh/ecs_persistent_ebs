resource "aws_ecs_cluster" "cluster" {
  name = "cluster"
}

resource "aws_ecs_task_definition" "task_definition" {
  family                   = "task_definition"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "host"
  requires_compatibilities = ["EC2"]

  container_definitions = jsonencode(
    [
      {
        "name" : "sqlite_web",
        "image" : "coleifer/sqlite-web:latest",
        "entryPoint" : [
          "sh",
          "-c"
        ],
        "command" : [
          "touch /data/sqlite3.db && sqlite_web -H 0.0.0.0 -x /data/sqlite3.db"
        ],
        "memory" : 1024,
        "portMappings" : [
          {
            "containerPort" : 8080,
            "hostPort" : 8080,
            "protocol" : "tcp"
          }
        ],
        "mountPoints" : [
          {
            "containerPath" : "/data",
            "sourceVolume" : "persistent_ebs"
          }
        ]
      }
    ]
  )

  volume {
    name = "persistent_ebs"
    docker_volume_configuration {
      scope         = "shared"
      autoprovision = true
      driver        = "rexray/ebs"
      driver_opts = {
        volumetype = "gp2"
        size       = 10
      }
    }
  }
}

resource "aws_ecs_capacity_provider" "capacity_provider" {
  name = "capacity_provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.autoscaling_group.arn

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 1
    }
  }
}

resource "aws_ecs_service" "service" {
  name                               = "service"
  cluster                            = aws_ecs_cluster.cluster.id
  task_definition                    = aws_ecs_task_definition.task_definition.arn
  desired_count                      = 1
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  enable_execute_command             = true

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.capacity_provider.name
    weight            = 100
  }

}

resource "aws_ecs_cluster_capacity_providers" "capacity_providers" {
  cluster_name       = aws_ecs_cluster.cluster.name
  capacity_providers = [aws_ecs_capacity_provider.capacity_provider.name]
}