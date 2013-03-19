#!/bin/bash

###########################
# CONDOR
#####################
# Cloud-Init contextualization script for installing and configuring condor ins a SLC6 machine
# /opt/condor-7.8.7/etc/init.d/condor start    to start condor
#####################


echo "Starting condor setup from the user-data script:"


###########################
# GLOBAL SETUP
###########################
DOMAIN='rackspace.com'
GLOBAL_HOSTNAME=`/bin/hostname`
GLOBAL_CMS_LOCAL_SITE='T2_CH_CERN_AI'
sed -i "s/$GLOBAL_HOSTNAME/$GLOBAL_HOSTNAME.$DOMAIN/gi" /etc/hosts # condor, sor some magic reason needs it....:(

/bin/hostname $GLOBAL_HOSTNAME.$DOMAIN

/etc/init.d/iptables stop

cat<<EOF >>/etc/profile.d/cms.sh
export CMS_LOCAL_SITE=$GLOBAL_CMS_LOCAL_SITE
export LANG="C"
export VO_CMS_SW_DIR='/srv/env'
export PATH=\$VO_SW_DIR:\$PATH
export CMS_PATH=/cvmfs/cms.cern.ch
EOF
source /etc/profile.d/cms.sh

mkdir -p /srv/env/cms.cern.ch
cat<<EOF >>/srv/env/cms.cern.ch/cmsset_default.sh
#!/bin/bash
export PATH=/cvmfs/cms.cern.ch/common:/cvmfs/cms.cern.ch/bin:\$PATH
if [ ! \$SCRAM_ARCH ]
then
    SCRAM_ARCH=slc5_amd64_gcc434
    export SCRAM_ARCH
fi
here=/cvmfs/cms.cern.ch
if [ "\$VO_CMS_SW_DIR" != ""  ] 
then
    here=\$VO_CMS_SW_DIR
else
    if [ "\$OSG_APP" != "" ]
    then
        here=\$OSG_APP/cmssoft/cms
    fi
fi
if [ ! -d \$here/\${SCRAM_ARCH}/etc/profile.d ] 
then
    echo "Your shell is not able to find where cmsset_default.sh is located." 
    echo "Either you have not set VO_CMS_SW_DIR or OSG_APP correctly"
    echo "or SCRAM_ARCH is not set to a valid architecture."
fi
for pkg in `/bin/ls /etc/profile.d/ | grep 'S.*[.]sh'`
do
	source \$here/\${SCRAM_ARCH}/etc/profile.d/\$pkg
done
if [ ! \$CMS_PATH ]
then
    export CMS_PATH=\$here
fi
if [ ! \$CVSROOT ]
then
    CVSROOT=:gserver:cmssw.cvs.cern.ch:/local/reps/CMSSW
    export CVSROOT
fi

export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
EOF


cat<<EOF >/srv/env/cms.cern.ch/cmsset_default.local
#!/bin/sh
if [ "root" = "cmsprd" ]
then
    export STAGE_SVCCLASS=cmsprod
fi
if [ -z \$PATH ]
then
    export PATH=/afs/cern.ch/cms/caf/scripts
else
    export PATH=/afs/cern.ch/cms/caf/scripts:\${PATH}
fi
if [ -z \$CVS_RSH ]
then
    export CVS_RSH=ssh
fi

EOF

echo "Starting condor setup from the user-data script:"


#############################################################
# First, let's write a condor configuration file in the 
# instance so that we can use it later.
# 
# This is only a configuration example. 
#############################################################


#############################################################
# CONDOR CONSTANS
#############################################################

CONDOR_TMP_DIR='/tmp/condor'
CONDOR_LOCAL_CONFIG='condor_config.local'
CONDOR_DIR='/opt/condor'
CONDOR_VERSION="condor-7.8.7"

CONDOR_YUM_DIR_DEST="/etc/yum.repos.d"
CONDOR_YUM_HTTP_ENDPOINT="http://www.cs.wisc.edu/condor/yum/repo.d/condor-stable-rhel5.repo"
CONDOR_REPO_FILE='condor-stable-rhel5.repo'


