# Local Make rules.
# Written by Gary V. Vaughan, 2013

# Copyright (C) 2013-2017 Gary V. Vaughan

# This file is part of lcurses.
# See README for license.

## ------------ ##
## Environment. ##
## ------------ ##

curses_cpath = $(abs_builddir)/ext/curses/$(objdir)/?$(shrext)

std_cpath = $(curses_cpath);$(LUA_CPATH)
std_path  = $(abs_srcdir)/lib/?.lua;$(LUA_PATH)

LUA_ENV   = LUA_PATH="$(std_path)" LUA_CPATH="$(std_cpath)"


## ---------- ##
## Bootstrap. ##
## ---------- ##

AM_CPPFLAGS  += -I $(srcdir)/ext/include -I $(srcdir)/ext $(POSIX_EXTRA_CPPFLAGS)
AM_CFLAGS     = $(WERROR_CFLAGS) $(WARN_CFLAGS)
AM_LDFLAGS    = -module -avoid-version

old_NEWS_hash = d41d8cd98f00b204e9800998ecf8427e

update_copyright_env = \
	UPDATE_COPYRIGHT_HOLDER='(Gary V. Vaughan|Reuben Thomas|lcurses authors)' \
	UPDATE_COPYRIGHT_USE_INTERVALS=1 \
	UPDATE_COPYRIGHT_FORCE=1


## ------------- ##
## Declarations. ##
## ------------- ##

examplesdir		= $(docdir)/examples
modulesdir		= $(docdir)/modules
classesdir		= $(docdir)/classes

dist_data_DATA		=
dist_doc_DATA		=
dist_examples_DATA	=
dist_modules_DATA	=
dist_classes_DATA	=

include specs/specs.mk


## ------ ##
## Build. ##
## ------ ##

dist_lua_DATA +=			\
	lib/curses.lua			\
	$(NOTHING_ELSE)

luaexec_LTLIBRARIES += ext/curses_c.la

ext_curses_c_la_SOURCES =		\
	ext/curses.c			\
	$(NOTHING_ELSE)
EXTRA_ext_curses_c_la_SOURCES =		\
	ext/curses/chstr.c		\
	ext/curses/window.c		\
	$(NOTHING_ELSE)

ext_curses_c_la_LDFLAGS = $(AM_LDFLAGS) $(CURSES_LIB)


## -------------- ##
## Documentation. ##
## -------------- ##

dist_doc_DATA +=			\
	doc/index.html			\
	doc/ldoc.css			\
	$(NOTHING_ELSE)

dist_modules_DATA +=			\
	doc/modules/curses.html		\
	$(NOTHING_ELSE)

dist_classes_DATA +=			\
	doc/classes/curses.chstr.html	\
	doc/classes/curses.window.html	\
	$(NOTHING_ELSE)

dist_examples_DATA +=			\
	doc/examples/curses.lua.html	\
	$(NOTHING_ELSE)

allhtml = $(dist_doc_DATA) $(dist_examples_DATA) $(dist_modules_DATA) $(dist_classes_DATA)

$(allhtml): $(EXTRA_ext_curses_la_SOURCES) $(ext_curses_la_SOURCES)
	test -d $(builddir)/doc || mkdir $(builddir)/doc
if HAVE_LDOC
	$(LDOC) -c build-aux/config.ld -d $(abs_srcdir)/doc .
else
	$(MKDIR_P) doc
	touch doc/index.html doc/ldoc.css
endif

doc: $(allhtml)


## ------------- ##
## Distribution. ##
## ------------- ##

EXTRA_DIST +=				\
	build-aux/config.ld.in		\
	examples/curses.lua		\
	ext/include/_helpers.c		\
	ext/include/compat-5.2.c	\
	ext/include/compat-5.2.h	\
	ext/include/strlcpy.c		\
	$(NOTHING_ELSE)

MAINTAINERCLEANFILES +=			\
	doc/index.html			\
	doc/ldoc.css			\
	$(dist_examples_DATA)		\
	$(dist_modules_DATA)		\
	$(NOTHING_ELSE)
