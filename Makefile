MAKEFLAGS += --no-builtin-rules --output-sync=target --jobs 8 --max-load 3.5
.SUFFIXES:

CONFIG := Makefile.config
include $(CONFIG)
NOW := $(shell TZ=$(CONFIG_TIMEZONE) date +%FT%T%Z)
VERSION := $(shell git log -n 1 --pretty=format:"%h" 2>/dev/null)
EXPIRE_CACHE := $(shell [[ ! -e cache/.run || -n `find cache/.run $(MAX_AGE_TO_CACHE) 2>/dev/null` ]] && touch cache/.run 2>/dev/null )
GNUPLOT_VARS := \
	CONFIG_WIDTH_SMALL=$(CONFIG_WIDTH_SMALL); CONFIG_WIDTH_BIG=$(CONFIG_WIDTH_BIG); CONFIG_WIDTH_ALL=$(CONFIG_WIDTH_ALL); \
	CONFIG_HEIGHT_SMALL=$(CONFIG_HEIGHT_SMALL); CONFIG_HEIGHT_BIG=$(CONFIG_HEIGHT_BIG); CONFIG_HEIGHT_ALL=$(CONFIG_HEIGHT_ALL); \
	PERIOD_START=$(PLOT_SINCE); CONFIG_TZ=$(CONFIG_TZ); CONFIG_TIMEZONE=$(CONFIG_TIMEZONE);

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
	@./cacher.pl $(basename $(notdir $@)) $(PLOT_SINCE) $(CONFIG_TIMEZONE) $(CONFIG_TZ)

out/%.png:	cache/%.csv timeplot.gpl $(CONFIG) | out/ tmp/
	@echo "Plotting $@ ..."
	@gnuplot -e "ID=$(basename $(notdir $@)); $(GNUPLOT_VARS)" ./timeplot.gpl
	@head -n3 tmp/$(basename $(notdir $@)).data |tail -n1|perl -ne '/"(.*)"/; print "$$1\n"' >tmp/$(basename $(notdir $@)).title

out/ALL.png:	$(LIVE_SENSORS:%=out/%.png) timeplot_all.gpl | out/ tmp/
	@echo "Plotting $@ ..."
	@gnuplot -e "IDs='$(LIVE_SENSORS)'; $(GNUPLOT_VARS)" ./timeplot_all.gpl

out/nGeigie_map.png:	in/nGeigie_map.png | out/
	@cp -a $< $@

out/index.html:	in/index.header in/index.footer $(LIVE_SENSORS:%=out/%.png) out/ALL.png | out/
	@echo "Compiling $@ ..."
	@{ \
		cat in/index.header; \
		perl -e 'my $$q="\""; for my $$id (@ARGV) { print "\t\t\t", "<a href=$${q}https://api.safecast.org/en-US/devices/$${id}/measurements$${q}><img src=$${q}$${id}.png$${q} alt=$${q}Sensor_$${id}_data$${q} width=$${q}$(CONFIG_WIDTH_BIG)$${q} height=$${q}$(CONFIG_HEIGHT_BIG)$${q} /></a>\n";}' $(LIVE_SENSORS); \
		cat in/index.footer |perl -pe 's#__PUT__DATE__HERE__#$(NOW) [$(VERSION)]#;'; \
	} >$@


test:
	@echo "It is $(NOW) in $(CONFIG_TIMEZONE)."
	@echo "Current version: $(VERSION)"

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

