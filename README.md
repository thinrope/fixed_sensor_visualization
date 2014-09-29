fixed_sensor_visualization
==========================

A (web-based) visualization for fixed sensor (radiation) data.

See full example at http://gamma.tar.bz/nGeigies/

A slightly modified version of this code is making the graphs on http://realtime.safecast.org/

# Description

A collection of scripts and settings to visualize data from fixed sensors. Initial scope is limited to Safecast nGegie sensors - fixed radiation sensors.

# Prerequisites

The following is my development environment, so it is (kind of) guaranteed to work in it.
* A recent Linux distro (I use [Gentoo](http://gentoo.org/))
* [GNU make](https://www.gnu.org/software/make/) {>=3.82}
* [GNUplot](http://gnuplot.info/) {>=4.6.4}
* [Perl](http://perl.org/) {>=5.16.3}
	* [DateTime::Format::ISO8601](http://search.cpan.org/~jhoblitt/DateTime-Format-ISO8601-0.08/) {>=0.0.8}

# Usage
Make sure you have EDITOR envvar defined (or simply edit Makefile.config with your favorite text editor)

```bash
cp -a Makefile.config{.EXAMPLE,} && ${EDITOR} Makefile.config
make view
make publish
```

# Architecture

* Local configuration (API endpoint, sensor IDs to plot, graphs color&size, etc.) is stored in *Makefile.config*, edit to suit your needs.

* Four sub-directories are used/created:
  * *in*: some static input data (HTML templates, etc.), updated from the repo when you do **git pull**, etc.
  * *cache*: dynamic data (each sensor readings, metadata, etc.), downloaded/refreshed and further processed (via *make* -> *cacher.pl* invocation)
  * *tmp*: temporary data (averaged readings, plot titles, etc.), produced via *make* -> *gnuplot* -> *timeplot_all.gpl*
  * *out*: final local mirror of what gets published to the server

* The usual **make publish** workflow is as follows (see inside *Makefile* for other targets/details):
  * invoke **gnuplot** to execute *timeplot.gpl* and produce each individual sensor graphs (e.g. *out/40.png* and *out/40_small.png*) as well as data for all-sensor-graphs (inside *tmp*)
  * invoke **gnuplot** to execute *timeplot_all* and produce all-sensor-graphs (*out/LIVE.png* and *out/TEST.png*)
  * parse HTML templates to produce the final output *out/index.html* and *out/TEST.html*
  * publish the results on a server (see PUBLISH_CMD inside *Makefile.conf*)
