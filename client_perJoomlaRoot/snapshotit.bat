cd ~dp0

rem This program is free software: you can redistribute it and/or modify
rem it under the terms of the GNU General Public License as published by
rem the Free Software Foundation, either version 3 of the License, or
rem (at your option) any later version.
rem 
rem This program is distributed in the hope that it will be useful,
rem but WITHOUT ANY WARRANTY; without even the implied warranty of
rem MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
rem GNU General Public License for more details.
rem 
rem You should have received a copy of the GNU General Public License
rem along with this program.  If not, see <http://www.gnu.org/licenses/>.


rem ********************************************************************************
rem configuration
rem ********************************************************************************
set sitename=demo-joomla-1.6
set dbuser=
set dbuserpwd=
set dbname=

set "packagedestination=e:\"

rem set path to some excutable
set "PATH=%PATH%;E:\dropbox\My Dropbox\phpstart\xampp\mysql\bin"
set "PATH=%PATH%;C:\Program Files\7-Zip"

rem ********************************************************************************
rem Do not change anything below
rem ********************************************************************************

echo dumping database to a file %dbname%.sql
mysqldump -u%dbuser% -p%dbuserpwd% %dbname% > %dbname%.sql

7z a %packagedestination%%sitename%.zip . -r -xr@snapshotit.excludes

echo "Finished, Snapshotit version 1.0.1"
