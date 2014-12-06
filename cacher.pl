#!/usr/bin/perl
use warnings;
use strict;
use utf8;
use DateTime::Format::ISO8601;

die ("\n[ERROR] Invalid number of arguments[", scalar @ARGV, "]!\n\nUsage:\n\t$0 <sensor_id> <fetch_since> <fetch_until> <TIMEZONE> <TZ> <SMA_BINS1> <SMA_BINS2>\n")
	unless (scalar @ARGV == 7);
my $id = $ARGV[0];
my $fetch_since = $ARGV[1];
my $fetch_until = $ARGV[2];
my $TIMEZONE = $ARGV[3];
my $TZ = $ARGV[4];
my $SMA_BINS1 = $ARGV[5];
my $SMA_BINS2 = $ARGV[6];

die ("\n[ERROR] SMA_BINS1 must be more than SMA_BINS2\n")
	unless ($SMA_BINS1 > $SMA_BINS2);

# API server uses in UTC in query and results
my $server_TZ='UTC';

my $since_query = qx!TZ=${server_TZ} date +since=%d%%2F%m%%2F%Y+%H%%3A%M%%3A%S --date='${fetch_since}'!; chomp $since_query;
my $until_query = qx!TZ=${server_TZ} date +until=%d%%2F%m%%2F%Y+%H%%3A%M%%3A%S --date='${fetch_until}'!; chomp $until_query;
my $URL = "https://api.safecast.org/en-US/devices/$id/measurements.csv?${since_query}&${until_query}&order=captured_at+asc";
open(LOG, ">cache/$id.URL")
	or die("$! , exitting");
print LOG $URL;
close(LOG)
	or die("$! , exitting");

my $cmd = "wget -q '${URL}' -O cache/$id.tmp";
qx!$cmd!;

open(IN, "<cache/$id.tmp")
	or die("$! , exitting");
open(OUT, ">cache/$id.csv")
	or die("$! , exitting");


my @sma_bins = ();
my $t_prev = -1;
my $dt_prev = 36000;	# NOTE: Big number initially, 10h
while(<IN>)
{
	my @R = split(/,/, $_, 5);
	if ($R[0] =~ m#(\d{4}-\d\d-\d\d) (\d\d:\d\d:\d\d) ${server_TZ}#)
	{
		my $timestamp = DateTime::Format::ISO8601->parse_datetime(qq(${1}T${2}Z))->set_time_zone(${TIMEZONE});

		# calculate difference
		$t_prev = $timestamp->epoch() - 300	# defeault is 5min
			if ($t_prev == -1);
		my $dt = $timestamp->epoch() - $t_prev;
		$t_prev = $timestamp->epoch();

		push @sma_bins, $R[3];							# push in buffer
		shift @sma_bins								# trim the oldest, if buffer too big
			if (scalar(@sma_bins) > $SMA_BINS1);
		#print STDERR  join(":", $#sma_bins-11, $#sma_bins), "\t", join("\t", @sma_bins), "\n";
		my $sma1 = (eval join('+', @sma_bins)) / scalar(@sma_bins);		# eval buffer
		my $sma2 = $sma1;							# place for smaller buffer
		if (scalar(@sma_bins) > $SMA_BINS2)					# 
		{
			$sma2 = (eval join('+', @sma_bins[$#sma_bins-$SMA_BINS2 + 1 .. $#sma_bins])) / $SMA_BINS2;	# use only last $SMA_BINS2 bins, NOTE: OB1
		}

		print OUT "\n"				# print blank line, if there was missing data (for gnuplot)
			if ($dt > 5.0 * $dt_prev);
		$dt_prev = $dt;

		print OUT join(',', "${timestamp}${TZ}", $R[3], sprintf("%0.3f,%0.3f,%d\n", $sma1, $sma2, $dt));
	}
}

close(OUT)
	or die("$!, exitting");
close(IN)
	or die("$! ,exitting");
