#!/bin/bash

###### CONFIGURATION ######
PREFIX="/opt"
TMP="/tmp"
CONDOR_VERSION="condor-7.8.7"
YUM_DIR_DEST="/etc/yum.repos.d"
YUM_HTTP_ENDPOINT="http://www.cs.wisc.edu/condor/yum/repo.d/condor-stable-rhel5.repo"
CONDOR_LOCAL_TEMPLATE='etc/condor/condor_config.local'
CONDOR_MASTER=''

if [ "x$CONDOR_MASTER" == "x" ]; then
	CONDOR_MASTER=`/bin/hostname -f`
fi

###########################


echo "Setup condor in SLC5 configuration"

TMPDIR="$PREFIX/$CONDOR_VERSION"
if [ ! -d "$TMPDIR" ]; then
	echo "Creating directory $TMPDIR"
	mkdir -p /opt/$CONDOR_VERSION
fi

REPO="$YUM_DIR_DEST/condor-stable-rhel5.repo"
if [ -f "$REPO" ]; then
	echo "Removing old repo file $REPO"
	rm -rf $REPO
fi

echo "Retrieving .repo file $YUM_HTTP_ENDPOINT -> $YUM_DIR_DEST"
wget -P $YUM_DIR_DEST $YUM_HTTP_ENDPOINT

echo "Installing yum-downloadonly package"
yum -y install yum-downloadonly

echo "Downloading condor package"
yum -y install condor.x86_64 --downloadonly --downloaddir=$TMP


echo "Installing condor dependencies (libvirt, XML-Simple)"
yum -y install libvirt
yum -y install perl-XML-Simple-2.14-4.fc6.noarch


PERL_MANIP=`yum list installed |grep -i perl-DateManip.noarch | wc -l`
if [ $PERL_MANIP -eq 0 ]; then
	yum -y install perl-DateManip.noarch
fi

echo "Installing condor in $PREFIX/$CONDOR_VERSION"
CONDOR_RPM=`ls -1 $TMP/condor-*.rpm | head -1`



rpm -Uvh $CONDOR_RPM --relocate /usr=$PREFIX/$CONDOR_VERSION/usr --relocate /var=$PREFIX/$CONDOR_VERSION/var --relocate /etc=$PREFIX/$CONDOR_VERSION/etc


###### COPY OVER READY CONDOR CONFIGS ######
echo "Copying condor configuration to it's destination"

ID_GID=`grep condor /etc/passwd | cut -d ':' -f 3-4`
CONDOR_ID=`echo $ID_GID | awk '{split($0,a,":"); print a[1]}'`
CONDOR_GID=`echo $ID_GID | awk '{split($0,a,":"); print a[2]}'`

sed s/xmasterhostx/$CONDOR_MASTER/gi < $CONDOR_LOCAL_FILE.dist > $CONDOR_LOCAL_FILE
sed s/xcondoridsx/$CONDOR_ID.$CONDOR_GID/gi < $CONDOR_LOCAL_FILE.dist > $CONDOR_LOCAL_FILE

if [ ! -d $PREFIX/$CONDOR_VERSION/etc/condor/ ]; then
	mkdir -p $PREFIX/$CONDOR_VERSION/etc/condor/
fi 

echo "copying local condor config to: $PREFIX/$CONDOR_VERSION/etc/condor/"
cp $CONDOR_LOCAL_TEMPLATE $PREFIX/$CONDOR_VERSION/etc/condor/

############################################
chown -R condor:condor $PREFIX/$CONDOR_VERSION
chmod -R o+rwx $PREFIX/$CONDOR_VERSION/var/log

echo "Setting up /etc/ld.so.conf"
cat<<EOF>>/etc/ld.so.conf
$PREFIX/$CONDOR_VERSION/usr/lib64
$PREFIX/$CONDOR_VERSION/usr/lib64/condor
EOF


PROFILE_FILE="/etc/profile.d/condor.sh"

echo "Setting and sourcing condor specific environment variables"
echo "export PATH=${PATH}:/$PREFIX/$CONDOR_VERSION/usr/bin:/$PREFIX/$CONDOR_VERSION/usr/sbin:/sbin" >> $PROFILE_FILE
echo "export CONDOR_CONFIG=/opt/$CONDOR_VERSION/etc/condor/condor_config" >> $PROFILE_FILE

source $PROFILE_FILE

