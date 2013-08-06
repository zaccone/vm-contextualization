#!/bin/bash

echo "Starting condor setup from the user-data script:"


###########################
# GLOBAL SETUP
###########################
DOMAIN='t-systems.com'
GLOBAL_HOSTNAME=`/bin/hostname`
GLOBAL_CMS_LOCAL_SITE='T2_CH_CERN_AI'
sed -i "s/$GLOBAL_HOSTNAME/$GLOBAL_HOSTNAME.$DOMAIN/gi" /etc/hosts # condor, sor some magic reason needs it....:(

/bin/hostname $GLOBAL_HOSTNAME.$DOMAIN

/etc/init.d/iptables stop # should be reconfigured, not stopped

cat<<EOF >>/etc/profile.d/cms.sh
export CMS_LOCAL_SITE=$GLOBAL_CMS_LOCAL_SITE
export LANG="C"
export VO_CMS_SW_DIR='/cvmfs/cms.cern.ch'
export PATH=\$VO_SW_DIR:\$PATH
export CMS_PATH=/cvmfs/cms.cern.ch
EOF
source /etc/profile.d/cms.sh

echo "Starting condor setup from the user-data script:"

## INSTALL TIME BINARY, jobs will very likely fail with the 127 Exit Code
## if they dont find it.

if [ ! -e /usr/bin/time ]; then
    echo -n "/usr/bin/time was not found, installing..."
    yum -y install time ;
    echo "time installed";
fi


##########################
# CVMFS
#####################################################################
CVMFS_CONFIG_REPOSITORIES='cms.cern.ch,grid.cern.ch'
CVMFS_CONFIG_PROXY_ENDPOINT='DIRECT'
CVMFS_CONFIG_CACHE='/var/cache/cvmfs'
CVMFS_CONFIG_QUOTA_LIMIT=8000
CVMFS_CONFIG_SERVER_URL='"http://cvmfs.fnal.gov:8000/opt/@org@;http://cvmfs.racf.bnl.gov:8000/opt/@org@;http://cvmfs-stratum-one.cern.ch:8000/opt/@org@;http://cernvmfs.gridpp.rl.ac.uk:8000/opt/@org@"'
CVMFS_CONFIG_CMS_LOCAL_SITE='T2_CH_CERN_AI'

CVMFS_LOCAL_FILE='/etc/cvmfs/default.local'
CVMFS_RPM_ENDPOINT='http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm'
CVMFS_RPM_OSG_ENDPOINT='http://repo.grid.iu.edu/osg-el6-release-latest.rpm'

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

###########################
# GANGLIA-GMOND
###########################
GMOND_CONFIG_CLUSTER_NAME='HelixNebula'
GMOND_CONFIG_UDP_SEND_CHANNEL_HOST='212.166.107.199'
GMOND_CONFIG_UDP_SEND_CHANNEL_PORT=8649
GMOND_CONFIG_UDP_SEND_CHANNEL_TTL=32
GMOND_CONFIG_UDP_RECV_CHANNEL=8649
GMOND_CONFIG_TCP_ACCEPT_CHANNEL=8649

GMOND_CONFIGURATION_FILE='/etc/ganglia/gmond.conf'

yum -y install ganglia-gmond.x86_64

cat <<EOF >$GMOND_CONFIGURATION_FILE
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
  allow_extra_data = yes
  host_dmax = 0 /*secs */
  cleanup_threshold = 300 /*secs */
  gexec = no
  send_metadata_interval = 0 /*secs */
}

/*
 * The cluster attributes specified will be used as part of the <CLUSTER>
 * tag that will wrap all hosts collected by this instance.
 */
