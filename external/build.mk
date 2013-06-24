
# $(call git-clone dir url tag)
define git-clone =
test -d $1 || { git init $1 && cd $1 && git remote add origin $2; }
cd $1 && git fetch origin
cd $1 && git checkout $3
endef

# $(call svn-clone dir url tag)
define svn-clone =
svn co -q $2/$3 $1
endef

# $(call cvs-clone dir url module tag)
define cvs-clone
mkdir -p $(dir $1)
cd $(dir $1) && cvs -d $2 co -d $(notdir $1) -r $4 $3
endef

O=../build/external

.PHONEY: all gcc boost jdk fontconfig freetype libjpeg zlib expat

all: gcc boost jdk fontconfig freetype libjpeg zlib expat

gcc:
	mkdir -p $O
	$(call svn-clone,$O/gcc,svn://gcc.gnu.org/svn/gcc,tags/gcc_4_7_3_release)
	cd $O/gcc && ./configure \
		CFLAGS='-mno-red-zone -O2' \
		CXXFLAGS='-mno-red-zone -O2' \
		--disable-bootstrap \
		--with-multilib-list=m64 \
		--enable-shared=libgcc,libstdc++ \
		--enable-languages=c,c++ \
		--prefix=$(abspath $O/bin/usr)
	$(MAKE) -C $O/gcc
	$(MAKE) -C $O/gcc install
	ln -sf usr/lib64 $O/bin/lib64

boost:
	mkdir -p $O
	$(call svn-clone,$O/boost,http://svn.boost.org/svn/boost,tags/release/Boost_1_50_0)
	mkdir -p $O/bin/usr
	ln -sf lib64 $O/bin/usr/lib
	cd $O/boost && ./bootstrap.sh \
		--with-libraries=program_options \
		--prefix=$(abspath $O/bin/usr)
	cd $O/boost && ./b2 threading=multi cxxflags=-mno-red-zone
	rm -rf $O/bin/usr/lib64/libboost*
	cd $O/boost && ./b2 install
	for i in $O/bin/usr/lib64/libboost*.{a,so}; do mv $$i $$(echo $$i | sed -E 's/\.(a|so)$$/-mt.\1/'); done 

openjdk.bin = /usr/lib/jvm/java-1.7.0-openjdk.x86_64

# export BUILD_HEADLESS_ONLY=true

jdk-extra = EXTRA_CFLAGS=-mno-red-zone

jdk:
	mkdir -p $O
	test -d $O/jdk || hg clone http://icedtea.classpath.org/hg/release/icedtea7-2.3 $O/jdk
	cd $O/jdk && hg pull -u
	cd $O/jdk && ./autogen.sh
	cd $O/jdk && $(jdk-extra) ./configure \
		--disable-hg \
		--disable-docs \
		--disable-bootstrap \
		--enable-system-lcms \
		--enable-system-zlib \
		--enable-system-png \
		--enable-system-gif \
		--with-parallel-jobs \
		--disable-tests \
		--with-rhino
	sed -i 's/DISABLE_INTREE_EC="true"/DISABLE_INTREE_EC=""/' $O/jdk/Makefile
	cd $O/jdk && $(jdk-extra) make

fontconfig:
	$(call git-clone,$O/fontconfig,git://anongit.freedesktop.org/fontconfig,2.10.2)
	cd $O/fontconfig && CFLAGS=-mno-red-zone ./autogen.sh \
		--sysconfdir=/etc --prefix=/usr --mandir=/usr/share/man
	cd $O/fontconfig && make
	# can't use make install, since it will try to write to /usr
	install -D $O/fontconfig/src/.libs/libfontconfig.so $O/bin/usr/lib64/libfontconfig.so.1

freetype:
	$(call git-clone,$O/freetype,git://git.sv.nongnu.org/freetype/freetype2.git,VER-2-4-10)
	cd $O/freetype && ./autogen.sh
	cd $O/freetype && CFLAGS=-mno-red-zone ./configure
	cd $O/freetype && make
	# can't use make install, since it will try to write to /usr
	install -D $O/freetype/objs/.libs/libfreetype.so $O/bin/usr/lib64/libfreetype.so.6

libjpeg:
	$(call svn-clone,$O/libjpeg,svn://svn.code.sf.net/p/libjpeg-turbo/code,tags/1.2.90)
	cd $O/libjpeg && autoreconf -fiv
	cd $O/libjpeg && CFLAGS=-mno-red-zone ./configure
	cd $O/libjpeg && make
	# can't use make install, since it will try to write to /usr
	install -D $O/libjpeg/.libs/libjpeg.so.62 $O/bin/usr/lib64/libjpeg.so.62


zlib:
	$(call git-clone,$O/zlib,git://github.com/madler/zlib.git,v1.2.7)
	cd $O/zlib && prefix=/usr CFLAGS='-O3 -mno-red-zone' ./configure
	cd $O/zlib && make
	install -D $O/zlib/libz.so.1 $O/bin/usr/lib64/libz.so.1


expat:
	$(call cvs-clone,$O/expat,:pserver:anonymous:@expat.cvs.sourceforge.net:/cvsroot/expat,expat,R_2_1_0)
	rm -rf $O/expat/autom4te*.cache
	cp /usr/share/libtool/config/install-sh $O/expat/conftools/
	cd $O/expat && autoreconf -fiv
	cd $O/expat; automake -a || true # ignore errors
	cd $O/expat && CFLAGS='-mno-red-zone -fPIC' ./configure
	cd $O/expat && make
	install -D $O/expat/.libs/libexpat.so.1 $O/bin/usr/lib64/libexpat.so.1
 