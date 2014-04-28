MAKEFLAGS += --no-builtin-rules --output-sync=target --jobs 8 --max-load 3.5
.SUFFIXES:

CONFIG := Makefile.config
include $(CONFIG)
NOW := $(shell date +%FT%T%Z)
EXPIRE_CACHE := $(shell [[ ! -e cache/.run || -n `find cache/.run $(MAX_AGE_TO_CACHE) 2>/dev/null` ]] && touch cache/.run 2>/dev/null )

.INTERMEDIATE:	cache/%.csv
.PRECIOUS:	cache/%.csv
.PHONY:		clean distclean mrproper all expire cache out publish view
all:	out

cache:	$(LIVE_SENSORS:%=cache/%.csv)
out:	$(LIVE_SENSORS:%=out/%.png) out/index.html out/nGeigie_map.png

publish:	out
	@$(PUBLISH_CMD)

view:	out
	@$(VIEW_CMD)

cache/ out/ tmp/:
	@mkdir -p $@

cache/.run:	cache/
	@$(shell [[ ! -e cache/.run || -n `find cache/.run $(MAX_AGE_TO_CACHE) 2>/dev/null` ]] && touch cache/.run 2>/dev/null )

cache/%.csv:	cacher.pl cache/.run | cache/
	@echo "Fetching data to fill $@ ..."
	@./cacher.pl $(basename $(notdir $@)) $(PLOT_SINCE)

out/%.png:	cache/%.csv timeplot.gpl $(CONFIG) | out/ tmp/
	@echo "Plotting $@ ..."
	@gnuplot -e "ID=$(basename $(notdir $@)); PERIOD_START=$(PLOT_SINCE);" ./timeplot.gpl

out/ALL.png:	$(LIVE_SENSORS:%=out/%.png) timeplot_all.gpl | out/ tmp/
	@echo "Plotting $@ ..."
	@gnuplot -e "IDs='$(LIVE_SENSORS)'; PERIOD_START=$(PLOT_SINCE);" ./timeplot_all.gpl

out/nGeigie_map.png:	in/nGeigie_map.png | out/
	@cp -a $< $@

out/index.html:	in/index.header in/index.footer $(LIVE_SENSORS:%=out/%.png) out/ALL.png | out/
	@echo "Compiling $@ ..."
	@{ \
		cat in/index.header; \
		perl -e 'my $$q="\""; for my $$id (@ARGV) { print "\t\t\t", "<a href=$${q}https://api.safecast.org/en-US/devices/$${id}/measurements$${q}><img src=$${q}$${id}.png$${q} alt=$${q}Sensor_$${id}_data$${q} /></a>\n";}' $(LIVE_SENSORS); \
		cat in/index.footer |perl -pe 's#__PUT__DATE__HERE__#$(NOW)#;'; \
	} >$@



clean:
	@rm -rf cache/* tmp/*
	@echo -ne "clean:\tdone.\n"

distclean:	clean
	@rm -rf out/*
	@echo -ne "distclean:\tdone.\n"

force:
	@touch cache/*

mrproper:	distclean
	@rm -rf cache/ tmp/ out/
	@test ! -e $(CONFIG) || { rm -i $(CONFIG); exit 0; }
	@echo -ne "mrproper:\tdone.\n"
