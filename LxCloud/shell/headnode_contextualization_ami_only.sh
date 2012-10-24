[amiconfig]
plugins=cernvm squid ganglia
[cernvm]
organisations = cms
repositories  = cms,grid
eos-server = eoscms.cern.ch
environment=CMS_SITECONFIG=EC2,CMS_ROOT=/opt/cms
[squid]
cvmfs_server = cernvm-webfs.cern.ch
cache_mem = 4096 MB
maximum_object_size_in_memory =  32 KB
cache_dir = /var/spool/squid
cache_dir_size = 50000
[ganglia]
name = CernVM
owner = unknown
latlong = unknown
url = unkonown
location = unknown
