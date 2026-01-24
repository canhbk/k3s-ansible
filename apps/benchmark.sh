#!/bin/bash

# MySQL connection details
MYSQL_HOST="mysql-0.mysql"
MYSQL_PORT="3306"
MYSQL_USER="root"
MYSQL_PASSWORD="your-password-here"
MYSQL_DB="sbtest"

# Sysbench parameters
TABLES=10
TABLE_SIZE=1000000
THREADS=16
TIME=300
