#### Start by creating the target volume group
vgcreate STORAGE /dev/md0p1
#### Add cache device to target VG
vgextend STORAGE /dev/sda3
#### Create target logical volume to be cached
lvcreate -l 100%PVS -n 0 STORAGE /dev/md0p1
#### Subtract size of metadata from target LV.
#### ( about 1% of cache device size )
lvreduce -L 128M STORAGE/0
#### Create metadata on cache device
lvcreate -L 128m -n meta STORAGE /dev/sda3
#### Allocate remainder of space on cache device for data.
#### value is in extents.  Find this number with `pvdisplay`
lvcreate -l 30699 -n cache STORAGE /dev/sda3
#### Assign the cache and metadata to cache-pool for VG
lvconvert --type cache-pool --poolmetadata STORAGE/meta STORAGE/cache
#### Assign cache-pool to target LV
lvconvert --type cache --cachepool STORAGE/cache STORAGE/0
