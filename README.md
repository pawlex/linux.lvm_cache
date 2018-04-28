# linux.lvm_cache
## Notes from creating SSD cached LV
### CentOS 7
- 4x 8TB HDD's in Software RAID-5 (md0p1)
- 1x 160GB INTEL SSD (sda3)

## RAID

```mdadm --create md0 --level=5 --raid-devices=4 --chunk=1024 /dev/sdb1 /dev/sdc1 /dev/sdd1 /dev/sde1 ```

```
[root@filer01 ~]# cat /proc/mdstat 
Personalities : [raid6] [raid5] [raid4] 
md0 : active raid5 sde1[4] sdd1[2] sdc1[1] sdb1[0]
      23441682432 blocks super 1.2 level 5, 1024k chunk, algorithm 2 [4/3] [UUU_]
      [=======>.............]  recovery = 37.9% (2963739448/7813894144) finish=505.9min speed=159773K/sec
      bitmap: 22/59 pages [88KB], 65536KB chunk

unused devices: <none>
```


```mkdir -p /etc/mdadm; mdadm --examine --scan >> /etc/mdadm/mdadm.conf ```
```ARRAY /dev/md/md0  metadata=1.2 UUID=d481b838:b49ebcb3:570b9a28:03a7350e name=vz03.pdxhosting.net:md0 ```


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
