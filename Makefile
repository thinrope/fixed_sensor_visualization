MAKEFLAGS += --no-builtin-rules --output-sync=target --jobs 8 --max-load 3.5
.SUFFIXES:

CONFIG := Makefile.config
include $(CONFIG)

NOW := $(shell TZ=$(CONFIG_TIMEZONE) date +%FT%T%z)
PERIOD_START := $(shell TZ=$(CONFIG_TIMEZONE) date +%FT%T%Z --date=$(PLOT_FROM))
PERIOD_END := $(shell TZ=$(CONFIG_TIMEZONE) date +%FT%T%Z --date=$(PLOT_TO))

VERSION := $(shell git log -n 1 --pretty=format:"%h" 2>/dev/null)
HOST := $(shell hostname)
SOURCE_STATUS := $(shell git_status=$$(git status --porcelain); if test -n "$${git_status}"; then echo " +α"; fi)
EXPIRE_CACHE := $(shell [[ ! -e cache/.run || -n `find cache/.run $(MAX_AGE_TO_CACHE) 2>/dev/null` ]] && touch cache/.run 2>/dev/null )

SYNC_CMD2 := wget -q 'http://realtime.safecast.org/wp-content/uploads/devices.json' -O cache/devices.json
SYNC2 := $(shell [[ ! -e cache/devices.json || -n `find cache/devices.json $(MAX_AGE_TO_CACHE) 2>/dev/null` ]] && $(SYNC_CMD2) 2>/dev/null )

LIVE_SENSORS ?= $(shell cat in/nGeigie_map.csv |cut -d, -f1,4 |fgrep fixed_sensor |cut -d, -f1 |sort -n |xargs echo)
TEST_SENSORS ?= $(shell cat in/nGeigie_map.csv |cut -d, -f1,4 |fgrep TEST_sensor  |cut -d, -f1 |sort -n |xargs echo)
DEAD_SENSORS ?= $(shell cat in/nGeigie_map.csv |cut -d, -f1,4 |fgrep DEAD_sensor  |cut -d, -f1 |sort -n |xargs echo)
KNOWN_SENSORS := $(shell for s in $(LIVE_SENSORS) $(TEST_SENSORS) $(DEAD_SENSORS); do echo $$s; done |sort -n |xargs echo)

RSO_SENSORS := $(shell cat cache/devices.json |perl -ne 'print "$$1\n" while (/\"id":"(\d+)"/g)' |sort -n |xargs echo)
NODATA_SENSORS := $(shell for s in $(DEAD_SENSORS) $(RSO_SENSORS); do echo "$(LIVE_SENSORS) $(TEST_SENSORS)" |fgrep -w -q $$s || echo $$s; done |xargs echo)

NEVERBEFOREHEARD_SENSORS := $(shell for s in $(RSO_SENSORS); do echo "$(KNOWN_SENSORS)" |fgrep -w -q $$s || echo $$s; done |sort -n  >tmp/to_add; cat tmp/to_add |xargs echo)

GNUPLOT_VARS := \
	CONFIG_WIDTH_SMALL=$(CONFIG_WIDTH_SMALL); CONFIG_WIDTH_BIG=$(CONFIG_WIDTH_BIG); CONFIG_WIDTH_ALL=$(CONFIG_WIDTH_ALL); \
	CONFIG_HEIGHT_SMALL=$(CONFIG_HEIGHT_SMALL); CONFIG_HEIGHT_BIG=$(CONFIG_HEIGHT_BIG); CONFIG_HEIGHT_ALL=$(CONFIG_HEIGHT_ALL); \
	PERIOD_START='$(PERIOD_START)'; PERIOD_END='$(PERIOD_END)'; CONFIG_TZ=$(CONFIG_TZ); CONFIG_TIMEZONE=$(CONFIG_TIMEZONE);

