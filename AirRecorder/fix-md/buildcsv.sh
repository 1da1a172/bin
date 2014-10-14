#!/usr/bin/bash
unset apname
unset master
unset servername
unset serverip
lms=cas-wlc-1.cns.vt.edu

for apname in `grep '///// Command: show ap provisioning ap-name' ${lms}-aps.txt | cut -d\  -f 7`; do
#	echo $apname
	master=`grep $apname ${lms}-aps.txt -A 2 | grep \^Master | sed 's/\ \ */\ /g' | cut -d\  -f 2 | sed 's/\r//g'`
	servername=`grep $apname ${lms}-aps.txt -A 3 | grep \^Server\ Name | sed 's/\ \ */\ /g' | cut -d\  -f 3 | sed 's/\r//g'`
	serverip=`grep $apname ${lms}-aps.txt -A 4 | grep \^Server\ IP | sed 's/\ \ */\ /g' | cut -d\  -f 3 | sed 's/\r//g'`
	echo $apname,$master,$servername,$serverip >> ${lms}-aps.csv
done

