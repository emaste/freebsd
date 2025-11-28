.PATH: ${SRCTOP}/sys/netinet

KMOD=   tcphpts
SRCS=   tcp_hpts.c tcp_lro_hpts.c \
	opt_inet.h opt_inet6.h opt_rss.h device_if.h bus_if.h

EXPORT_SYMS= \
	tcp_hptsi_create \
	tcp_hptsi_destroy \
	tcp_hptsi_pace \
	tcp_hptsi_start \
	tcp_hptsi_stop

.include <bsd.kmod.mk>
