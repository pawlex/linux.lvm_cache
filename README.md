# linux.lvm_cache
## Notes from creating SSD cached LV
- CentOS 7
- 4x 8TB HDD's in Software RAID-5 (md0p1)
- 1x 160GB INTEL SSD (sda3)

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
  
