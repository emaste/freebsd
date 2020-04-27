# Specl specs make rules.


## ------ ##
## Specs. ##
## ------ ##

specl_SPECS =						\
	$(srcdir)/specs/curses_spec.yaml		\
	$(NOTHING_ELSE)

EXTRA_DIST +=						\
	$(srcdir)/specs/spec_helper.lua			\
	$(NOTHING_ELSE)

include build-aux/specl.mk