CONDOR_CONFIG_MASTER='dashboard61.cern.ch'
CONDOR_CONFIG_LOWPORT=20000
CONDOR_CONFIG_HIGHPORT=24500
CONDOR_CONFIG_MASTER_PORT=20001
#############################################################

if [ ! -d $CONDOR_TMP_DIR ]; then
    /bin/mkdir -p $CONDOR_TMP_DIR;
fi


if [ "x$CONDOR_CONFIG_MASTER" == "x" ]; then
	CONDOR_CONFIG_MASTER=`/bin/hostname`
fi

# Stop running condor daemons
#service condor stop

if [ $? -eq 0 ]; then
	echo "Stopping running condor and removing old condor rpm package..."
	pkill -f condor
	old_condor_version=$(rpm -qa | grep condor)
	rpm -e $old_condor_version
else
	echo "There isn't any previous condor installation in this machine. Proceeding to condor installation..."
fi

cd $CONDOR_YUM_DIR_DEST
echo "Removing old condor repo file."
rm -f $CONDOR_REPO_FILE

echo "Getting the new condor repo file:"
wget $CONDOR_YUM_HTTP_ENDPOINT

echo "Installing Yum's downloadonly module:"
yum -y install yum-downloadonly

echo "Downloading Condor RPM from yum repository:"
yum -y install condor.x86_64 --downloadonly --downloaddir=$CONDOR_TMP_DIR

# Latest version of condor

# Install rpm sources (condor dependencies) by default
yum -y install libvirt
yum -y install perl-XML-Simple


PERL_MANIP=`yum list installed | grep -i perl-DateManip.noarch | wc -l`
if [ $PERL_MANIP -eq 0 ]; then
	yum -y install perl-DateManip.noarch
fi

# CONDOR INSTALL
echo "Installing CONDOR $CONDOR_VERSION..."


CONDOR_RPM=`ls -1 $CONDOR_TMP_DIR/condor-*.rpm | head -1`

rpm -ivh $CONDOR_RPM \
--relocate /usr=$CONDOR_DIR/usr \
--relocate /var=$CONDOR_DIR/var \
--relocate /etc=$CONDOR_DIR/etc 


# Copying the condor config file the we wrote before to its final destination, so the configurations can be applied
echo "Configuring condor..."

cat<<EOF >$CONDOR_TMP_DIR/$CONDOR_LOCAL_CONFIG
CONDOR_HOST = $CONDOR_CONFIG_MASTER
COLLECTOR_HOST=$CONDOR_CONFIG_MASTER:$CONDOR_CONFIG_MASTER_PORT
CONDOR_IDS = xcondoridsx
DAEMON_LIST = MASTER, STARTD
#RELEASE_DIR = $CONDOR_DIR
#LOCAL_DIR = /scratch/condor
CONDOR_ADMIN = $CONDOR_CONFIG_MASTER
QUEUE_SUPER_USERS = root, condor
HIGHPORT = $CONDOR_CONFIG_HIGHPORT
LOWPORT = $CONDOR_CONFIG_LOWPORT
UID_DOMAIN = $CONDOR_CONFIG_MASTER
FILESYSTEM_DOMAIN = $CONDOR_CONFIG_MASTER
ALLOW_WRITE = *
STARTER_ALLOW_RUNAS_OWNER = False
#JAVA=/usr/lib/jvm/java-1.6.0-openjdk-1.6.0.0.x86_64/bin/java
ALLOW_DAEMON=*
HOSTALLOW_READ=*
HOSTALLOW_WRITE=*
SEC_DAEMON_AUTHENTICATION=OPTIONAL

START=True
SUSPEND = FALSE
KILL = FALSE

EOF
###

CPUS=`cat /proc/cpuinfo | grep processor | wc -l`

for var in $(seq $CPUS)
do
     useradd -m -s /sbin/nologin  cms${var} > /dev/null 2>&1
#     dir=$(getent passwd cms${var} | cut -d: -f6)
#     chown -R cms${var} $dir > /dev/null 2>&1
#     chmod -R 775 $dir > /dev/null 2>&1
     echo "SLOT${var}_USER=cms${var}" >> $CONDOR_TMP_DIR/$CONDOR_LOCAL_CONFIG
done


