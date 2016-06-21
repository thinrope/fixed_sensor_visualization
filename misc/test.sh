#!/bin/bash

DEVELOPMENT="https://dev.safecast.org"
STAGING="http://api-staging.safecast.org"
PRODUCTION="https://api.safecast.org"
UNDER_TEST="${STAGING} ${PRODUCTION}"

URL1="en-US/devices/132/measurements.csv?unit=cpm&since=28%2F08%2F2015+10%3A11%3A16&until=28%2F08%2F2015+11%3A11%3A16"
URL2="en-US/measurements.csv?device_id=132&unit=cpm&since=28%2F08%2F2015+10%3A11%3A16&until=28%2F08%2F2015+11%3A11%3A16"

for H in ${UNDER_TEST}
do
	for URL in ${URL1} ${URL2}
	do
		echo -ne "${H}/${URL}\n\t trying to get 12 records + 1 header for device 132 on 2015-08-28 ..."
		wget -q "${H}/${URL}" -O - |wc -l|fgrep -q 13
		if [ $? -eq 0 ]
		then
			echo " OK."
		else
			echo " FAILED!!!"
			echo " FAILED!!!" >&2
		fi
	done
done

# Check same results for URL1/URL2
	
for H in ${UNDER_TEST}
do
	echo -ne "${H}\n\t comparing 2 URLs"
	(wget -q "${H}/${URL1}" -O - |md5sum -; wget -q "${H}/${URL2}" -O - |md5sum - )|sort -u |wc -l |grep -q ^1\$ 
	if [ $? -eq 0 ]
	then
		echo " OK."
	else
		echo " FAILED!!!"
		echo " FAILED!!!" >&2
	fi
done
