#!/bin/bash
# customize/etc/motd
#echo 'autogconfigured-squid' > /etc/motd
# setup vim alias. Quite helpful in many cases
#/bin/touch /etc/profile.d/vi.sh
#echo "alias vim='vi'" > /etc/profile.d/vi.sh
#source /etc/profile.d/vi.sh

useradd dbfrontier

### VARIABLES
USER='dbfrontier'
INSTALL_DIR='/home/${USER}/squid'
OLDINSTALL_DIR='/home/${USER}/oldsquid'
MISSING_CACHEDIR=$INSTALL_DIR'/frontier-cache/squid/var/cache'
PACKAGE='frontier-squid-2.7.STABLE9-9'
TARPACKAGE=$PACKAGE'.tar.gz'
PACKAGELINK='http://frontier.cern.ch/dist/'$TARPACKAGE

NETMASK="128.142.0.0/16"
CACHE_MEMORY='128'  # MB
CACHE_DISK='2000' # 2GB in this case

LOGNAME='/home/${USER}/squid-server-deployment-'`date +%Y-%m-%d-%R:%S`'.log'

###

### Functions
check_exit_code() {
	expected_code=$1
        comment=$2

        if [ $? -ne $expected_code ]
        then
                echo $comment
                exit 1
        fi
}
check_user() {
    user=$1
    if id $user > /dev/null 2>&1
    then
        return 1
    else
        return 0
    fi
}

###

### Start work here

# Redirect streams to files.
exec 1> /home/${USER}/squid-install.stdout
exec 2> /home/${USER}/squid-install.stderr


check_user "$USER"
exists=$?
if [ $exists -ne 0 ];
then
    echo "User ${USER} exists, proceeding."
else
    echo "User ${USER} doesn't exist. Adding."
    useradd $USER
    check_exit_code 0 "Cannot add user"
fi 

DIR=`su -c "mktemp -dp /home/${USER}/" ${USER}` 
cd $DIR

echo "Auto deplyment of squid server..."
echo "Following instructions from:"
echo "https://twiki.cern.ch/twiki/bin/view/CMS/SquidForCMS#Installing_Frontier_Local_Squid"

echo -n "Downloading and unpacking the package...."
#cd /home/${USER}
su -c "wget $PACKAGELINK " ${USER}
check_exit_code 0 "Problems with wget"

su -c "tar -xvzf $TARPACKAGE" ${USER}
check_exit_code 0 "Problems with unpacking the squid package"

echo "done"

cd $PACKAGE

echo "Calling configuration script..."

if [ ! -e './configure' ] 
then
    echo "Cannot find ./configure script"
    exit 1
fi


su -c "./configure --prefix=$INSTALL_DIR --oldprefix=$OLDINSTALL_DIR<<EOF
$NETMASK
$CACHE_MEMORY
$CACHE_DISK
EOF" ${USER}
check_exit_code 0 "Cannot configure squid,sorry"

su -c "mkdir -p $MISSING_CACHEDIR" ${USER}
check_exit_code 0 "Create this missing cache directory?"

echo "Installing squid"

su -c "make" ${USER}
check_exit_code 0 "Cannot build squid package, exiting..."

su -c "make install" ${USER}
check_exit_code 0 "Cannot install squid, exiting..."

echo "Squid installed"
echo "Running squid instance..."
su -c "$INSTALL_DIR/frontier-cache/utils/bin/fn-local-squid.sh start" ${USER}

check_exit_code 0 "Problems with starting squid"

su -c "cat<<EOF>${INSTALL_DIR}/frontier-cache/utils/cron/crontab.dat
7 7 * * * ${INSTALL_DIR}/frontier-cache/utils/cron/daily.sh >/dev/null 2>&1 
8 * * * * ${INSTALL_DIR}/frontier-cache/utils/cron/hourly.sh >/dev/null 2>&1
EOF" ${USER}

check_exit_code 0 "Problems with setting crontab"

rm -rf $DIR
exit 0

############################################################################
[amiconfig]
plugins=cernvm
[cernvm]
organisations = cms
repositories  = cms,grid
eos-server = eoscms.cern.ch
proxy = http://127.0.0.1:3128
environment=CMS_SITECONFIG=EC2,CMS_ROOT=/opt/cms