.INTERMEDIATE:	cache/%.csv daily/%.csv
.PRECIOUS:	cache/%.csv daily/%.csv
.PHONY:		clean distclean mrproper all expire cache out daily publish view printvars bootstrap test print_current_online
all:	out nodata	| bootstrap

bootstrap:	cache/devices.json
cache:	$(LIVE_SENSORS:%=cache/%.csv) $(TEST_SENSORS:%=cache/%.csv) | bootstrap
out:	$(LIVE_SENSORS:%=out/%.png) $(TEST_SENSORS:%=out/%.png) out/LIVE.png out/TEST.png out/index.html out/window.html out/TEST.html out/tilemap.png	| cache out/
daily:	$(TEST_SENSORS:%=daily/%.png)	| cache daily/


publish:	crush
	@$(PUBLISH_CMD)

nodata:	out/
	# FIXME: This is a HACK, slightly improved...
	@echo "Hack around sensors with no data ($(NODATA_SENSORS))..."
	$(shell for s in $(NODATA_SENSORS); do gnuplot -e "ID=$$s; $(GNUPLOT_VARS)" ./nodata.gpl; done )

crush:	out nodata
	@echo "Crushing PNGs..."
	@pngcrush -q -oldtimestamp -ow out/*png
	@echo "done."

view:	out
	@$(VIEW_CMD)

out/ tmp/ daily/:
	@mkdir -p $@

cache/.run:
	@$(shell [[ ! -e cache/.run || -n `find cache/.run $(MAX_AGE_TO_CACHE) 2>/dev/null` ]] && touch cache/.run 2>/dev/null )

cache/%.csv:	cacher.pl cache/.run ${CONFIG}
	@echo "Fetching data to fill $@ ..."
	@./cacher.pl $(basename $(notdir $@)) $(PLOT_FROM) $(PLOT_TO) $(CONFIG_TIMEZONE) $(CONFIG_TZ) $(CONFIG_SMA1) $(CONFIG_SMA2)
	@echo -e "\t$@ fetched."

cache/devices.json:	cache/.run ${CONFIG}
	@echo "Fetching data for $@ ..."
	@$(SYNC_CMD2)
	@echo -e "\t$@ fetched."

out/%.png:	cache/%.csv in/nGeigie_map.csv timeplot.gpl $(CONFIG) | out/ tmp/
	@echo "Plotting $@ ..."
	-@gnuplot -e "ID=$(basename $(notdir $@)); $(GNUPLOT_VARS)" ./timeplot.gpl
	@head -n3 tmp/$(basename $(notdir $@)).data |tail -n1|perl -ne '/"(.*)"/; print "$$1\n"' >tmp/$(basename $(notdir $@)).title
	@echo -e "\t$@ plotted."

out/LIVE.png:	$(LIVE_SENSORS:%=out/%.png) timeplot_all.gpl ${CONFIG} | out/ tmp/
	@echo "Plotting $@ ..."
	@gnuplot -e "OUTFILE='$@'; IDs='$(LIVE_SENSORS)'; $(GNUPLOT_VARS)" ./timeplot_all.gpl
	@echo -e "\t$@ plotted."

out/TEST.png:	$(TEST_SENSORS:%=out/%.png) timeplot_all.gpl ${CONFIG} | out/ tmp/
	@echo "Plotting $@ ..."
	@gnuplot -e "OUTFILE='$@'; IDs='$(TEST_SENSORS)'; $(GNUPLOT_VARS)" ./timeplot_all.gpl
	@echo -e "\t$@ plotted."

out/tilemap.png:	in/tilemap.png ${CONFIG} | out/
	@cp -a $< $@

out/index.html:	in/index.header in/index.footer $(LIVE_SENSORS:%=out/%.png) out/LIVE.png ${CONFIG} | out/
	@echo "Compiling $@ ..."
	@{ \
		cat in/index.header; \
		perl -e 'my $$q="\""; for my $$id (@ARGV) { open(IN, "<cache/$${id}.URL") or die; $${URL} = do {local $$/; <IN>}; $${URL} =~ s/\.csv//; close(IN) or die; print "\t\t\t", "<a href=$${q}$${URL}$${q}><img style=$${q}padding: 0;$${q} src=$${q}$${id}.png$${q} alt=$${q}Sensor_$${id}_data$${q} width=$${q}$(CONFIG_WIDTH_BIG)$${q} height=$${q}$(CONFIG_HEIGHT_BIG)$${q} /></a>\n";}' $(LIVE_SENSORS); \
		cat in/index.footer |perl -pe 's#__PUT__DATE__HERE__#$(NOW) at $(HOST) [<a href="https://github.com/thinrope/fixed_sensor_visualization/commit/$(VERSION)">$(VERSION)</a>$(SOURCE_STATUS)]#;'; \
	} >$@
	@echo -e "\t$@ compiled."

out/window.html:	in/index.header in/index.footer $(LIVE_SENSORS:%=out/%.png) out/LIVE.png ${CONFIG} | out/
	@echo "Compiling $@ ..."
	@{ \
		cat in/index.header; \
		perl -e 'my $$q="\""; for my $$id (@ARGV) { open(IN, "<cache/$${id}.URL") or die; $${URL} = do {local $$/; <IN>}; $${URL} =~ s/\.csv//; close(IN) or die; print "\t\t\t", "<a href=$${q}$${URL}$${q}><img style=$${q}padding: 0;$${q} src=$${q}$${id}_window.png$${q} alt=$${q}Sensor_$${id}_update_window$${q} width=$${q}$(CONFIG_WIDTH_BIG)$${q} height=$${q}$(CONFIG_HEIGHT_BIG)$${q} /></a>\n";}' $(LIVE_SENSORS); \
		cat in/index.footer |perl -pe 's#__PUT__DATE__HERE__#$(NOW) at $(HOST) [<a href="https://github.com/thinrope/fixed_sensor_visualization/commit/$(VERSION)">$(VERSION)</a>$(SOURCE_STATUS)]#;'; \
	} >$@
	@echo -e "\t$@ compiled."

out/TEST.html:	in/TEST.header in/index.footer $(TEST_SENSORS:%=out/%.png) out/TEST.png ${CONFIG} | out/
	@echo "Compiling $@ ..."
	@{ \
		cat in/TEST.header; \
		perl -e 'my $$q="\""; for my $$id (@ARGV) { open(IN, "<cache/$${id}.URL") or die; $${URL} = do {local $$/; <IN>}; $${URL} =~ s/\.csv//; close(IN) or die; print "\t\t\t", "<a href=$${q}$${URL}$${q}><img src=$${q}$${id}.png$${q} alt=$${q}Sensor_$${id}_data$${q} width=$${q}$(CONFIG_WIDTH_BIG)$${q} height=$${q}$(CONFIG_HEIGHT_BIG)$${q} /></a>\n";}' $(TEST_SENSORS); \
		cat in/index.footer |perl -pe 's#__PUT__DATE__HERE__#$(NOW) at $(HOST) [<a href="https://github.com/thinrope/fixed_sensor_visualization/commit/$(VERSION)">$(VERSION)</a>$(SOURCE_STATUS)]#;'; \
	} >$@
	@echo -e "\t$@ compiled."

daily/%.csv:	cache/%.csv $(CONFIG) | daily/
	@echo "Crunching stats for $@ ..."
	@cat $< |perl -MStatistics::Descriptive  -e 'while (<>){ m#\d{4}-\d{2}-\d{2}T(\d{2}):\d{2}:\d{2}JST,([0-9.]+)#; $$A{$$1}=Statistics::Descriptive::Sparse->new() unless (defined $$A{$$1}); $$A{$$1}->add_data($$2);} print map {sprintf("%s,%0.3f,%0.3f,%d\n", $$_, $$A{$$_}->mean(), 3.0 * $$A{$$_}->standard_deviation(),$$A{$$_}->count())} sort keys %A;' >$@
	@echo -e "\t$@ done."

daily/%.png:	daily/%.csv $(CONFIG) timeplot_daily.gpl | daily/
	@echo "Plotting $@ ..."
	@gnuplot -e 'reset; set term png enhanced notransparent nointerlace truecolor butt font "Arial Unicode MS,8" size 800, 600 background "#ffffef"; set output "$@"; set datafile separator ","; set xrange [-0.5:24.5]; set xtics 0 3; set grid; set format x "%02.0f"; plot "$<" u ($$1+0.5):2 w lines lw 3 title "daily average CPM (per hour)", "" u ($$1+0.5):2:3 w yerrorbars title "3σ";'
	@echo -e "\t$@ plotted."

print_current_online:	cache/devices.json
	@{ \
		cat $< | \
		perl -ne 'print join("|", $$+{id},"$$+{lat} $$+{lon}",$$+{location},$$+{last_updated}),"\n" while (/"id":"(?<id>[0-9]+)","lat":"(?<lat>[\+\-0-9.]+)","lon":"(?<lon>[\+\-0-9.]+)","location":"(?<location>[^"]+)","updated":"(?<last_updated>\d\d\d\d-\d\d-\d\dT\d\d\:\d\d\:\d\dZ)"/g)' | \
		fgrep $$(TZ=Z date +%FT --date '1 hour ago') | \
		sort -n|column -s"|" -t; \
	}

test:
	@echo "It is $(NOW) in $(CONFIG_TIMEZONE)."
	@echo "Current version: $(VERSION)$(SOURCE_STATUS)"
	@echo -e "LIVE: $(LIVE_SENSORS)"
	@echo -e "TEST: $(TEST_SENSORS)"
	@echo -e "DEAD: $(DEAD_SENSORS)"
	@echo -e "KNOWN: $(KNOWN_SENSORS)"
	@echo
	@echo -e "RSO: $(RSO_SENSORS)"
	@echo -e "NODATA_SENSORS: $(NODATA_SENSORS)  <-- hack"
	@echo
	@echo -e "NEVERBEFOREHEARD_SENSORS: $(NEVERBEFOREHEARD_SENSORS) <-- those may need to be added to in/nGeigie_map.csv"
	@echo "Currently the following has updated recently (=live)"
	@echo
	@{ \
		cat cache/devices.json | \
		perl -ne 'print join("|", $$+{id},"$$+{lat} $$+{lon}",$$+{location},$$+{last_updated}),"\n" while (/"id":"(?<id>[0-9]+)","lat":"(?<lat>[\+\-0-9.]+)","lon":"(?<lon>[\+\-0-9.]+)","location":"(?<location>[^"]+)","updated":"(?<last_updated>\d\d\d\d-\d\d-\d\dT\d\d\:\d\d\:\d\dZ)"/g)' | \
		fgrep $$(TZ=Z date +%FT --date '1 hour ago') | \
		fgrep -w -f tmp/to_add | \
		sort -n|column -s"|" -t; \
	}
	@echo
	@echo -e "GNUPLOT_VARS: $(GNUPLOT_VARS)"

clean:
	@rm -rf cache/* tmp/* daily/*
	@echo -ne "clean:\tdone.\n"

distclean:	clean
	@rm -rf out/ daily/
	@echo -ne "distclean:\tdone.\n"

force:
	@touch cache/*

mrproper:	distclean
	@rm -rf tmp/
	@test ! -e $(CONFIG) || { rm -i $(CONFIG); exit 0; }
	@echo -ne "mrproper:\tdone.\n"

get-%:
	@$(info $($*))

printvars:
	@$(foreach V,$(sort $(.VARIABLES)), $(if $(filter-out environment% default automatic, $(origin $V)),$(info $V=$($V) )))
