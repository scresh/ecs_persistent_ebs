resource "aws_ecs_task_definition" "task_definition" {
  family                   = "task_definition"
  execution_role_arn       = aws_iam_role.role.arn
  task_role_arn            = aws_iam_role.role.arn
  network_mode             = "awsvpc"
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
    name      = "persistent_ebs"
    host_path = "/data"
  }
}