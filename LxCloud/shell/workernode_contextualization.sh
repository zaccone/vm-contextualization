#!/bin/bash

# customize/etc/motd
echo 'Contextualized version of CerVM - ver. BETA' > /etc/motd

# setup vim alias. Quite helpful in many cases
/bin/touch /etc/profile.d/vi.sh
echo "alias vim='vi'" > /etc/profile.d/vi.sh
source /etc/profile.d/vi.sh

# install ganglia, we will need it - until we use CernVM2.6 HEADNODE we must install gmond by hand.
conary install ganglia

# configure gmond (ganglia component) to register at the headnode and provide information 
# about the host.

HEADNODE='IP'
MONITORINGNAME='NAME'
cat<<EOF>/etc/gmond.conf
/* This configuration is as close to 2.5.x default behavior as possible
   The values closely match ./gmond/metric.h definitions in 2.5.x */
globals {
  daemonize = yes
  setuid = yes
  user = nobody
  debug_level = 0
  max_udp_msg_len = 1472
  mute = no
  deaf = no
  allow_extra_data = yes
  host_dmax = 0 /*secs */
  cleanup_threshold = 300 /*secs */
  gexec = no
  send_metadata_interval = 45 /*secs */
}

cluster {
  name = "${MONITORINGNAME}"
  owner = "CERN"
  latlong = "unknown"
  url = "unknown"
}

host {
  location = "unknown"
}

udp_send_channel {
  host = ${HEADNODE}
  port = 8649
  ttl = 32
}

udp_recv_channel {
  port = 8649
}

tcp_accept_channel {
  port = 8649
}

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

include ('/etc/conf.d/*.conf')

collection_group {
  collect_once = yes
  time_threshold = 20
  metric {
    name = "heartbeat"
  }
}

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

collection_group {
  collect_once = yes
  time_threshold = 300
  metric {
    name = "gexec"
    title = "Gexec Status"
  }
}

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

# only after HUPing gmond it will start sending real data to headnode
/etc/init.d/gmond start
sleep 1
kill -HUP `pidof gmond`

cd /cvmfs/cms.cern.ch # just to warm-up cvmfsd

#mkdir -p /data
# Copy site config file and setup to use our squid server
#cd /cvmfs/cms.cern.ch/SITECONF/T1_CH_CERN/JobConfig/
#cp /cvmfs/cms.cern.ch/SITECONF/T1_CH_CERN/JobConfig/site-local-config.xml /data/
#sed -i -e 's/<frontier-connect>/<frontier-connect>\n       <proxy url="http:\/\/128.142.192.20:3128"\/>/g' /data/site-local-config.xml 

############################################################################
[amiconfig]
plugins=cernvm rootsshkeys
[cernvm]
organisations = cms
repositories  = cms,grid
eos-server = eoscms.cern.ch
environment=CMS_SITECONFIG=EC2,CMS_ROOT=/opt/cms
