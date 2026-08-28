data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.environment}-vpc"
  }
}

# --------------------------------------------------
# Internet Gateway
# --------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-igw"
  }
}

# --------------------------------------------------
# Public Subnets
# --------------------------------------------------

resource "aws_subnet" "public" {
  count = 2

  vpc_id = aws_vpc.main.id

  cidr_block = count.index == 0 ? "10.0.1.0/24" : "10.0.2.0/24"

  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-public-${count.index + 1}"
    Tier = "public"
  }
}

# --------------------------------------------------
# Private Application Subnets
# --------------------------------------------------

resource "aws_subnet" "private_app" {
  count = 2

  vpc_id = aws_vpc.main.id

  cidr_block = count.index == 0 ? "10.0.11.0/24" : "10.0.12.0/24"

  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.environment}-private-app-${count.index + 1}"
    Tier = "private-app"
  }
}

# --------------------------------------------------
# Private Database Subnets
# --------------------------------------------------

resource "aws_subnet" "private_db" {
  count = 2

  vpc_id = aws_vpc.main.id

  cidr_block = count.index == 0 ? "10.0.21.0/24" : "10.0.22.0/24"

  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.environment}-private-db-${count.index + 1}"
    Tier = "private-db"
  }
}

# --------------------------------------------------
# Public Route Table
# --------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --------------------------------------------------
# Elastic IP for NAT Gateway
# --------------------------------------------------

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.environment}-nat-eip"
  }
}

# --------------------------------------------------
# NAT Gateway
# --------------------------------------------------

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [
    aws_internet_gateway.main
  ]

  tags = {
    Name = "${var.environment}-nat"
  }
}

# --------------------------------------------------
# Private Application Route Table
# --------------------------------------------------

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-private-app-rt"
  }
}

resource "aws_route" "private_app_internet" {
  route_table_id         = aws_route_table.private_app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "private_app" {
  count = 2

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app.id
}

# --------------------------------------------------
# Private Database Route Table
# --------------------------------------------------

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-private-db-rt"
  }
}

resource "aws_route_table_association" "private_db" {
  count = 2

  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}