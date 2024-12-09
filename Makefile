.PHONY : all build flush clean install test dist

FILES = $(wildcard sql/*.sql)

TESTFILES = $(wildcard test/sql/*.sql)

EXTENSION = data_historization

EXTVERSION   = $(shell grep -m 1 '[[:space:]]\{3\}"version":' META.json | \
	       sed -e 's/[[:space:]]*"version":[[:space:]]*"\([^"]*\)",\{0,1\}/\1/')

DISTVERSION  = $(shell grep -m 1 '[[:space:]]\{3\}"version":' META.json | \
	       sed -e 's/[[:space:]]*"version":[[:space:]]*"\([^"]*\)",\{0,1\}/\1/')

DATA = $(wildcard data_historization--*.sql)

PGTLEOUT = pgtle.$(EXTENSION)-$(EXTVERSION).sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)

# edit this value if you want to deploy by hand
SCHEMA = @extschema@

include $(PGXS)

all: $(EXTENSION)--$(EXTVERSION).sql $(PGTLEOUT) data_historization.control

$(EXTENSION)--$(EXTVERSION).sql: $(FILES)
	cat $(FILES) > $@
	cat $@ > data_historization.sql

clean:
	rm -f $(DATA) $(PGTLEOUT) *.zip

test:
	pg_prove $(TESTFILES)

$(PGTLEOUT): $(EXTENSION)--$(EXTVERSION).sql src/pgtle_footer.in src/pgtle_header.in
	sed -e 's/_EXTVERSION_/$(EXTVERSION)/' src/pgtle_header.in > $(PGTLEOUT)
	cat $(EXTENSION)--$(EXTVERSION).sql >> $(PGTLEOUT)
	cat src/pgtle_footer.in >> $(PGTLEOUT)

dist:
	git archive --format zip --prefix=$(EXTENSION)-$(DISTVERSION)/ -o $(EXTENSION)-$(DISTVERSION).zip HEAD

data_historization.control: data_historization.control.in META.json
	sed 's,EXTVERSION,$(EXTVERSION),g; ' $< > $@;
