resource "aws_db_subnet_group" "this" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "this" {
  name        = "${var.environment}-rds-sg"
  description = "Allow Postgres access"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_security_group_rule" "ingress" {
  count             = length(var.allowed_cidr_blocks)
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_cidr_blocks[count.index]]
  security_group_id = aws_security_group.this.id
}

resource "aws_db_instance" "this" {
  identifier                  = "${var.environment}-${var.db_name}"
  engine                      = "postgres"
  instance_class              = "db.t3.micro"
  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true
  allocated_storage           = 10
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = [aws_security_group.this.id]
  publicly_accessible         = var.publicly_accessible

  skip_final_snapshot = true
  apply_immediately   = true

  tags = var.tags
}
