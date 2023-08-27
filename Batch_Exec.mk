# Makefile for Batch::Exec	(C) Tom McMeekin 2023
#
# usage:	make Batch_Exec.mk
#
# description:
# Generally used to drive installation dependencies before calling the
# usual perl make process.  Generally this .mk will look for a .plmk
# file and rename it to Makefile.PL.  This file is based on ide_template.mk

include ${IDE_DN_PROFILE}/ide_include.mk

# -------- variables --------
PACKAGE_THIS=Batch::Exec
DN_TOP=${IDE_DN_TOP}
FN_THIS=Batch_Exec.mk
FN_PERL_MF_THIS=Batch_Exec.plmk

# Note: do not need to test core modules, ref. https://perldoc.perl.org/modules
PERL_MODULES := Carp Data::Dumper Hash::Merge List::Util Path::Tiny Text::Unidecode Logfer
PKGS_CYGWIN := Change-Me
PKGS_DEBIAN := libhash-merge-perl libpath-tiny-perl libtext-unidecode-perl powershell
IDE_PURGE_FILES := change___me e.g. ${DN_BIN}/hello/world

# -------- macros --------


# -------- targets --------
#all: ide_banner prereqs install ide_purge ide_complete
all: ide_banner prereqs install ide_complete

prereqs: ide_perltest

install: ide_perlmake