# grabs condor ID and Group ID from /etc/passwd
ID_GID=`grep condor /etc/passwd | cut -d ':' -f 3-4`
CONDOR_ID=`echo $ID_GID | awk '{split($0,a,":"); print a[1]}'`
CONDOR_GID=`echo $ID_GID | awk '{split($0,a,":"); print a[2]}'`

# Now that we know condor ID's, rewrite the initial configuration file
sed -i s/xcondoridsx/$CONDOR_ID.$CONDOR_GID/gi  $CONDOR_TMP_DIR/$CONDOR_LOCAL_CONFIG

cp $CONDOR_TMP_DIR/$CONDOR_LOCAL_CONFIG $CONDOR_DIR/etc/condor/$CONDOR_LOCAL_CONFIG

############################################

echo "Specifying additional default directories in /etc/ld.so.conf:"
# Adds two directories to the ld.so.conf file
cat<<EOF >>/etc/ld.so.conf
$CONDOR_DIR/usr/lib64
$CONDOR_DIR/usr/lib64/condor
EOF

echo "Sourcing from /etc/profile.d/condor.sh..."
echo "export PATH=${PATH}:$CONDOR_DIR/usr/bin:$CONDOR_DIR/usr/sbin:/sbin" >> /etc/profile.d/condor.sh
echo "export CONDOR_CONFIG=$CONDOR_DIR/etc/condor/condor_config" >> /etc/profile.d/condor.sh

echo "Executing ldconfig(8)"
/sbin/ldconfig

source /etc/profile.d/condor.sh

#Let's start Condor 
echo "STARTING CONDOR:"
$CONDOR_DIR/etc/init.d/condor start


##########################
# CVMFS
#####################################################################
# CVMFS CONFIG VARIABLES
#####################################################################
CVMFS_CONFIG_REPOSITORIES='cms.cern.ch,grid.cern.ch'
CVMFS_CONFIG_PROXY_ENDPOINT='DIRECT'
CVMFS_CONFIG_CACHE='/var/cache/cvmfs'
CVMFS_CONFIG_QUOTA_LIMIT=8000
CVMFS_CONFIG_SERVER_URL='"http://cvmfs.fnal.gov:8000/opt/@org@;http://cvmfs.racf.bnl.gov:8000/opt/@org@;http://cvmfs-stratum-one.cern.ch:8000/opt/@org@;http://cernvmfs.gridpp.rl.ac.uk:8000/opt/@org@"'
CVMFS_CONFIG_CMS_LOCAL_SITE='T2_CH_CERN_AI'

CVMFS_LOCAL_FILE='/etc/cvmfs/default.local'
CVMFS_RPM_ENDPOINT='http://dl.fedoraproject.org/pub/epel/5/i386/epel-release-5-4.noarch.rpm'
CVMFS_RPM_OSG_ENDPOINT='http://repo.grid.iu.edu/osg-el5-release-latest.rpm'

rpm -Uvh $CVMFS_RPM_ENDPOINT

yum_priorities=`yum list installed | grep yum-priorities | wc -l`
if [ $yum_priorities -eq 0 ]; then
    yum -y install yum-priorities ;
fi

yum_plugins=`grep 'plugins=1' /etc/yum.conf | wc -l`
if [ $yum_plugins -eq 0 ]; then
    echo "plugins=1" >> /etc/yum.conf ;
fi

### INSTALL OSG REPOSITORIES ###
rpm -Uvh $CVMFS_RPM_OSG_ENDPOINT

#### INSTALLATION ####

yum -y install cvmfs
if [ $? -eq 0 ]; then
	echo "cvmfs packges were installed."
else
	# cleaning yum cache
	yum -y clean all
	yum -y install cvmfs
fi
echo "setup fuse, automount"
FUSE_CONFIG_FILE='/etc/fuse.conf'
user_allow_other_option='user_allow_other'

if [ ! -e $FUSE_CONFIG_FILE ];
then
    echo $user_allow_other_option >> $FUSE_CONFIG_FILE
else
    fuse_allow_other_option_cnt=`grep $user_allow_other_option $FUSE_CONFIG_FILE | wc -l`
    if [ $fuse_allow_other_option_cnt -eq 0 ]; then
        echo $user_allow_other_option >> $FUSE_CONFIG_FILE
    fi
fi

