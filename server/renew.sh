#!/bin/bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# call example
#locationOf_renew.sh config.cfg


if [ -z "$1" ]; then
	echo "missing : configuration file, call program like this: renew.sh config.cfg"
	exit
fi


# -------------------------- below are useful functions ---------------------------------

function main() {
  readConfigFile $1
  
  cd ${scriptlocation}

  removeEverythingAt ${packagedestination}
  lockDirectory ${packagedestination}
  
  renewJoomlaFilesAndDatabase
  activateFileConfigurationOnlineIfExist ${packagedestination}

  # empty directory in case they were not empty in zip file  
  removeEverythingAt ${packagedestination}cache
  removeEverythingAt ${packagedestination}log
  removeEverythingAt ${packagedestination}tmp
  
  changeUnixOwnerAndUserGroup ${packagedestination}
  setUnixMinimumRequiredPermissions ${packagedestination}

  secureJoomla
  updateJoomlaModule
  unlockDirectory ${packagedestination}
  #appendRedirectRulesInHtaccess

  assertSiteIsRunning
}

function assertSiteIsRunning() {

    # We use the -O option of wget which allows us to specify the name of the file into which
    # wget dumps the page contents. We specify - to get the dump onto standard output and collect
    # that into the variable content. You can add the -q quiet option to turn off's wget output.
    content=$(wget ${demoSiteLiveUrl} -q -O -);

    if [[ ${content} == *${assertRunningSite}* ]]; then
        echo "Site has been deployed successfuly";
    else
        echo "Site is not running, did not found ${assertRunningSite} at ${demoSiteLiveUrl}";
        exit 1;
    fi
}


function appendRedirectRulesInHtaccess() {
    echo "Append redirect rules In .htaccess to redirect to ${demoSiteLiveUrl}/demoSiteWarning.html"
	echo "#" >> ${packagedestination}/.htaccess
	echo "# Demo has been hardened and the following components urls have been disabled" >> ${packagedestination}/.htaccess
	echo "# to not perturn the user, we redirect him to a page"                          >> ${packagedestination}/.htaccess
	echo "Redirect permanent ${demoSiteLiveUrl}/administrator/components/com_media      ${demoSiteLiveUrl}/demoSiteWarning.html" >> ${packagedestination}/.htaccess
	echo "Redirect permanent ${demoSiteLiveUrl}/administrator/components/com_config     ${demoSiteLiveUrl}/demoSiteWarning.html" >> ${packagedestination}/.htaccess
	echo "Redirect permanent ${demoSiteLiveUrl}/administrator/components/com_installer  ${demoSiteLiveUrl}/demoSiteWarning.html" >> ${packagedestination}/.htaccess
}


function lockDirectory() {
 echo "Lock destination $1"
 cp ${scriptlocation}/.htaccess $1
 cp ${scriptlocation}/.htpasswd $1
}

#unlock the root directory of the demo
function unlockDirectory() {
 echo "Unlock destination $1"
 deleteFileIfExist ${packagedestination}/.htaccess
 deleteFileIfExist ${packagedestination}/.htpasswd

 # get latest and hopefully productive .htaccess from source as it has been deleted at unlock time
 unzip ${packagelocation} .htaccess -d ${packagedestination}
}

function removeEverythingAt() {
  echo "Delete all files at $1 to remove potential scripts backdoors"
  # delete all files
  rm -Rf "$1/*"
  # delete also hidden files
  rm -Rf "$1/.??*"
  cd ${scriptlocation}
}

function renewJoomlaFilesAndDatabase() {
  #unpack package to destination, because of lock do not overwrite .htaccess of lock
  unzip -o ${packagelocation} -d ${packagedestination} -x .htaccess > /dev/null 2>&1
  echo "Archive unpacked at ${packagedestination}"

  if ${mysqlremote} = "true"
  then
    echo "Restore database from ${packagedestination}${mysqltargetablename}.sql to ${mysqlremotehost}"
    mysql -u${mysqldbuser} -p${mysqldbpasswd} ${mysqltargetablename} -h ${mysqlremotehost} < ${packagedestination}${mysqltargetablename}.sql
  else
    echo "Restore database from ${packagedestination}${mysqltargetablename}.sql to localhost"
    mysql -u${mysqldbuser} -p${mysqldbpasswd} ${mysqltargetablename} < ${packagedestination}${mysqltargetablename}.sql
  fi

  if [ $? -ne 0 ] ; then
        echo "did not inject database from file"
        exit 1
  fi

  echo "delete ${packagedestination}${mysqltargetablename}.sql file unpacked from zip package"
  rm ${packagedestination}${mysqltargetablename}.sql 
}


