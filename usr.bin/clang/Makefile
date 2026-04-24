.include <src.opts.mk>

.if ${MK_CLANG} != "no"
SUBDIR+=	clang
.endif

.if !defined(TOOLS_PREFIX)
.if ${MK_CLANG} != "no"
SUBDIR+=	clang-scan-deps
.endif

# LLVM binutils are needed to support features such as LTO, so we build them
# by default if clang is enabled. If MK_LLVM_BINUTILS is set, we also use them
# as the default binutils (ar,nm,addr2line, etc.).
.if ${MK_CLANG} != "no" || ${MK_LLVM_BINUTILS} != "no"
_LLVM_BINUTILS=		llvm-ar
_LLVM_BINUTILS+=	llvm-ar
_LLVM_BINUTILS+=	llvm-cxxfilt
_LLVM_BINUTILS+=	llvm-nm
_LLVM_BINUTILS+=	llvm-objcopy
_LLVM_BINUTILS+=	llvm-objdump
_LLVM_BINUTILS+=	llvm-readobj
_LLVM_BINUTILS+=	llvm-size
_LLVM_BINUTILS+=	llvm-strings
_LLVM_BINUTILS+=	llvm-symbolizer

SUBDIR+=	${_LLVM_BINUTILS}

SUBDIR+=	toolchain
SUBDIR_DEPEND_toolchain= ${_LLVM_BINUTILS}
.endif

.if ${MK_CLANG_EXTRAS} != "no"
SUBDIR+=	bugpoint
SUBDIR+=	llc
SUBDIR+=	lli
SUBDIR+=	llvm-as
SUBDIR+=	llvm-bcanalyzer
SUBDIR+=	llvm-cxxdump
SUBDIR+=	llvm-diff
SUBDIR+=	llvm-dis
SUBDIR+=	llvm-dwarfdump
SUBDIR+=	llvm-dwarfutil
SUBDIR+=	llvm-dwp
SUBDIR+=	llvm-extract
SUBDIR+=	llvm-link
SUBDIR+=	llvm-lto
SUBDIR+=	llvm-lto2
SUBDIR+=	llvm-mc
SUBDIR+=	llvm-mca
SUBDIR+=	llvm-modextract
SUBDIR+=	llvm-pdbutil
SUBDIR+=	llvm-rtdyld
SUBDIR+=	llvm-xray
SUBDIR+=	opt
.endif

.if ${MK_CLANG_EXTRAS} != "no" || ${MK_CLANG_FORMAT} != "no"
SUBDIR+=	clang-format
.endif

.if ${MK_LLD} != "no"
SUBDIR+=	lld
.endif
.if ${MK_LLDB} != "no"
SUBDIR+=	lldb
SUBDIR+=	lldb-server
.endif
.if ${MK_CLANG} != "no"
SUBDIR+=	llvm-cov
SUBDIR+=	llvm-profdata
SUBDIR_DEPEND_toolchain=	llvm-cov
.endif
.endif # TOOLS_PREFIX

SUBDIR_PARALLEL=

.include <bsd.subdir.mk>