##### allow cvmfs automount itself
sed -i '/+auto.master/d' /etc/auto.master 
echo "/cvmfs /etc/auto.cvmfs" >> /etc/auto.master
echo "+auto.master" >> /etc/auto.master

echo "Base setup..."

#### cvmfs setup example
cat<<EOF >>$CVMFS_LOCAL_FILE
CVMFS_REPOSITORIES=$CVMFS_CONFIG_REPOSITORIES
CVMFS_HTTP_PROXY=$CVMFS_CONFIG_PROXY_ENDPOINT
CVMFS_QUOTA_LIMIT=$CVMFS_CONFIG_QUOTA_LIMIT
CVMFS_CACHE_BASE=/var/cache/cvmfs
CVMFS_DEFAULT_DOMAIN=cern.ch
CVMFS_TIMEOUT=5
CVMFS_TIMEOUT_DIRECT=10
CVMFS_NFILES=65535
CMS_LOCAL_SITE=$CVMFS_CONFIG_CMS_LOCAL_SITE
export CMS_LOCAL_SITE=$CVMFS_CONFIG_CMS_LOCAL_SITE
EOF

cat<<EOF >>/etc/cvmfs/domain.d/cern.ch.local
CVMFS_SERVER_URL=$CVMFS_CONFIG_SERVER_URL
EOF

/sbin/service cvmfs restartautofs 
sleep 5
/sbin/service cvmfs restartclean

#### review script cause there's a mounting issue after the cvmfs setup ######


#######################################################################
#######################################################################
############# CVMFS IS DONE (final review required)####################
#######################################################################
#
#
#
###########################
# GANGLIA-GMOND
###########################
GMOND_CONFIG_CLUSTER_NAME='RACKSPACE'
GMOND_CONFIG_UDP_SEND_CHANNEL_HOST='dashboard61.cern.ch'
GMOND_CONFIG_UDP_SEND_CHANNEL_PORT=24501
GMOND_CONFIG_UDP_SEND_CHANNEL_TTL=32
GMOND_CONFIG_UDP_RECV_CHANNEL=24501
GMOND_CONFIG_TCP_ACCEPT_CHANNEL=24501

yum -y install ganglia-gmond.x86_64

cat <<EOF >/etc/gmond.conf
/* This configuration is as close to 2.5.x default behavior as possible
   The values closely match ./gmond/metric.h definitions in 2.5.x */
globals {
  daemonize = yes
  setuid = yes
  user = ganglia
  debug_level = 0
  max_udp_msg_len = 1472
  mute = no
  deaf = no
  host_dmax = 0 /*secs */
  cleanup_threshold = 300 /*secs */
  gexec = no

}

/* If a cluster attribute is specified, then all gmond hosts are wrapped inside
 * of a <CLUSTER> tag.  If you do not specify a cluster tag, then all <HOSTS> will
 * NOT be wrapped inside of a <CLUSTER> tag. */
cluster {
  name = "$GMOND_CONFIG_CLUSTER_NAME"
  owner = ""
  latlong = "unspecified"
  url = "unspecified"
}

/* The host section describes attributes of the host, like the location */
host {
  location = "unspecified"
}

/* Feel free to specify as many udp_send_channels as you like.  Gmond
   used to only support having a single channel */
udp_send_channel {
  host = $GMOND_CONFIG_UDP_SEND_CHANNEL_HOST
  port = $GMOND_CONFIG_UDP_SEND_CHANNEL_PORT
  ttl = $GMOND_CONFIG_UDP_SEND_CHANNEL_TTL
}

/* You can specify as many udp_recv_channels as you like as well. */
udp_recv_channel {
  port = $GMOND_CONFIG_UDP_RECV_CHANNEL
}

/* You can specify as many tcp_accept_channels as you like to share
   an xml description of the state of the cluster */
tcp_accept_channel {
  port = $GMOND_CONFIG_TCP_ACCEPT_CHANNEL
}
/* The old internal 2.5.x metric array has been replaced by the following
   collection_group directives.  What follows is the default behavior for
   collecting and sending metrics that is as close to 2.5.x behavior as
   possible. */

/* This collection group will cause a heartbeat (or beacon) to be sent every
   20 seconds.  In the heartbeat is the GMOND_STARTED data which expresses
   the age of the running gmond. */
