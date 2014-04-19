MAKEFLAGS := --output-sync=target --jobs 8 --max-load 3.5

CONFIG := Makefile.config
include $(CONFIG)

NOW := $(shell date +%FT%T%Z)

.INTERMEDIATE:	cache/%.csv
.PRECIOUS:	cache/%.csv

all:	out

cache:	$(LIVE_SENSORS:%=cache/%.csv)
out:	$(LIVE_SENSORS:%=out/%.png) out/index.html

publish:	out
	@$(PUBLISH_CMD)

view:	out
	@$(VIEW_CMD)

cache/%.csv:	cacher.pl
	@echo "Fetching data to fill $@ ..."
	@./cacher.pl $(basename $(notdir $@)) $(PLOT_SINCE)

out/%.png:	cache/%.csv timeplot.gpl $(CONFIG)
	@echo "Plotting $@ ..."
	@gnuplot -e "ID=$(basename $(notdir $@)); PERIOD_START=$(PLOT_SINCE);" ./timeplot.gpl

out/ALL.png:	$(LIVE_SENSORS:%=out/%.png) timeplot_all.gpl
	@echo "Plotting $@ ..."
	@gnuplot -e "IDs='$(LIVE_SENSORS)'; PERIOD_START=$(PLOT_SINCE);" ./timeplot_all.gpl

out/index.html:	in/index.header in/index.footer $(LIVE_SENSORS:%=out/%.png) out/ALL.png
	@echo "Compiling $@ ..."
	@{ \
		cat in/index.header; \
		perl -e 'my $$q="\""; for my $$id (@ARGV) { print "\t\t\t", "<a href=$${q}https://api.safecast.org/en-US/devices/$${id}/measurements$${q}><img src=$${q}$${id}.png$${q} /></a>\n";}' $(LIVE_SENSORS); \
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
	@test ! -e $(CONFIG) || { rm -i $(CONFIG); exit 0; }
	@echo -ne "mrproper:\tdone.\n"
