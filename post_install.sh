#!/bin/sh

#enable all services
echo -n "Enabling all services"
sysrc zabbix_agentd_enable="YES"
sysrc zabbix_server_enable="YES"
sysrc nginx_enable="YES"
sysrc php_fpm_enable="YES"
sysrc mysql_enable="YES"
echo " ok"

# Copy sample files to config files
echo -n "Creating Zabbix config files"
 cp /usr/local/etc/zabbix5/zabbix_agentd.conf.sample /usr/local/etc/zabbix5/zabbix_agentd.conf
 cp /usr/local/etc/zabbix5/zabbix_server.conf.sample /usr/local/etc/zabbix5/zabbix_server.conf
echo " ok"

# update nginx conf
NGINX_CONFIG_URI="https://raw.githubusercontent.com/xTITUSMAXIMUSX/iocage-plugin-zabbix5-server/master/nginx.conf"
echo -n "Updating nginx config..."
rm /usr/local/etc/nginx/nginx.conf
/usr/bin/fetch -o /usr/local/etc/nginx/nginx.conf ${NGINX_CONFIG_URI}
chown www:www /usr/local/etc/nginx/nginx.conf
echo " ok"

# Update php-fpm config
echo -n "Updating php-fpm config"
sed -i www.conf s/\;listen\.owner\ \=\ www/listen\.owner\ \=\ www/g /usr/local/etc/php-fpm.d/www.conf
sed -i www.conf s/\;listen\.group\ \=\ www/listen\.group\ \=\ www/g /usr/local/etc/php-fpm.d/www.conf
sed -i www.conf s/\;listen\.mode\ \=\ 0660/listen\.mode\ \=\ 0660/g /usr/local/etc/php-fpm.d/www.conf
echo " ok"

# Update PHP.ini
echo -n "Updating php.ini config"
cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini
sed -i php.ini s/post\_max\_size\ \=\ 8M/post\_max\_size\ \=\ 16M/g /usr/local/etc/php.ini
sed -i php.ini s/max\_execution\_time\ \=\ 30/max\_execution\_time\ \=\ 300/g /usr/local/etc/php.ini
sed -i php.ini s/max\_input\_time\ \=\ 60/max\_input\_time\ \=\ 300/g /usr/local/etc/php.ini
sed -i php.ini s/\;date\.timezone\ \=\/date\.timezone\ \=\ America\\/Chicago/g /usr/local/etc/php.ini
echo -n " ok"

# Creating zabbix DB and user
echo -n "Creating Zabbix DB and user"
service mysql-server start
mysql_random_pass=$(openssl rand -base64 8)
mysql -u root -e "create database zabbix character set utf8 collate utf8_bin;"
mysql -u root -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '$mysql_random_pass';"
mysql -u root -e "ALTER USER 'zabbix'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mysql_random_pass';"
mysql -u root -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
mysql -u root zabbix < /usr/local/share/zabbix5/server/database/mysql/schema.sql
mysql -u root zabbix < /usr/local/share/zabbix5/server/database/mysql/images.sql
mysql -u root zabbix < /usr/local/share/zabbix5/server/database/mysql/data.sql
echo -n " ok"

# update zabbix.conf.php file
sed -i zabbix.conf.php "9s/'';/'$mysql_random_pass'/g" /usr/local/www/zabbix5/conf/zabbix.conf.php
chown -R www:www /usr/local/www/zabbix5/conf/

# Starting services
echo -n "Staring services"
service nginx start
service zabbix_agentd start
service zabbix_server start
service php-fpm start
echo -n " ok"

echo -n " SQL Pass: $mysql_random_pass"
