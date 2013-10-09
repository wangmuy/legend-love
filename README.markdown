基于游泳的鱼的金庸群侠传lua复刻版，修改gbk编码为utf8编码，移植到Mac OS X上。

Ubuntu下编译成功。

# Ubuntu下编译

 - 安装 ```libsdl1.2-dev libsdl-image1.2-dev libsdl-mixer1.2-dev libsdl-ttf2.0-dev libsmpeg-dev timidity```
 - 编译

```
cd src
make
```

# 运行

```
cd bin
./jy
```
## 关于midi输出
[参考1](http://lilypond.1069038.n5.nabble.com/How-do-you-test-MIDI-output-when-the-MIDI-instrument-is-not-supported-td52785.html)

安装 timidity 后就有声音输出了, 但是不全. 补全如下:

1. 到 [SDL_mixer docs][2] 下载 [GUS patches](http://www.libsdl.org/projects/mixer/timidity/timidity.tar.gz)

2. 解压整个目录放到 /usr/share/midi/ 下(假设是 /usr/share/midi/timidity)

3. 修改 /usr/share/midi/timidity/timidity.cfg, 文件最上面加入<br>
   ```dir /usr/share/midi/timidity```

4. 修改 /etc/timidity/timidity.cfg, 注释掉 source freepats.cfg 行, 加入<br>
   ```source /usr/share/midi/timidity/timidity.cfg```

5. 重启 timidity<br>
   ```sudo service timidity restart```

[2]: http://www.libsdl.org/projects/docs/SDL_mixer/SDL_mixer.html
