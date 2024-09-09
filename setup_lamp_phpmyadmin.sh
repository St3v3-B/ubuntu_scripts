#!/usr/bin/env bash

# Ensure the script runs as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo privileges."
   exit 1
fi

# Ask for MariaDB root and user credentials
read -sp "Enter the new MariaDB root password: " DB_ROOT_PASS
echo
read -p "Enter a name for the new MariaDB user: " DB_USER
read -sp "Enter a password for new MariaDB user $DB_USER: " DB_USER_PASS
echo

# Variables for phpMyAdmin configuration storage
PHPMYADMIN_DB="phpmyadmin"
PHPMYADMIN_USER="pma"
PHPMYADMIN_PASS="pmapass"
SQL_PATH="/usr/share/phpmyadmin/sql/create_tables.sql"

# Update package list and install prerequisites
echo "Updating package list and installing prerequisites..."
apt update
apt install -y software-properties-common ca-certificates lsb-release apt-transport-https

# Add PHP PPA for the latest versions
echo "Adding PHP PPA..."
add-apt-repository ppa:ondrej/php -y
apt update

# Install Apache
echo "Installing Apache..."
apt install -y apache2

# Enable common Apache modules
echo "Enabling common Apache modules..."
a2enmod rewrite
a2enmod headers
a2enmod ssl
a2enmod expires

# Start and enable Apache
echo "Starting and enabling Apache..."
systemctl start apache2
systemctl enable apache2

# Install MariaDB
echo "Installing MariaDB..."
apt install -y mariadb-server mariadb-client

# Start and enable MariaDB
echo "Starting and enabling MariaDB..."
systemctl start mariadb
systemctl enable mariadb

# Secure MariaDB installation
echo "Securing MariaDB installation..."
mysql --user=root <<SQL_QUERY
UPDATE mysql.user SET Password=PASSWORD('$DB_ROOT_PASS') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
SQL_QUERY

# Create a new MariaDB user with full privileges
echo "Creating new MariaDB user with full privileges..."
mysql --user=root --password="$DB_ROOT_PASS" <<SQL_QUERY
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_USER_PASS';
GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL_QUERY

# Install PHP 8.3 and necessary modules
echo "Installing PHP 8.3 and necessary modules..."
apt install -y php8.3 libapache2-mod-php8.3 php8.3-mysql php8.3-cli \
php8.3-curl php8.3-gd php8.3-mbstring php8.3-xml php8.3-xmlrpc php8.3-zip

# Restart Apache to apply PHP changes
echo "Restarting Apache..."
systemctl restart apache2

# Install phpMyAdmin
echo "Installing phpMyAdmin..."
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean false"
apt install -y phpmyadmin

# Create phpMyAdmin database and import tables
echo "Setting up phpMyAdmin configuration storage..."
mysql --user=root --password="$DB_ROOT_PASS" <<SQL_QUERY
CREATE DATABASE IF NOT EXISTS $PHPMYADMIN_DB;
USE $PHPMYADMIN_DB;
SOURCE $SQL_PATH;
CREATE USER IF NOT EXISTS '$PHPMYADMIN_USER'@'localhost' IDENTIFIED BY '$PHPMYADMIN_PASS';
GRANT SELECT, INSERT, UPDATE, DELETE ON $PHPMYADMIN_DB.* TO '$PHPMYADMIN_USER'@'localhost';
FLUSH PRIVILEGES;
SQL_QUERY

# Update phpMyAdmin configuration file
PHPMYADMIN_CONFIG="/etc/phpmyadmin/config.inc.php"
if ! grep -q "controluser" $PHPMYADMIN_CONFIG; then
    echo "Updating phpMyAdmin configuration file..."
    cat <<EOL >> $PHPMYADMIN_CONFIG

/* User for advanced features */
\$cfg['Servers'][\$i]['controlhost'] = 'localhost';
\$cfg['Servers'][\$i]['controluser'] = '$PHPMYADMIN_USER';
\$cfg['Servers'][\$i]['controlpass'] = '$PHPMYADMIN_PASS';
\$cfg['Servers'][\$i]['pmadb'] = '$PHPMYADMIN_DB';
\$cfg['Servers'][\$i]['bookmarktable'] = 'pma__bookmark';
\$cfg['Servers'][\$i]['relation'] = 'pma__relation';
\$cfg['Servers'][\$i]['table_info'] = 'pma__table_info';
\$cfg['Servers'][\$i]['table_coords'] = 'pma__table_coords';
\$cfg['Servers'][\$i]['pdf_pages'] = 'pma__pdf_pages';
\$cfg['Servers'][\$i]['column_info'] = 'pma__column_info';
\$cfg['Servers'][\$i]['history'] = 'pma__history';
\$cfg['Servers'][\$i]['designer_coords'] = 'pma__designer_coords';
\$cfg['Servers'][\$i]['tracking'] = 'pma__tracking';
\$cfg['Servers'][\$i]['userconfig'] = 'pma__userconfig';
\$cfg['Servers'][\$i]['recent'] = 'pma__recent';
\$cfg['Servers'][\$i]['favorite'] = 'pma__favorite';
EOL
else
    echo "phpMyAdmin configuration is already set."
fi

# Restart Apache to apply new configurations
echo "Restarting Apache one more time..."
systemctl restart apache2

echo "LAMP stack with PHP 8.3 and phpMyAdmin setup is complete."
echo "You can now access phpMyAdmin through your web server."
echo "PHP version installed:"
php -v