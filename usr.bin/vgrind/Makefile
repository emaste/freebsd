PROG=	vfontedpr
SRCS=	regexp.c vfontedpr.c
SCRIPTS=vgrind.sh
FILES=	vgrindefs.src vgrindefs.src.db tmac.vgrind
FILESNAME_vgrindefs.src=	vgrindefs
FILESNAME_vgrindefs.src.db=	vgrindefs.db
FILESDIR=	${SHAREDIR}/misc
FILESDIR_tmac.vgrind=	${SHAREDIR}/tmac
MAN=	vgrind.1 vgrindefs.5

WARNS?=	3

BINDIR=	${LIBEXECDIR}
SCRIPTSDIR=/usr/bin

CLEANFILES= vgrindefs.src.db

.include <bsd.endian.mk>
.include <src.tools.mk>

vgrindefs.src.db: vgrindefs.src
	${CAP_MKDB_CMD} ${CAP_MKDB_ENDIAN} -f vgrindefs.src ${.ALLSRC}

.include <bsd.prog.mk>
