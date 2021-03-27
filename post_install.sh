#!/bin/sh

#enable all services
echo -n "Enabling all services..."
{
sysrc zabbix_agentd_enable="YES" 
sysrc zabbix_server_enable="YES" 
sysrc nginx_enable="YES" 
sysrc php_fpm_enable="YES" 
sysrc mysql_enable="YES" 
} &> /dev/null
echo " ok"

# Copy sample files to config files
echo -n "Creating Zabbix config files..."
{
ZABBIX_CONFIG_URI="https://raw.githubusercontent.com/xTITUSMAXIMUSX/iocage-plugin-zabbix5-server/master/zabbix.conf.php"
/usr/bin/fetch -o /usr/local/www/zabbix5/conf/zabbix.conf.php ${ZABBIX_CONFIG_URI} 
cp /usr/local/etc/zabbix5/zabbix_agentd.conf.sample /usr/local/etc/zabbix5/zabbix_agentd.conf 
cp /usr/local/etc/zabbix5/zabbix_server.conf.sample /usr/local/etc/zabbix5/zabbix_server.conf 
} &> /dev/null
echo " ok"

# update nginx conf
echo -n "Updating nginx config..."
{
NGINX_CONFIG_URI="https://raw.githubusercontent.com/xTITUSMAXIMUSX/iocage-plugin-zabbix5-server/master/nginx.conf"
rm /usr/local/etc/nginx/nginx.conf 
/usr/bin/fetch -o /usr/local/etc/nginx/nginx.conf ${NGINX_CONFIG_URI} 
chown www:www /usr/local/etc/nginx/nginx.conf 
} &> /dev/null
echo " ok"

# Update php-fpm config
echo -n "Updating php-fpm config..."
{
sed -i www.conf s/\;listen\.owner\ \=\ www/listen\.owner\ \=\ www/g /usr/local/etc/php-fpm.d/www.conf 
sed -i www.conf s/\;listen\.group\ \=\ www/listen\.group\ \=\ www/g /usr/local/etc/php-fpm.d/www.conf 
sed -i www.conf s/\;listen\.mode\ \=\ 0660/listen\.mode\ \=\ 0660/g /usr/local/etc/php-fpm.d/www.conf 
} &> /dev/null
echo " ok"

# Update PHP.ini
echo -n "Updating php.ini config"
{
cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini 
sed -i php.ini s/post\_max\_size\ \=\ 8M/post\_max\_size\ \=\ 16M/g /usr/local/etc/php.ini 
sed -i php.ini s/max\_execution\_time\ \=\ 30/max\_execution\_time\ \=\ 300/g /usr/local/etc/php.ini 
sed -i php.ini s/max\_input\_time\ \=\ 60/max\_input\_time\ \=\ 300/g /usr/local/etc/php.ini 
sed -i php.ini s/\;date\.timezone\ \=\/date\.timezone\ \=\ America\\/Chicago/g /usr/local/etc/php.ini 
} &> /dev/null
echo " ok"

# Creating zabbix DB and user
echo -n "Creating Zabbix DB and user..."
{
service mysql-server start 
mysql_random_pass=$(openssl rand -hex 10)
mysql_admin_pass=$(awk NR==2 /root/.mysql_secret)
mysql_admin_random_pass=$(openssl rand -hex 10)
echo "set password = password('$mysql_admin_random_pass'); flush privileges;" >> updateroot.sql
echo "create database zabbix character set utf8 collate utf8_bin;" >> createzabbixuser.sql
echo "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY '$mysql_random_pass';" >> createzabbixuser.sql
echo "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';" >> createzabbixuser.sql
mysql -u root --password="$mysql_admin_pass" --connect-expired-password < updateroot.sql 
mysql -u root --password="$mysql_admin_random_pass" < createzabbixuser.sql 
mysql -u root --password="$mysql_admin_random_pass" zabbix < /usr/local/share/zabbix5/server/database/mysql/schema.sql 
mysql -u root --password="$mysql_admin_random_pass" zabbix < /usr/local/share/zabbix5/server/database/mysql/images.sql 
mysql -u root --password="$mysql_admin_random_pass" zabbix < /usr/local/share/zabbix5/server/database/mysql/data.sql 
} &> /dev/null
echo " ok"

# update zabbix.conf.php file
{
sed -i zabbix.conf.php "9s/'';/'$mysql_random_pass';/g" /usr/local/www/zabbix5/conf/zabbix.conf.php
chown -R www:www /usr/local/www/zabbix5/conf/ 
} &> /dev/null

# Add DB password to zabbix server config
{
sed -i zabbix_server.conf "s/# DBPassword=/DBPassword=$mysql_random_pass/g" /usr/local/etc/zabbix5/zabbix_server.conf
} &> /dev/null

# Starting services
echo -n "Staring services"
{
service nginx start 
service zabbix_agentd start 
service zabbix_server start 
service php-fpm start 
} &> /dev/null
echo " ok"

#Adding Usernames and passwords to post install notes
echo -n "Adding post install notes"
 echo "Mysql Root Password: $mysql_admin_random_pass" > /root/PLUGIN_INFO
 echo "Mysql zabbix DB: zabbix" >> /root/PLUGIN_INFO
 echo "Mysql zabbix User: zabbix" >> /root/PLUGIN_INFO
 echo "Mysql zabbix Password: $mysql_random_pass" >> /root/PLUGIN_INFO
echo "Complete!"
