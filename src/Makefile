LUA_VERSION=lua5.2
all:
	gcc *.c `pkg-config $(LUA_VERSION) --libs --cflags` `sdl-config --cflags --libs` `smpeg-config --cflags --libs` -lSDL_ttf -lSDL_image -lSDL_mixer -o ../bin/jy
