# linux.lvm_cache
## Notes from creating SSD cached LV
- CentOS 7
- 4x 8TB HDD's in Software RAID-5 (md0p1)
- 1x 160GB INTEL SSD (sda3)

``` man lvmcache ```

### RAID
#### Create the RAID block device
```mdadm --create md0 --level=5 --raid-devices=4 --chunk=1024 /dev/sdb1 /dev/sdc1 /dev/sdd1 /dev/sde1 ```
```
[root@filer01 ~]# cat /proc/mdstat 
Personalities : [raid6] [raid5] [raid4] 
md0 : active raid5 sde1[4] sdd1[2] sdc1[1] sdb1[0]
      23441682432 blocks super 1.2 level 5, 1024k chunk, algorithm 2 [4/3] [UUUU]
      bitmap: 22/59 pages [88KB], 65536KB chunk

unused devices: <none>
```

#### Create mdadm.conf file.  Ensures your MD device is always md0 upon boot.
```mkdir -p /etc/mdadm; mdadm --examine --scan >> /etc/mdadm/mdadm.conf ```
```
[root@filer01 ~]# cat /etc/mdadm/mdadm.conf
ARRAY /dev/md/md0  metadata=1.2 UUID=d481b838:b49ebcb3:570b9a28:03a7350e name=vz03.pdxhosting.net:md0 
```

#### Create disklabel and partition on MD device.  *** ALWAYS PARTITION YOUR MD DEVICE ***
```parted /dev/md0 mklabel gpt; parted -a optimal /dev/md0 mkpart primary 0% 100% ```
```
[root@filer01 ~]# parted /dev/md0 print
Model: Linux Software RAID Array (md)
Disk /dev/md0: 24.0TB
Sector size (logical/physical): 512B/4096B
Partition Table: gpt
Disk Flags: 

Number  Start   End     Size    File system  Name     Flags
 1      3146kB  24.0TB  24.0TB               primary
 ```
 
### LVM
#### Start by creating the target volume group
```vgcreate STORAGE /dev/md0p1```
```
[root@filer01 ~]# vgs
  VG      #PV #LV #SN Attr   VSize   VFree
  STORAGE   2   1   0 wz--n- <21.95t    0 
```
#### Add cache device to target VG
```vgextend STORAGE /dev/sda3```
```
[root@filer01 ~]# pvs
  PV         VG      Fmt  Attr PSize   PFree
  /dev/sda3  STORAGE lvm2 a--  120.04g    120.04g 
```
#### Create target logical volume to be cached
```lvcreate -l 100%PVS -n 0 STORAGE /dev/md0p1```
```
[root@filer01 ~]# lvs
  LV   VG      Attr       LSize  Pool    Origin    Data%  Meta%  Move Log Cpy%Sync Convert
  0    STORAGE -wi-ao---- 21.83t            
```
#### Subtract size of metadata from target LV.
##### ( about 1% of cache device size )
```lvreduce -L 128M STORAGE/0```
#### Create metadata on cache device
```lvcreate -L 128m -n meta STORAGE /dev/sda3```
#### Allocate remainder of space on cache device for data.
##### value is in extents.  Find this number with `pvdisplay`
```
[root@filer01 ~]# pvdisplay /dev/sda3
  --- Physical volume ---
  PV Name               /dev/sda3
  VG Name               STORAGE
  PV Size               <120.05 GiB / not usable <4.84 MiB
  Allocatable           yes (but full)
  PE Size               4.00 MiB
  Total PE              30731
  Free PE               30699
  Allocated PE          32
  PV UUID               Oet6UE-Hijg-jwDg-y4Ni-9xuP-TfjD-bTVxAx
```
```lvcreate -l 30699 -n cache STORAGE /dev/sda3```
#### Assign the cache and metadata to cache-pool for VG
```lvconvert --type cache-pool --poolmetadata STORAGE/meta STORAGE/cache```
#### Assign cache-pool to target LV
```lvconvert --type cache --cachepool STORAGE/cache STORAGE/0```
```
[root@filer01 ~]# lvs
  LV   VG      Attr       LSize  Pool    Origin    Data%  Meta%  Move Log Cpy%Sync Convert
  0    STORAGE Cwi-a-C--- 21.83t [cache] [0_corig] 0.00   5.96            0.00            
  home centos  -wi-ao----  2.00g                                                          
  root centos  -wi-ao---- 25.00g                                                          
  swap centos  -wi-ao----  1.00g                       
```
### XFS
#### xfsprogs > 3.1.0 should auto-detect the underlying device and align/optimize appropriately.

```
  [root@filer01 ~]# yum list installed | grep xfsprogs
xfsprogs.x86_64                   4.5.0-12.el7               @anaconda        
```
#### Test to make sure mkfs.xfs will create an optimized filesystem.
#### I'm really just seeing if these all generate the same parameters.

##### LVM DEVICE
```
[root@filer01 ~]# mkfs.xfs -N /dev/STORAGE/0 
meta-data=/dev/STORAGE/0         isize=512    agcount=32, agsize=183137024 blks
         =                       sectsz=4096  attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=5860384768, imaxpct=5
         =                       sunit=256    swidth=768 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=521728, version=2
         =                       sectsz=4096  sunit=1 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
```

##### SW RAID DEVICE
```
[root@filer01 ~]# vgchange -an STORAGE; mkfs.xfs -f -N /dev/md0p1 
meta-data=/dev/md0p1             isize=512    agcount=32, agsize=183138304 blks
         =                       sectsz=4096  attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=5860419072, imaxpct=5
         =                       sunit=256    swidth=768 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=521728, version=2
         =                       sectsz=4096  sunit=1 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
```

##### SW RAID DEVICE WITH FORCED STRIPE/CHUNK/WIDTH
```
[root@filer01 ~]# mkfs.xfs -N -f -d su=1024k,sw=3 /dev/md0p1
meta-data=/dev/md0p1             isize=512    agcount=32, agsize=183138304 blks
         =                       sectsz=4096  attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=5860419072, imaxpct=5
         =                       sunit=256    swidth=768 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=521728, version=2
         =                       sectsz=4096  sunit=1 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
```
#### Re-activate the Volume Group and create the filesystem.
```vgchange -ay STORAGE ```

```mkfs.xfs -L STORAGE0 /dev/STORAGE/0```

#### Create fstab entry
```
 LABEL=STORAGE0  /media/STORAGE0 xfs defaults,nobarrier,noatime,nodiratime,discard,noexec 0 0
```
