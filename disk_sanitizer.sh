#!/bin/bash
## Joe Nyilas
## 11/01/09
## Solaris Mass LUN/Disk ERASER
## Suitable for placement into Jumpstart or WANBOOT miniroot

# $Id: disk_sanitizer,v 1.4 2020/05/11 19:09:59 jnyilas Exp $
# $Log: disk_sanitizer,v $
# Revision 1.4  2020/05/11 19:09:59  jnyilas
# Fixed reporting of selected devices so that it is clear which devices will be scrubbed.
# Added power off option.
#
# Revision 1.3  2020/05/11 14:55:46  jnyilas
# Added EFI support.
#
# Revision 1.2  2020/05/11 14:22:17  jnyilas
# Added Fast Method
# Changed scrub routines to functions
#

# *** EFI FAQ ***
#The EFI disk label differs from the VTOC disk label in the following ways:

#    Provides support for disks greater than 2 terabytes in size.

#    Provides usable slices 0-6, where slice 2 is just another slice.

#    Partitions (or slices) cannot overlap with the primary or backup label,
#    nor with any other partitions. The size of the EFI label is usually 34
#    sectors, so partitions usually start at sector 34. This feature means
#    that no partition can start at sector zero (0).

#    No cylinder, head, or sector information is stored in the EFI label.
#    Sizes are reported in blocks.

#    Information that was stored in the alternate cylinders area, the last
#    two cylinders of the disk, is now stored in slice 8.

#    The EFI specification prohibits overlapping slices.
#    !! The entire disk is represented by cxtydz. !!

PATH=/bin:/sbin:/usr/sbin
pid_list=""
trap 'echo ""
echo "=======>  `basename $0` aborted <======="
echo ""
if [[ -n "${pid_list}" ]]; then
	kill ${pid_list}
fi
exit 1' 1 2 3 15


usage()
{
echo "Usage `basename $0` [-x none|disks] [-i disks] [-p]" 1>&2
echo "Usage `basename $0` [-f ] enables fast mode" 1>&2
echo "Usage `basename $0` [-p ] Power Off server after completion" 1>&2
echo "" 1>&2
}

efi_check()
{
	# Is this EFI?
	# If yes, the whole disk is just the LUN.
	# If not (SMI), the whole disk is s2.
	chk=`prtvtoc -h /dev/dsk/${disk}s2 | grep "^ *8 "`
	if [[ -n "${chk}" ]]; then
		#EFI
		echo "   --> EFI Partition ${disk}"
		slice=""
	else
		#SMI
		echo "   --> SMI Partition ${disk}"
		slice="s2"
	fi
}


fast_method()
{
	efi_check
	echo "The above disk(s) will be sanitized with the
3x random data rewrite method for overwriting data.
This is much faster than the NIST standard, but does not meet
Department of Defense guidelines for media sanitization.
"
	# rewrite zero pass 1
	dd if=/dev/zero of=/dev/rdsk/${disk}${slice} bs=1024k > /dev/null 2>&1
	#rewrite the label
	format /dev/rdsk/${disk}${slice}<<EOF > /dev/null
label
y
q
EOF
	echo "Disk ${disk} pass 1/3 completed."

	# rewrite random pass 2
	#rescan device because it has a new label
	efi_check
	dd if=/dev/urandom of=/dev/rdsk/${disk}${slice} obs=128k > /dev/null 2>&1
	#rewrite the label
	format /dev/rdsk/${disk}${slice}<<EOF > /dev/null
label
y
q
EOF
	echo "Disk ${disk} pass 2/3 completed."

	# rewrite random pass 3
	#rescan device because it has a new label
	efi_check
	dd if=/dev/urandom of=/dev/rdsk/${disk}${slice} obs=64k > /dev/null 2>&1
	#rewrite the label
	format /dev/rdsk/${disk}${slice}<<EOF > /dev/null
label
y
q
EOF
	echo "Disk ${disk} pass 3/3 completed."
	echo ""
}


