package = "lcurses"
version = "git-1"
description = {
  detailed = "lcurses is a C library for Lua that wraps the curses API.",
  homepage = "http://github.com/lcurses/lcurses/",
  license = "MIT/X11",
  summary = "Lua bindings for curses",
}
source = {
  url = "git://github.com/lcurses/lcurses.git",
}
dependencies = {
  "lua >= 5.1, < 5.4",
}
external_dependencies = nil
build = {
  build_command = "LUA='$(LUA)' ./bootstrap && ./configure LUA='$(LUA)' LUA_INCLUDE='-I$(LUA_INCDIR)' --prefix='$(PREFIX)' --libdir='$(LIBDIR)' --datadir='$(LUADIR)' --datarootdir='$(PREFIX)' && make clean all",
  copy_directories = {},
  install_command = "make install luadir='$(LUADIR)' luaexecdir='$(LIBDIR)'",
  type = "command",
}
