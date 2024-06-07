resource "aws_ecs_cluster" "cluster" {
  name = "cluster"
}

resource "aws_launch_template" "launch_template" {
  name                   = "launch_template"
  ebs_optimized          = true
  instance_type          = var.instance_type
  image_id               = data.aws_ami.linux.id

  iam_instance_profile {
    arn = aws_iam_instance_profile.profile.arn
  }

    network_interfaces {
      associate_public_ip_address = true
      security_groups             = [aws_security_group.security_group.id]
    }

  user_data = base64encode(
    join(
      "\n",
      [
        "#!/bin/bash",
        "set -euxo pipefail",
        "echo ECS_CLUSTER='${aws_ecs_cluster.cluster.name}' > /etc/ecs/ecs.config",
        "sudo yum install -y unzip",
        "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
        "unzip awscliv2.zip",
        "sudo ./aws/install",
        "aws ec2 wait volume-available --volume-ids ${aws_ebs_volume.storage.id}",
        "aws ec2 attach-volume --volume-id ${aws_ebs_volume.storage.id} --instance-id $(cat /var/lib/cloud/data/instance-id) --device /dev/sdh",
        "aws ec2 wait volume-in-use --volume-ids ${aws_ebs_volume.storage.id} --filters 'Name=attachment.status,Values=attached'",
        "sudo blkid $(readlink -f /dev/sdh) || sudo mkfs -t ext4 /dev/sdh",
        "sudo mkdir -p /data",
        "echo '/dev/sdh /data ext4 defaults 0 2' | sudo tee -a /etc/fstab",
        "sudo mount -a",
      ]
    )
  )
}

resource "aws_autoscaling_group" "autoscaling_group" {
  name                 = "autoscaling_group"
  vpc_zone_identifier  = [aws_subnet.public_subnet.id]
  min_size             = 1
  max_size             = 1
  desired_capacity     = 1
  health_check_type    = "EC2"
  termination_policies = ["OldestInstance"]

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
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
  desired_count                      = 1
  task_definition                    = aws_ecs_task_definition.task_definition.arn
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  enable_execute_command             = true

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.capacity_provider.name
    base              = 1
    weight            = 100
  }

  network_configuration {
    subnets         = [aws_subnet.public_subnet.id]
    security_groups = [aws_security_group.security_group.id]
  }

}

resource "aws_ecs_cluster_capacity_providers" "capacity_providers" {
  cluster_name       = aws_ecs_cluster.cluster.name
  capacity_providers = [aws_ecs_capacity_provider.capacity_provider.name]
}