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

  user_data = base64encode(
    join(
      "\n",
      [
        "#!/bin/bash",
        "set -euxo pipefail",
        "sudo yum install -y unzip",
        "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
        "unzip awscliv2.zip",
        "sudo ./aws/install",
        "until curl --fail http://169.254.169.254/latest/meta-data/iam/security-credentials/${aws_iam_role.ec2_role.name}; do sleep 1; done",
        "aws ec2 wait volume-available --volume-ids ${aws_ebs_volume.storage.id} --region ${var.region}",
        "aws ec2 attach-volume --volume-id ${aws_ebs_volume.storage.id} --instance-id $(cat /var/lib/cloud/data/instance-id) --device /dev/sdh --region ${var.region}",
        "aws ec2 wait volume-in-use --volume-ids ${aws_ebs_volume.storage.id} --filters 'Name=attachment.status,Values=attached' --region ${var.region}",
        "until [ -e /dev/sdh ]; do sleep 1; done",
        "sudo blkid $(readlink -f /dev/sdh) || sudo mkfs -t ext4 /dev/sdh",
        "sudo mkdir -p /data",
        "echo '/dev/sdh /data ext4 defaults 0 2' | sudo tee -a /etc/fstab",
        "sudo mount -a",
        "echo ECS_CLUSTER='${aws_ecs_cluster.cluster.name}' > /etc/ecs/ecs.config",
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