std_method()
{
	efi_check
	echo "The above disk(s) will be sanitized with the
NCSC-TG-025 algorithm for overwriting data.
This meets or exceeds NIST guidelines for media sanitization.
"
	format /dev/rdsk/${disk}${slice}<<EOF
analyze
purge
y
q
EOF
}

#Parse arguments
EXCLUDE=""
INCLUDE=""
FAST=0
POWEROFF=0
while getopts pfi:x: o; do
case ${o} in
	x)	EXCLUDE="${EXCLUDE} ${OPTARG}"		
		if [[ "${EXCLUDE}" = "none" ]]; then
			echo "Not excluding any disks!"
			EXCLUDE=""
		fi
		;;
	i)	INCLUDE="${INCLUDE} ${OPTARG}"
		;;
	f)	FAST=1
		;;
	p)	POWEROFF=1
		;;
	*)	usage
		exit 0
		;;
esac
done
shift `expr $OPTIND - 1`

#set the rewrite method
if [[ ${FAST} -eq 1 ]]; then
	method=fast_method
else
	method=std_method
fi

echo "--> Generating Disk list..."
drvs_all=`format < /dev/null | awk '{print $2}' | grep c[0-9][0-9]*`
#Process Includes
if [[ -n "${INCLUDE}" ]]; then
	#include listed disks
		drvs=""
	for i in ${INCLUDE}; do
		echo " -- ${i} included"
		drvs="${drvs}
`echo "${drvs_all}" | grep "${i}"`"
	done
else
	# select all disks
	drvs="${drvs_all}"
fi

#Process Excludes
xtotal=0
if [[ -n "${EXCLUDE}" ]]; then
	#exclude listed disks
	for i in ${EXCLUDE}; do
		echo " -- ${i} excluded"
		xcnt=`echo "${drvs}" | grep "${i}" | wc -l`
		drvs=`echo "${drvs}" | grep -v "${i}"`
		xtotal=$(( ${xtotal} + ${xcnt} ))
	done
fi

a_cnt=`echo "${drvs_all}" | wc -w | awk '{print $1}'`
cnt=`echo "${drvs}" | wc -w | awk '{print $1}'`
x_cnt=`echo "${EXCLUDE}" | wc -w | awk '{print $1}'`
i_cnt=`echo "${INCLUDE}" | wc -w | awk '{print $1}'`

printf -- "--> %5d total devices found\n" "${a_cnt}"
if [[ "${i_cnt}" -eq 0 ]]; then
	printf -- "-->       All devices and paths included\n"
else
	printf -- "--> %5d devices||paths included\n" "${i_cnt}"
fi
printf -- "--> %5d devices||paths excluded\n" "${x_cnt}"
printf -- "--> %5d actual devices excluded\n" "${xtotal}"
printf -- "--> %5d devices selected\n" "${cnt}"
echo ""
echo "--> Final Device Selections:"
echo "${drvs}"

if [[ "${cnt}" -eq 0 ]]; then
	echo "Nothing to do!"
	echo ""
	exit 0
fi

echo ""
echo "**** ALL DATA ON ALL LISTED DISKS WILL BE DESTROYED ****"
echo "**** IN 60 SECONDS. HALT OR INTERRUPT THIS PROCESS    ****"
echo "****          NOW TO PRESERVE YOUR DATA.              ****"
echo ""
echo "CTRL-C to Interrupt ..."

sleep 65
#The Bell
echo "\07 \07 \07 \07 \07 \07 \07 \07"
for i in 10 9 8 7 6 5 4 3 2 1; do
	sleep 1
	echo "PURGING ALL DATA in $i ... \r\c"
	sleep 1
done
#debug
#read q

echo ""
for disk in ${drvs}; do
	echo "--> Processing $disk <--"
	${method} &
	pid_list="$! ${pid_list}"
done

wait

echo ""
echo "Data Purge Completed"
if [[ "${POWEROFF}" -eq 1 ]]; then
	echo "Powering off system now"
	init 5
fi

exit 0
