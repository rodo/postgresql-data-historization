.PHONY : all build flush clean install test

FILES = $(wildcard sql/*.sql)

TESTFILES = test/sql/get_random_country.sql

EXTENSION = data_historization

EXTVERSION = 0.0.3

DATA = $(wildcard data_historization--*.sql)

PGTLEOUT = pgtle.$(EXTENSION)-$(EXTVERSION).sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)

# edit this value if you want to deploy by hand
SCHEMA = @extschema@

include $(PGXS)

all: $(EXTENSION)--$(EXTVERSION).sql

$(EXTENSION)--$(EXTVERSION).sql: $(FILES)
	cat $(FILES) > $@

clean:
	rm -f $(DATA) $(PGTLEOUT)

test:
	pg_prove $(TESTFILES)

pgtle: build
	sed -e 's/_EXTVERSION_/$(EXTVERSION)/' pgtle_header.in > $(PGTLEOUT)
	cat data_historization--$(EXTVERSION).sql >>  $(PGTLEOUT)
	cat pgtle_footer.in >> $(PGTLEOUT)
