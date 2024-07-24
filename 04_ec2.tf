resource "aws_ebs_volume" "storage" {
  availability_zone = aws_subnet.public_subnet.availability_zone
  size              = 10
}

data "aws_ami" "linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


resource "aws_launch_template" "launch_template" {
  ebs_optimized = true
  instance_type = var.instance_type
  image_id      = data.aws_ami.linux.id


  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  iam_instance_profile { arn = aws_iam_instance_profile.ec2_profile.arn }

  user_data = base64encode(templatefile("${path.module}/user_data.tftpl", {
    ec2_role_name  = aws_iam_role.ec2_role.name
    ebs_storage_id = aws_ebs_volume.storage.id
    region         = var.region
    cluster_name   = aws_ecs_cluster.cluster.name
    device_path    = "/dev/sdh"
    mount_path     = "/data"
  }))

}

resource "aws_autoscaling_group" "autoscaling_group" {
  name                 = "autoscaling_group"
  vpc_zone_identifier  = [aws_subnet.public_subnet.id]
  min_size             = 1
  max_size             = 1
  desired_capacity     = 1
  termination_policies = ["OldestInstance"]

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

}
