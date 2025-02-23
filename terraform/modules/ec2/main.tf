locals {
  # Se AZs não foram especificadas, usar as da região
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : [
    "${var.aws_region}a",
    "${var.aws_region}b"
  ]
}

# Exemplo de uso em recursos EC2
resource "aws_instance" "example" {
  # ... outras configurações ...
  availability_zone = local.availability_zones[0]
} 