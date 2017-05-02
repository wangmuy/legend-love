SDLFLAG=`pkg-config --cflags --libs sdl`
LUAFLAG=`pkg-config --cflags --libs lua5.2`
SMPEGFLAG=`smpeg-config --cflags --libs`
OTHERFLAG= -lSDL_ttf -lSDL_image -lSDL_mixer -lsmpeg 
RM= rm -rf
all:
	gcc *.c -o ../bin/jy $(LUAFLAG) $(SDLFLAG) $(SMPEGFLAG) $(OTHERFLAG)

clean:
	$(RM) ../bin/*.txt ../bin/jy

instbuilddeps:
	sudo apt-get install -y libsdl1.2-dev libsdl-image1.2-dev libsdl-mixer1.2-dev libsdl-ttf2.0-dev libsmpeg-dev timidity
