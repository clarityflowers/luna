# Luna

Luna is a MIDI sequencer, built on top of [Löve2d](https://love2d.org), tightly-coupled with my electronic music hardware and particular my modular synthesizers.

It features:

- multiple parallel sequences sent to different channels
- staff notation representation of sequences
- live code reloading
- ability to take advantage of portamento settings to create ties between notes

You can see it in action in my newer YouTube releases:

[![Far Away](https://img.youtube.com/vi/GGFZG6qigFQ/0.jpg)](https://www.youtube.com/watch?v=GGFZG6qigFQ)

## Things I did to get this running

These are some notes I made for myself in order to get my setup going on my Macbook. Maybe it'll work for you too? Good luck.

---

Built lua 5.1 from source:

```
curl -R -O http://www.lua.org/ftp/lua-5.1.5.tar.gz
tar zxf lua-5.1.5.tar.gz
cd lua-5.1.5
make macosx install
```

---

I needed cmake. Got it from brew.

Built [RtMidi](https://github.com/thestk/rtmidi). It was necessary to patch a missing semaphor function with a an [open-sourced replacement](https://raw.githubusercontent.com/attie/libxbee3/master/xsys_darwin/sem_timedwait.c). Copied the file into the src directory, deleted `#include "sem_timedwait.h"` because that header file is empty, and added `#include "sem_timedwait.h"` below the semaphore include.

Ran these commands (from the readme)

```
./autogen.sh
./configure
make
```

cmake told me I needed some things. brew installed them just fine

---

Next I built [luamidi](https://github.com/dwiel/luamidi). There are two libraries with this name, which confused me for a bit.

This isn't compatible with lua 5.3.

Instead of running `make`, I added a `rockspec`:

```
package = "luamidi"
version = "1.0-1"
source = {
   url = "." -- not online yet!
}
build = {
   type = "make"
}
```

and ran `luarocks make`

copied `luamidi.o` into into the src directory

---

Also pulled down the source and build [luafilesystem](https://github.com/keplerproject/luafilesystem), creating `lfo.so`
