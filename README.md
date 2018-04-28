# linux.lvm_cache
## Notes from creating SSD cached LV
### CentOS 7
- 4x 8TB HDD's in Software RAID-5 (md0p1)
- 1x 160GB INTEL SSD (sda3)

## RAID

[root@filer01 ~]# cat /proc/mdstat 
Personalities : [raid6] [raid5] [raid4] 
md0 : active raid5 sde1[4] sdd1[2] sdc1[1] sdb1[0]
      23441682432 blocks super 1.2 level 5, 1024k chunk, algorithm 2 [4/3] [UUU_]
      [=======>.............]  recovery = 37.9% (2963739448/7813894144) finish=505.9min speed=159773K/sec
      bitmap: 22/59 pages [88KB], 65536KB chunk

unused devices: <none>
