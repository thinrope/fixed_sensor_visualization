#!/bin/bash

#
# Generates SMA code for gnuplot
# copy inside gnuplot, then use like:
# plot e=sma_6_init(0) "some_data" u 1:(sma_6($2)
#

N=${1:-6}	# 6-bin by default
LF=${2:-" "}	# "\n" for multiline

usage()
{
	echo -ne "USAGE:\n";
	echo -ne "\t${0} [number_of_bins] [multiline?]\n"
	echo -ne "Example:\n"
	echo -ne "\t${0} 6 \"\\"; echo -ne "n\"\t\t<-- for multiline\n"
	echo -ne "\t${0} 6     \t\t<-- for single long line\n"
	exit
}

if (( ${N} <= 1 ))
then
	echo "ERROR: first argument must be between 2 and 53"
	usage
elif (( ${N} <= 27 ))
then	# 2=>a, 3=>b, .. ,27=>z
	P=$(printf \\$(printf "%o" $((95+${N}))))
elif (( ${N} <= 53 )) # 28=>A, 29=>B, .. ,53=>Z
then
	P=$(printf \\$(printf "%o" $((65 - 28 + ${N}))))
else
	echo "ERROR: first argument must be between 2 and 53"
	usage
fi
	
	

echo -ne "sma_${N}_init(x) = ("; for i in $(seq ${N} -1 2); do echo -ne "${P}$i="; done; echo -ne "${P}1=x);${LF}"
echo -ne "sma_${N}_shift(x) = ("; for i in $(seq ${N} -1 2); do echo -ne "${P}$i=${P}$(($i - 1)),"; done; echo -ne "${P}1=x);${LF}"
echo -ne "sma_${N}_samples(x) = \$0 > $(( ${N} - 1)) ? ${N} : (\$0+1);${LF}"
echo -ne "sma_${N}_RO(x) = ("; for i in $(seq ${N} -1 2); do echo -ne "${P}$i+"; done; echo -ne "${P}1)/sma_${N}_samples(\$0);${LF}"
echo -ne "sma_${N}(x) = (sma_${N}_shift(x), sma_${N}_RO(x));${LF}"
[ "${LF}" != "\n" ] && echo
