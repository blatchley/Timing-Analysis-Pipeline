FROM ubuntu:16.04

ARG NUM_PROCESSORS=4

RUN apt-get update -y && \
    apt-get -y install gcc g++ git make wget xz-utils python

# Dudect
RUN git clone https://github.com/oreparaz/dudect.git /usr/share/dudect
RUN cd /usr/share/dudect && make

# Flow Tracker
RUN wget -O /tmp/llvm.src.tar.xz "https://www.llvm.org/releases/3.7.1/llvm-3.7.1.src.tar.xz"
RUN tar -xf /tmp/llvm.src.tar.xz -C $HOME

RUN wget -O /tmp/cfe-3.7.1.src.tar.xz "http://www.llvm.org/releases/3.7.1/cfe-3.7.1.src.tar.xz"
RUN tar -xf /tmp/cfe-3.7.1.src.tar.xz -C $HOME/llvm-3.7.1.src/tools/
RUN mv $HOME/llvm-3.7.1.src/tools/cfe-3.7.1.src $HOME/llvm-3.7.1.src/tools/clang
RUN mkdir -p $HOME/llvm-3.7.1.src/build/lib/Transforms

RUN git clone https://github.com/dfaranha/FlowTracker.git /tmp/flowtracker && \
    cp -r /tmp/flowtracker/AliasSets $HOME/llvm-3.7.1.src/lib/Transforms && \
    cp -r /tmp/flowtracker/DepGraph $HOME/llvm-3.7.1.src/lib/Transforms && \
    cp -r /tmp/flowtracker/bSSA2 $HOME/llvm-3.7.1.src/lib/Transforms && \
    \
    cp -r /tmp/flowtracker/AliasSets $HOME/llvm-3.7.1.src/build/lib/Transforms && \
    cp -r /tmp/flowtracker/DepGraph $HOME/llvm-3.7.1.src/build/lib/Transforms && \
    cp -r /tmp/flowtracker/bSSA2 $HOME/llvm-3.7.1.src/build/lib/Transforms

RUN sed -i "s#bool hasMD() const { return MDMap; }#bool hasMD() const { return bool(MDMap); }#g" $HOME/llvm-3.7.1.src/include/llvm/IR/ValueMap.h

RUN cd $HOME/llvm-3.7.1.src/build && \
    ../configure --disable-bindings && \
    make -j${NUM_PROCESSORS}

ENV PATH="$PATH:/root/llvm-3.7.1.src/build/Release+Asserts/bin"

RUN cd $HOME/llvm-3.7.1.src/build/lib/Transforms/AliasSets && \
    make -j${NUM_PROCESSORS}
RUN cd $HOME/llvm-3.7.1.src/build/lib/Transforms/DepGraph && \
    make -j${NUM_PROCESSORS}
RUN cd $HOME/llvm-3.7.1.src/build/lib/Transforms/bSSA2 && \
    make -j${NUM_PROCESSORS}
RUN cd $HOME/llvm-3.7.1.src/build/lib/Transforms/bSSA2 && \
    g++ -shared -o parserXML.so -fPIC parserXML.cpp tinyxml2.cpp

# Valgrind
RUN apt-get update && \ 
    apt-get install -y bzip2 libc6-dbg

RUN wget -O /tmp/valgrind.tar.bz2 "https://sourceware.org/pub/valgrind/valgrind-3.16.1.tar.bz2" && \
    tar -xf /tmp/valgrind.tar.bz2 -C /tmp/

# Inject ctgrind
COPY src/ctgrind/ctgrind.c /usr/share/sources/ctgrind/ctgrind.c
COPY src/ctgrind/ctgrind.h /usr/share/sources/ctgrind/ctgrind.h

RUN gcc -o /usr/lib/libctgrind.so -shared /usr/share/sources/ctgrind/ctgrind.c -I/usr/share/sources/ctgrind -Wall -std=c99 -fPIC -Wl,-soname,libctgrind.so.1 && \
    ln -s /usr/lib/libctgrind.so /usr/lib/libctgrind.so.1

COPY valgrind.patch /tmp/valgrind.patch
RUN cd /tmp/ && \
    patch -p0 < /tmp/valgrind.patch

RUN cd /tmp/valgrind-3.16.1 && \
    ./configure --prefix=/usr/share/valgrind && \
    make -j${NUM_PROCESSORS} && \
    make install

ENV PATH="/usr/share/valgrind/bin:$PATH"

# Scripts
COPY src /usr/share/sources

# Cleanup
RUN rm -rf /var/lib/apt/lists/*
RUN rm -rf /tmp/*

CMD /usr/share/sources/scripts/run.sh