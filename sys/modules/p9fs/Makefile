.PATH: ${SRCTOP}/sys/fs/p9fs

KMOD=	p9fs
SRCS=	vnode_if.h \
	p9_client.c p9_protocol.c p9_transport.c \
	p9fs_subr.c p9fs_vfsops.c p9fs_vnops.c

EXPORT_SYMS= \
	p9_debug_level \
	p9_destroy_zones \
	p9_init_zones \
	p9_register_trans

.include <bsd.kmod.mk>
