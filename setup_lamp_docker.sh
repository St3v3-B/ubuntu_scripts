#!/bin/bash

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create necessary directories
mkdir -p my-lamp-docker/www

# Create a basic PHP index file
cat > my-lamp-docker/www/index.php <<EOL
<?php
phpinfo();
?>
EOL

# Create the Docker Compose file
cat > my-lamp-docker/docker-compose.yml <<EOL
version: '3.8'

services:
  db:
    image: mariadb:latest
    container_name: my_mariadb
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: lamp_db
      MYSQL_USER: lamp_user
      MYSQL_PASSWORD: lamp_password
    volumes:
      - db_data:/var/lib/mysql

  php:
    image: php:8.3-apache
    container_name: my_php
    restart: always
    volumes:
      - ./www:/var/www/html
    ports:
      - "8080:80"
    depends_on:
      - db

  phpmyadmin:
    image: phpmyadmin:latest
    container_name: my_phpmyadmin
    restart: always
    ports:
      - "8081:80"
    environment:
      PMA_HOST: db
      MYSQL_ROOT_PASSWORD: rootpassword
    depends_on:
      - db

volumes:
  db_data:
    driver: local
EOL

# Start the Docker Compose stack
cd my-lamp-docker
docker-compose up -d

echo "LAMP stack is up and running!"
echo "Visit http://localhost:8080 for the web server."
echo "Visit http://localhost:8081 for phpMyAdmin."
