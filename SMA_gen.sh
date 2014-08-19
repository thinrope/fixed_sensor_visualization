#!/bin/bash

#
# Generates SMA code for gnuplot
# copy inside gnuplot, then use like:
# plot e=sma_6_init(0), "some_data" u 1:(sma_6($2)
#
LF="-n"		# "-n" for single line, "" for multiline
N=${1:-6}	# 6-bin by default
if (( ${N} <= 1 ))
then
	echo "ERROR: argument must be between 2 and 53"
	exit
elif (( ${N} <= 27 ))
then	# 2=>a, 3=>b, .. ,27=>z
	P=$(printf \\$(printf "%o" $((95+${N}))))
elif (( ${N} <= 53 )) # 28=>A, 29=>B, .. ,53=>Z
then
	P=$(printf \\$(printf "%o" $((65 - 28 + ${N}))))
else
	echo "ERROR: argument must be between 2 and 53"
	exit
fi
	
	

echo -n "sma_${N}_init(x) = ("; for i in $(seq ${N} -1 2); do echo -n "${P}$i="; done; echo $LF "${P}1=x);"
echo -n "sma_${N}_shift(x) = ("; for i in $(seq ${N} -1 2); do echo -n "${P}$i=${P}$(($i - 1)), "; done; echo $LF "${P}1=x);"; 
echo $LF "sma_${N}_samples(x) = \$0 > $(( ${N} - 1)) ? ${N} : (\$0+1);";
echo -n "sma_${N}(x) = (sma_${N}_shift(x), ("; for i in $(seq ${N} -1 2); do echo -n "${P}$i+"; done; echo $LF "${P}1)/sma_${N}_samples(\$0) );";
echo
