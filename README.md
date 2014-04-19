fixed_sensor_visualization
==========================

A (web-based) visualization for fixed sensor (radiation) data.
See example at http://gamma.tar.bz/nGeigies/

# Description

A collection of scripts and settings to visualize data from fixed sensors. Initial scope is limitted to Safecast nGegie sensors - fixed radiation sensors.

# Prerequisites

The following is my development environment, so it is (kind of) guaranteed to work in it.
* A recent Linux distro (I use [Gentoo](http://gentoo.org/))
* [GNU make](https://www.gnu.org/software/make/) {>=3.82}
* [GNUplot](http://gnuplot.info/) {>=4.6.4}
* [Perl](http://perl.org/) {>=5.16.3}
	* [DateTime::Format::ISO8601](http://search.cpan.org/~jhoblitt/DateTime-Format-ISO8601-0.08/) {>=0.0.8}

# Usage
```bash
cp -a Makefile.config{.EXAMPLE,} && ${EDITOR} Makefile.config
make view
make publish
```
