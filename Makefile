.PHONY : all build flush clean install test

FILES = $(wildcard sql/*.sql)

TESTFILES = $(wildcard test/sql/*.sql)

EXTENSION = data_historization

EXTVERSION = 0.0.3

DATA = $(wildcard data_historization--*.sql)

PGTLEOUT = pgtle.$(EXTENSION)-$(EXTVERSION).sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)

# edit this value if you want to deploy by hand
SCHEMA = @extschema@

include $(PGXS)

all: $(EXTENSION)--$(EXTVERSION).sql $(PGTLEOUT)

$(EXTENSION)--$(EXTVERSION).sql: $(FILES)
	cat $(FILES) > $@
	cat $@ > sql/data_historization.sql

clean:
	rm -f $(DATA) $(PGTLEOUT)

test:
	pg_prove $(TESTFILES)

$(PGTLEOUT): $(EXTENSION)--$(EXTVERSION).sql src/pgtle_footer.in src/pgtle_header.in
	sed -e 's/_EXTVERSION_/$(EXTVERSION)/' src/pgtle_header.in > $(PGTLEOUT)
	cat $(EXTENSION)--$(EXTVERSION).sql >> $(PGTLEOUT)
	cat src/pgtle_footer.in >> $(PGTLEOUT)
