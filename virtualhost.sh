#!/bin/bash
### Set Language
TEXTDOMAIN=virtualhost

### Set default parameters
action=$1
domain=$2
rootDir=$3
owner=$(who am i | awk '{print $1}')
email='y.savary@comon-real.fr'
sitesEnabled='/etc/apache2/sites-enabled/'
sitesAvailable='/etc/apache2/sites-available/'
userDir='/home/comonreal/'
sitesAvailabledomain=$sitesAvailable$domain.conf

### don't modify from here unless you know what you are doing ####

if [ "$(whoami)" != 'root' ]; then
	echo $"You have no permission to run $0 as non-root user. Use sudo"
		exit 1;
fi

if [ "$action" != 'create' ] && [ "$action" != 'delete' ]
	then
		echo $"You need to prompt for action (create or delete) -- Lower-case only"
		exit 1;
fi

while [ "$domain" == "" ]
do
	echo -e $"Please provide domain. e.g.dev,staging"
	read domain
done

if [ "$rootDir" == "" ]; then
	rootDir=${domain//./}
fi

### if root dir starts with '/', don't use /var/www as default starting point
if [[ "$rootDir" =~ ^/ ]]; then
	userDir=''
fi

rootDir=$userDir$rootDir

if [ "$action" == 'create' ]
	then
		### check if domain already exists
		if [ -e $sitesAvailabledomain ]; then
			echo -e $"This domain already exists.\nPlease Try Another one"
			exit;
		fi

		### check if directory exists or not
		if ! [ -d $rootDir ]; then
			### create the directory
			mkdir $rootDir
			mkdir $rootDir/prod
			mkdir $rootDir/dev
			chmod 755 $rootDir


			if ! cp /home/comonreal/index.php $rootDir/prod/index.php && cp /home/comonreal/index.php $rootDir/dev/index.php
			then
				echo $"ERROR: Not able to write in file $rootDir/index.php. Please check permissions"
				exit;
			else
				echo $"Added content to $rootDir/index.php"
			fi
		fi

		if ! echo "
		<VirtualHost *:80>
		  ServerAdmin y.savary@comon-real.fr
		  ServerName $domain
		  DocumentRoot $rootDir/prod/
		  <Directory />
		    AllowOverride All
		  </Directory>
		  <Directory $rootDir/prod/>
		    Options Indexes FollowSymLinks MultiViews
		    AllowOverride all
		    Require all granted
		  </Directory>
		  ErrorLog /var/log/apache2/$domain-error.log
		  LogLevel error
		  CustomLog /var/log/apache2/$domain-access.log combined
		</VirtualHost>
		" > $sitesAvailabledomain
		then
		  echo -e $"There is an ERROR creating $domain file"
		  exit;
		else

		  echo -e $"\nNew Virtual Host Created\n"
		fi


			chown -R comonreal:comonreal $rootDir/*

		### enable website
		a2ensite $domain

		### restart Apache
		/etc/init.d/apache2 reload
	  /usr/local/bin/certbot-auto -d $domain --noninteractive --redirect --apache --expand
		### show the finished message
		echo -e $"Complete! \nYou now have a new Virtual Host \nYour new host is: http://$domain \nAnd its located at $rootDir"
		exit;
	else
		### check whether domain already exists
		if ! [ -e $sitesAvailabledomain ]; then
			echo -e $"This domain does not exist.\nPlease try another one"
			exit;
		else
			### Delete domain in /etc/hosts
			newhost=${domain//./\\.}
			sed -i "/$newhost/d" /etc/hosts

			### disable website
			a2dissite $domain

			### restart Apache
			/etc/init.d/apache2 reload

			### Delete virtual host rules files
			rm $sitesAvailabledomain
		fi

		### check if directory exists or not
		if [ -d $rootDir ]; then
			echo -e $"Delete host root directory ? (y/n)"
			read deldir

			if [ "$deldir" == 'y' -o "$deldir" == 'Y' ]; then
				### Delete the directory
				rm -rf $rootDir
				echo -e $"Directory deleted"
			else
				echo -e $"Host directory conserved"
			fi
		else
			echo -e $"Host directory not found. Ignored"
		fi

		### show the finished message
		echo -e $"Complete!\nYou just removed Virtual Host $domain"
		exit 0;
fi