# This create a new file that can be checked for creation time in a dedicated Joomla! module
function updateJoomlaModule() {
  base="${packagedestination}/modules/mod_demositecountdown"
  file="${base}/settings.placeholder.xml";
  targetfile="${base}/settings.xml";
  if [ -f "$file" ]
        then
          nextRun=`date --date "now +${nextrun}"`
          targetYear=`date --date "now +${nextrun}" +%Y`
          targetMonth=`date --date "now +${nextrun}" +%m`
          targetDay=`date --date "now +${nextrun}" +%e`
          targetHour=`date --date "now +${nextrun}" +%k`
          targetMinute=`date --date "now +${nextrun}" +%M`

		  echo "Next update $nextRun Updating file at $file"
          sed -i "s/_targetYear/${targetYear}/g;s/_targetMonth/${targetMonth}/g;s/_targetDay/${targetDay}/g;s/_targetHour/${targetHour}/g;s/_targetMinute/${targetMinute}/g" $file
          echo "Move ${file} to ${targetfile}"
          cp ${file} ${targetfile}
          
          echo "<html><body></body></html>" > ${base}/index.html
        else
          echo "Joomla module mod_demositecountdown not detected, install it from http://joomlacode.org/svn/demosite/trunk/RenewJoomlaDemo"  ;
       fi
}


function changeUnixOwnerAndUserGroup() {
  echo "Change Unix Owner And UserGroup"
  chown -R ${unixuser}:${unixusergrp} $1

}


function setUnixMinimumRequiredPermissions() {
  echo "Set minimum required Unix permissions for files and directories"
  
  # search all directory and set to 555 or r-xr-xr-x
  find $1 -type d -exec chmod 555 {} \;
  
  # search all files  and set to 444 or r--r--r--
  find $1 -type f -exec chmod 444 {} \;
  
  #some directories have to be writable, so set to 755 or rwxr-xr-x
  chmod 755 ${packagedestination}/cache
  chmod 755 ${packagedestination}/logs
  
  chmod g+w ${packagedestination}/cache 
  find ${packagedestination}/cache -type f  -exec chmod 666 {} \;
  #find ${packagedestination}/cache -type d -exec chmod 777 {} \;

 
  chmod 755 ${packagedestination}
}


function activateFileConfigurationOnlineIfExist() {
        if [ -f "$1/configuration.online.php" ]
        then
                echo "found a different online configuration file so use it for runtime"
                mv "$1/configuration.online.php" "$1/configuration.php"
        fi
}


# require one argument 
# ex: deleteFileIfExist /tmp/index.php
function deleteFileIfExist() {
        if [ -f "$1" ]
        then
                rm "$1"
        fi
}

# require one argument 
# ex: deleteDirectoryIfExist /tmp/logs
function deleteDirectoryIfExist() {
        if [ -d "$1" ]
        then
                rm -R "$1"
        fi
}

# delete some files and directories to make hacker's life complicated
function secureJoomla() {
  echo "Removing the users the right to upload, alter or delete files"
  deleteDirectoryIfExist ${packagedestination}/components/com_media
  deleteDirectoryIfExist ${packagedestination}/administrator/components/com_media

  echo "Removing the users the right to change configuration"
  deleteDirectoryIfExist ${packagedestination}/administrator/components/com_config

  echo "Removing the users the right to install extensions"
  deleteDirectoryIfExist ${packagedestination}/administrator/components/com_installer
}

function readConfigFile() {
	echo "Reading config....$1"
	configfile=$1
	configfile_secured='/tmp/$1'
	# check if the file contains something we don't want
	if egrep -q -v '^#|^[^ ]*=[^;]*' "$configfile"; then
	  echo "Config file is unclean, cleaning it..." >&2
	  # filter the original to a new file
	  egrep '^#|^[^ ]*=[^;&]*'  "$configfile" > "$configfile_secured"
	  configfile="$configfile_secured"
	fi
	# now source it, either the original or the filtered variant
	source "$configfile"
}

echo "renew.sh v 1.0.3 - a script to renew your Joomla! demo site - by www.cedricwalter.com"
echo "See http://wiki.waltercedric.com/index.php?title=Demo_site_for_Joomla"
echo "Use http://www.corntab.com/pages/crontab-gui to set up your crontab, recommended is to renew your demo site every 30 minutes"

readConfigFile $1
log=$(main $1)
if [ $? -ne 0 ]; then
   subject="renew.sh v 1.0.3 has encountered some errors";
   echo ${log} | mail -s ${subject} ${reportingEmail}
fi

if [[ ${emailOnSuccess} == *true* ]]; then
   echo ${log} | mail -s "success" "${reportingEmail}"
fi
