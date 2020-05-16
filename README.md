# Disk-Sanitizer
A tool which can wipe any or all attached disks based on include and exclude device name filters

This was designed as a disk data wiper for Solaris, which at the time, did not have a good way to purge data from all disks.

It was inteneded to be executed from a network boot (available from the miniroot). Nowadays, you can boot from a USB device to execute the tool.

The "normal" method uses Solaris native format/analyze/purge to perform a NIST standard data wipe.
The "fast" method uses a 3 pass of writes: 1) all zeros, 2) 64k random data writes 3) 128k random data writes. It is significantly faster than the NIST
Standard, and it should be "good enough".

# Usage
  disk_sanitizer.sh [-x none|disks] [-i disks] [-p] [-f]
  
  By default all disks detected at boot time are selected for data wipe. You can change this by manipulating the -i (include) and -x (exclude) filters.
  For example, to inlcude all the disks on controller 0, but exclude only c0t7d0, and all the devices on c8; then:
  '''disk_sanitizer.sh -i c0 -x c0t7d0 -x c8'''
  
  -f toggles to use the Fast Method
  
  -p automatically powers off the server at the completion of the data wipe


