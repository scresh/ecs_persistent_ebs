resource "aws_ebs_volume" "storage" {
  availability_zone = aws_subnet.public_subnet.availability_zone
  size              = 10
}