collection_group {
  collect_once = yes
  time_threshold = 20
  metric {
    name = "heartbeat"
  }
}

/* This information doesn't change between reboots and is only collected once. */
collection_group {
  collect_once = yes
  time_threshold = 1200
  metric {
    name = "cpu_num"
  }
  metric {
    name = "cpu_speed"
  }
  metric {
    name = "mem_total"
  }
  /* Should this be here? Swap can be added/removed between reboots. */
  metric {
    name = "swap_total"
  }
  metric {
    name = "boottime"
  }
  metric {
    name = "machine_type"
  }
  metric {
    name = "os_name"
  }
  metric {
    name = "os_release"
  }
  metric {
    name = "location"
  }
}

/* This collection group will send the status of gexecd for this host every 300 secs */
/* Unlike 2.5.x the default behavior is to report gexecd OFF.  */
collection_group {
  collect_once = yes
  time_threshold = 300
  metric {
    name = "gexec"
  }
}


/* This collection group will collect the CPU status info every 20 secs.
   The time threshold is set to 90 seconds.  In honesty, this time_threshold could be
   set significantly higher to reduce unneccessary network chatter. */
collection_group {
  collect_every = 20
  time_threshold = 90
  /* CPU status */
  metric {
    name = "cpu_user"
    value_threshold = "1.0"
  }
  metric {
    name = "cpu_system"
    value_threshold = "1.0"
  }
  metric {
    name = "cpu_idle"
    value_threshold = "5.0"
  }
  metric {
    name = "cpu_nice"
    value_threshold = "1.0"
  }
  metric {
    name = "cpu_aidle"
    value_threshold = "5.0"
  }
  metric {
    name = "cpu_wio"
    value_threshold = "1.0"
  }
  /* The next two metrics are optional if you want more detail...
     ... since they are accounted for in cpu_system.
  metric {
    name = "cpu_intr"
    value_threshold = "1.0"
  }
  metric {
    name = "cpu_sintr"
    value_threshold = "1.0"
  }
  */
}



collection_group {
  collect_every = 20
  time_threshold = 90
  /* Load Averages */
  metric {
    name = "load_one"
    value_threshold = "1.0"
  }
  metric {
    name = "load_five"
    value_threshold = "1.0"
  }
  metric {
    name = "load_fifteen"
    value_threshold = "1.0"
  }
}

/* This group collects the number of running and total processes */
collection_group {
  collect_every = 80
  time_threshold = 950
  metric {
    name = "proc_run"
    value_threshold = "1.0"
  }
  metric {
    name = "proc_total"
    value_threshold = "1.0"
  }
}

/* This collection group grabs the volatile memory metrics every 40 secs and
   sends them at least every 180 secs.  This time_threshold can be increased
   significantly to reduce unneeded network traffic. */
collection_group {
  collect_every = 40
  time_threshold = 180
  metric {
    name = "mem_free"
    value_threshold = "1024.0"
  }
  metric {
    name = "mem_shared"
    value_threshold = "1024.0"
  }
  metric {
   name = "mem_buffers"
    value_threshold = "1024.0"
  }
  metric {
    name = "mem_cached"
    value_threshold = "1024.0"
  }
  metric {
    name = "swap_free"
    value_threshold = "1024.0"
  }
}

collection_group {
  collect_every = 40
  time_threshold = 300
  metric {
    name = "bytes_out"
    value_threshold = 4096
  }
  metric {
    name = "bytes_in"
    value_threshold = 4096
  }
  metric {
    name = "pkts_in"
    value_threshold = 256
  }
  metric {
    name = "pkts_out"
    value_threshold = 256
  }
}

/* Different than 2.5.x default since the old config made no sense */
collection_group {
  collect_every = 1800
  time_threshold = 3600
  metric {
    name = "disk_total"
    value_threshold = 1.0
  }
}


collection_group {
  collect_every = 40
  time_threshold = 180
  metric {
    name = "disk_free"
    value_threshold = 1.0
  }
  metric {
    name = "part_max_used"
    value_threshold = 1.0
  }
}

EOF

/etc/init.d/gmond start

#END
######################################
######################################
exit 0