cluster {
  name = "$GMOND_CONFIG_CLUSTER_NAME"
  owner = "CERN"
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
  #bind_hostname = yes # Highly recommended, soon to be default.
                       # This option tells gmond to use a source address
                       # that resolves to the machine's hostname.  Without
                       # this, the metrics may appear to come from any
                       # interface and the DNS names associated with
                       # those IPs will be used to create the RRDs.
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

/* Each metrics module that is referenced by gmond must be specified and
   loaded. If the module has been statically linked with gmond, it does
   not require a load path. However all dynamically loadable modules must
   include a load path. */
modules {
  module {
    name = "core_metrics"
  }
  module {
    name = "cpu_module"
    path = "modcpu.so"
  }
  module {
    name = "disk_module"
    path = "moddisk.so"
  }
  module {
    name = "load_module"
    path = "modload.so"
  }
  module {
    name = "mem_module"
    path = "modmem.so"
  }
  module {
    name = "net_module"
    path = "modnet.so"
  }
  module {
    name = "proc_module"
    path = "modproc.so"
  }
  module {
    name = "sys_module"
    path = "modsys.so"
  }
}

include ('/etc/ganglia/conf.d/*.conf')

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

/* This collection group will send general info about this host every
   1200 secs.
   This information doesn't change between reboots and is only collected
   once. */
collection_group {
  collect_once = yes
  time_threshold = 1200
  metric {
    name = "cpu_num"
    title = "CPU Count"
  }
  metric {
    name = "cpu_speed"
    title = "CPU Speed"
  }
  metric {
    name = "mem_total"
    title = "Memory Total"
  }
  /* Should this be here? Swap can be added/removed between reboots. */
  metric {
    name = "swap_total"
    title = "Swap Space Total"
  }
  metric {
    name = "boottime"
    title = "Last Boot Time"
  }
  metric {
    name = "machine_type"
    title = "Machine Type"
  }
  metric {
    name = "os_name"
    title = "Operating System"
  }
  metric {
    name = "os_release"
    title = "Operating System Release"
  }
  metric {
    name = "location"
    title = "Location"
  }
}

/* This collection group will send the status of gexecd for this host
   every 300 secs.*/
/* Unlike 2.5.x the default behavior is to report gexecd OFF. */
collection_group {
  collect_once = yes
  time_threshold = 300
  metric {
    name = "gexec"
    title = "Gexec Status"
  }
}

/* This collection group will collect the CPU status info every 20 secs.
   The time threshold is set to 90 seconds.  In honesty, this
   time_threshold could be set significantly higher to reduce
   unneccessary  network chatter. */
collection_group {
  collect_every = 20
  time_threshold = 90
  /* CPU status */
  metric {
    name = "cpu_user"
    value_threshold = "1.0"
    title = "CPU User"
  }
  metric {
    name = "cpu_system"
    value_threshold = "1.0"
    title = "CPU System"
  }
  metric {
    name = "cpu_idle"
    value_threshold = "5.0"
    title = "CPU Idle"
  }
  metric {
    name = "cpu_nice"
    value_threshold = "1.0"
    title = "CPU Nice"
  }
  metric {
    name = "cpu_aidle"
    value_threshold = "5.0"
    title = "CPU aidle"
  }
  metric {
    name = "cpu_wio"
    value_threshold = "1.0"
    title = "CPU wio"
  }
  /* The next two metrics are optional if you want more detail...
     ... since they are accounted for in cpu_system.
  metric {
    name = "cpu_intr"
    value_threshold = "1.0"
    title = "CPU intr"
  }
  metric {
    name = "cpu_sintr"
    value_threshold = "1.0"
    title = "CPU sintr"
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
    title = "One Minute Load Average"
  }
  metric {
    name = "load_five"
    value_threshold = "1.0"
    title = "Five Minute Load Average"
  }
  metric {
    name = "load_fifteen"
    value_threshold = "1.0"
    title = "Fifteen Minute Load Average"
  }
}

/* This group collects the number of running and total processes */
collection_group {
  collect_every = 80
  time_threshold = 950
  metric {
    name = "proc_run"
    value_threshold = "1.0"
    title = "Total Running Processes"
  }
  metric {
    name = "proc_total"
    value_threshold = "1.0"
    title = "Total Processes"
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
    title = "Free Memory"
  }
  metric {
    name = "mem_shared"
    value_threshold = "1024.0"
    title = "Shared Memory"
  }
  metric {
    name = "mem_buffers"
    value_threshold = "1024.0"
    title = "Memory Buffers"
  }
  metric {
    name = "mem_cached"
    value_threshold = "1024.0"
    title = "Cached Memory"
  }
  metric {
    name = "swap_free"
    value_threshold = "1024.0"
    title = "Free Swap Space"
  }
}

collection_group {
  collect_every = 40
  time_threshold = 300
  metric {
    name = "bytes_out"
    value_threshold = 4096
    title = "Bytes Sent"
  }
  metric {
    name = "bytes_in"
    value_threshold = 4096
    title = "Bytes Received"
  }
  metric {
    name = "pkts_in"
    value_threshold = 256
    title = "Packets Received"
  }
  metric {
    name = "pkts_out"
    value_threshold = 256
    title = "Packets Sent"
  }
}

/* Different than 2.5.x default since the old config made no sense */
collection_group {
  collect_every = 1800
  time_threshold = 3600
  metric {
    name = "disk_total"
    value_threshold = 1.0
    title = "Total Disk Space"
  }
}

collection_group {
  collect_every = 40
  time_threshold = 180
  metric {
    name = "disk_free"
    value_threshold = 1.0
    title = "Disk Space Available"
  }
  metric {
    name = "part_max_used"
    value_threshold = 1.0
    title = "Maximum Disk Space Used"
  }
}
EOF

/etc/init.d/gmond start


#############################################################
# CONDOR CONSTANS
#############################################################

CONDOR_TMP_DIR='/tmp/condor'
CONDOR_LOCAL_CONFIG='condor_config.local'

CONDOR_YUM_DIR_DEST="/etc/yum.repos.d"
CONDOR_YUM_HTTP_ENDPOINT="http://www.cs.wisc.edu/condor/yum/repo.d/condor-stable-rhel6.repo"
#CONDOR_YUM_HTTP_ENDPOINT="http://repo.grid.iu.edu/osg-el6-release-latest.rpm"
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



echo "Downloading Condor RPM from yum repository:"
yum -y install condor.x86_64

PERL_MANIP=`yum list installed | grep -i perl-DateManip.noarch | wc -l`
if [ $PERL_MANIP -eq 0 ]; then
	yum -y install perl-DateManip.noarch
fi

# CONDOR INSTALL
echo "Installing CONDOR $CONDOR_VERSION..."

echo "Move all the default local configs to the backup directory"
mkdir -p /etc/condor/backup/config.d
mv -f /etc/condor/config.d/* /etc/condor/backup/config.d


# Copying the condor config file the we wrote before to its final destination, so the configurations can be applied
echo "Configuring condor..."

cat<<EOF >$CONDOR_TMP_DIR/$CONDOR_LOCAL_CONFIG
CONDOR_HOST = $CONDOR_CONFIG_MASTER
COLLECTOR_HOST=$CONDOR_CONFIG_MASTER:$CONDOR_CONFIG_MASTER_PORT
CONDOR_IDS = `cat /etc/passwd | grep condor: | awk -F: '{ print $3"."$4}'`
DAEMON_LIST = MASTER, STARTD
CONDOR_ADMIN = $CONDOR_CONFIG_MASTER
QUEUE_SUPER_USERS = root, condor
HIGHPORT = $CONDOR_CONFIG_HIGHPORT
LOWPORT = $CONDOR_CONFIG_LOWPORT
UID_DOMAIN = $CONDOR_CONFIG_MASTER
FILESYSTEM_DOMAIN = $CONDOR_CONFIG_MASTER
ALLOW_WRITE = *
STARTER_ALLOW_RUNAS_OWNER = False
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
     echo "SLOT${var}_USER=cms${var}" >> $CONDOR_TMP_DIR/$CONDOR_LOCAL_CONFIG
done

# Now that we know condor ID's, rewrite the initial configuration file
sed -i s/xcondoridsx/$CONDOR_ID.$CONDOR_GID/gi  $CONDOR_TMP_DIR/$CONDOR_LOCAL_CONFIG

cp $CONDOR_TMP_DIR/$CONDOR_LOCAL_CONFIG /etc/condor/$CONDOR_LOCAL_CONFIG
ln -s /etc/condor/$CONDOR_LOCAL_CONFIG /etc/condor/config.d/$CONDOR_LOCAL_CONFIG

############################################

echo "Sourcing from /etc/profile.d/condor.sh..."
echo "export PATH=${PATH}:/usr/bin:/sbin" >> /etc/profile.d/condor.sh
echo "export CONDOR_CONFIG=/etc/condor/condor_config" >> /etc/profile.d/condor.sh

source /etc/profile.d/condor.sh

#Let's start Condor 
echo "STARTING CONDOR:"
/etc/init.d/condor start

### Restart gmond

/etc/init.d/gmond restart


exit 0





