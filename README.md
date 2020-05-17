# Disk-Sanitizer
A tool which can wipe any or all attached disks based on include and exclude device name filters. This was designed as a disk data wiper for Solaris, which at the time, did not have a good way to purge data from all disks. (OK, let's be honest -- it still doesn't.) It will work with local (internal SAS/SCSI) disks, SAN storage, SSD Cards, and NVME devices.

It purges data in parallel on all selected disk devices. It will fork off the desired purge method for each device and execute the data wipe on each device independently. Have a server with hundreds of disks? Not a problem!
As long as you have the IO bandwidth, it will do the job in the most efficient way possible.

It was intended to be executed from a network boot (available from the miniroot). Nowadays, you can boot from a USB device to execute the tool, or from an NFS or CIFS, share, or whatever you like.

The "normal" method uses Solaris native [format\(8\)](https://docs.oracle.com/cd/E88353_01/html/E72487/format-8.html) `analyze/purge` function to perform a NIST Guidelines for Media Sanitization (NIST SP 800-88) compliant data wipe. The downside to this method is that it is extremely slow.

The "fast" method uses a 3 pass of writes: 1) wite all zeros, 2) 64k blocksize urandom data overwrite 3) 128k blocksize urandom data overwrite. It is significantly faster than the NIST Standard, and it should be "good enough".

## Usage
  `disk_sanitizer.sh [-x none|disks] [-i disks] [-p] [-f]`
  
  `-i`   optional include device filter
  `-x`   optional exclude device filter
  `-f`   option to toggle to use the Fast Method
  `-p`   option to automatically power off the server at the completion of the data wipe
  
  **By default all disks detected at boot time are selected for data wipe.**
  You can change this by manipulating the -i (include) and -x (exclude) filters.
  For example, to include all the disks on controllers 0 and 7, but exclude a specific device 0t7d0, and all the devices on controller 8; then:
  
```
  disk_sanitizer.sh -i c0 -i c7 -x c0t7d0 -x c8
```
  
### Caution
** This wll cause data loss!***
It is expressly designed to do so. Verify the disk list output confirmation before allowing the tool to proceed.
Signal 15 (control C) is trapped and will kill all forked sub shells, so as to preserve your sanity.
