/*-
 * Copyright (c) 2001 Chris D. Faulhaber
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/cdefs.h>
__FBSDID("$FreeBSD$");

#include <sys/types.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/acl.h>
#include <sys/queue.h>

#include <err.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fts.h>

#include "setfacl.h"

/* file operations */
#define	OP_MERGE_ACL		0x00	/* merge acl's (-mM) */
#define	OP_REMOVE_DEF		0x01	/* remove default acl's (-k) */
#define	OP_REMOVE_EXT		0x02	/* remove extended acl's (-b) */
#define	OP_REMOVE_ACL		0x03	/* remove acl's (-xX) */
#define	OP_REMOVE_BY_NUMBER	0x04	/* remove acl's (-xX) by acl entry number */
#define	OP_ADD_ACL		0x05	/* add acls entries at a given position */

/* TAILQ entry for acl operations */
struct sf_entry {
	uint	op;
	acl_t	acl;
	uint	entry_number;
	TAILQ_ENTRY(sf_entry) next;
};
static TAILQ_HEAD(, sf_entry) entrylist;

uint have_mask;
uint need_mask;
uint have_stdin;
uint n_flag;

static void	usage(void);

static void
usage(void)
{

	fprintf(stderr, "usage: setfacl [-bdhkn] [-a position entries] "
	    "[-m entries] [-M file] [-x entries] [-X file] [file ...]\n");
	exit(1);
}

int
main(int argc, char *argv[])
{
	acl_t acl;
	acl_type_t acl_type;
	acl_entry_t unused_entry;
	char filename[PATH_MAX];
	int local_error, carried_error, ch, entry_number, ret, fts_options;
	int R_flag, h_flag;
	struct sf_entry *entry;
  char *fn_dup;
	char *end;
	struct stat sb;
	FTS *ftsp;
	FTSENT *p;
  char ** filelist;
  size_t size, len;

	acl_type = ACL_TYPE_ACCESS;
	carried_error = local_error = 0;
	R_flag = h_flag = have_mask = have_stdin = n_flag = need_mask = 0;

	TAILQ_INIT(&entrylist);

	while ((ch = getopt(argc, argv, "M:RX:a:bdhkm:nx:")) != -1)
		switch(ch) {
		case 'M':
			entry = zmalloc(sizeof(struct sf_entry));
			entry->acl = get_acl_from_file(optarg);
			if (entry->acl == NULL)
				err(1, "%s: get_acl_from_file() failed", optarg);
			entry->op = OP_MERGE_ACL;
			TAILQ_INSERT_TAIL(&entrylist, entry, next);
			break;
    case 'R':
      R_flag = 1;
      break;
		case 'X':
			entry = zmalloc(sizeof(struct sf_entry));
			entry->acl = get_acl_from_file(optarg);
			entry->op = OP_REMOVE_ACL;
			TAILQ_INSERT_TAIL(&entrylist, entry, next);
			break;
		case 'a':
			entry = zmalloc(sizeof(struct sf_entry));

			entry_number = strtol(optarg, &end, 10);
			if (end - optarg != (int)strlen(optarg))
				errx(1, "%s: invalid entry number", optarg);
			if (entry_number < 0)
				errx(1, "%s: entry number cannot be less than zero", optarg);
			entry->entry_number = entry_number;

			if (argv[optind] == NULL)
				errx(1, "missing ACL");
			entry->acl = acl_from_text(argv[optind]);
			if (entry->acl == NULL)
				err(1, "%s", argv[optind]);
			optind++;
			entry->op = OP_ADD_ACL;
			TAILQ_INSERT_TAIL(&entrylist, entry, next);
			break;
		case 'b':
			entry = zmalloc(sizeof(struct sf_entry));
			entry->op = OP_REMOVE_EXT;
			TAILQ_INSERT_TAIL(&entrylist, entry, next);
			break;
		case 'd':
			acl_type = ACL_TYPE_DEFAULT;
			break;
		case 'h':
			h_flag = 1;
			break;
		case 'k':
			entry = zmalloc(sizeof(struct sf_entry));
			entry->op = OP_REMOVE_DEF;
			TAILQ_INSERT_TAIL(&entrylist, entry, next);
			break;
		case 'm':
			entry = zmalloc(sizeof(struct sf_entry));
			entry->acl = acl_from_text(optarg);
			if (entry->acl == NULL)
				err(1, "%s", optarg);
			entry->op = OP_MERGE_ACL;
			TAILQ_INSERT_TAIL(&entrylist, entry, next);
			break;
		case 'n':
			n_flag++;
			break;
		case 'x':
			entry = zmalloc(sizeof(struct sf_entry));
			entry_number = strtol(optarg, &end, 10);
			if (end - optarg == (int)strlen(optarg)) {
				if (entry_number < 0)
					errx(1, "%s: entry number cannot be less than zero", optarg);
				entry->entry_number = entry_number;
				entry->op = OP_REMOVE_BY_NUMBER;
			} else {
				entry->acl = acl_from_text(optarg);
				if (entry->acl == NULL)
					err(1, "%s", optarg);
				entry->op = OP_REMOVE_ACL;
			}
			TAILQ_INSERT_TAIL(&entrylist, entry, next);
			break;
		default:
			usage();
			break;
		}
	argc -= optind;
	argv += optind;

	if (n_flag == 0 && TAILQ_EMPTY(&entrylist))
		usage();

	/* take list of files from stdin */
	if (argc == 0 || strcmp(argv[0], "-") == 0) {
		if (have_stdin)
			err(1, "cannot have more than one stdin");
		have_stdin = 1;
		bzero(&filename, sizeof(filename));
    size = 16;
    len = 0;
    filelist = realloc(NULL, sizeof(char *) * size);
		while (fgets(filename, (int)sizeof(filename), stdin)) {
			/* remove the \n */
			filename[strlen(filename) - 1] = '\0';
			fn_dup = strdup(filename);
			if (fn_dup == NULL)
				err(1, "strdup() failed");
      //filelist
      filelist[len++] = fn_dup;
      if (size == len) {
        filelist = realloc(filelist, sizeof(char *) * (size += 16));
        if (!filelist) {
          err(1, "realloc() failed");
        }
      }
		}
    filelist = realloc(filelist, sizeof(char *) * len);
	} else {
    filelist = argv;
  }

  if (R_flag) {
    if (h_flag) 
			errx(1, "the -R and -h options may not be "
			    "specified together.");
    fts_options = FTS_PHYSICAL;
  } else {
    fts_options = FTS_LOGICAL;
  }

  if ((ftsp = fts_open(filelist, fts_options, 0)) == NULL)
    err(1, "fts_open");
  for (ret = 0;(p = fts_read(ftsp)) != NULL;) {
    switch(p->fts_info) {
      case FTS_D:
        if (!R_flag)
          fts_set(ftsp,p,FTS_SKIP);
        break;
      case FTS_DNR:
        warnx("%s: %s", p->fts_accpath, strerror(p->fts_errno));
        ret = 1;
        break;
      case FTS_DP:
        continue;
      case FTS_ERR:
      case FTS_NS:
        warnx("%s: %s", p->fts_accpath, strerror(p->fts_errno));
        ret = 1;
        continue;
      default:
        break;
    }

    /* cycle through each file */
		local_error = 0;

		if (stat(p->fts_accpath, &sb) == -1) {
			warn("%s: stat() failed", p->fts_accpath);
			carried_error++;
			continue;
		}

		if (acl_type == ACL_TYPE_DEFAULT && S_ISDIR(sb.st_mode) == 0) {
			warnx("%s: default ACL may only be set on a directory",
			    p->fts_accpath);
			carried_error++;
			continue;
		}

		if (h_flag)
			ret = lpathconf(p->fts_accpath, _PC_ACL_NFS4);
		else
			ret = pathconf(p->fts_accpath, _PC_ACL_NFS4);
		if (ret > 0) {
			if (acl_type == ACL_TYPE_DEFAULT) {
				warnx("%s: there are no default entries "
			           "in NFSv4 ACLs", p->fts_accpath);
				carried_error++;
				continue;
			}
			acl_type = ACL_TYPE_NFS4;
		} else if (ret == 0) {
			if (acl_type == ACL_TYPE_NFS4)
				acl_type = ACL_TYPE_ACCESS;
		} else if (ret < 0 && errno != EINVAL) {
			warn("%s: pathconf(..., _PC_ACL_NFS4) failed",
			    p->fts_accpath);
		}

		if (h_flag)
			acl = acl_get_link_np(p->fts_accpath, acl_type);
		else
			acl = acl_get_file(p->fts_accpath, acl_type);
		if (acl == NULL) {
			if (h_flag)
				warn("%s: acl_get_link_np() failed",
				    p->fts_accpath);
			else
				warn("%s: acl_get_file() failed",
				    p->fts_accpath);
			carried_error++;
			continue;
		}

		/* cycle through each option */
		TAILQ_FOREACH(entry, &entrylist, next) {
			if (local_error)
				continue;

			switch(entry->op) {
			case OP_ADD_ACL:
				local_error += add_acl(entry->acl,
				    entry->entry_number, &acl, p->fts_accpath);
				break;
			case OP_MERGE_ACL:
				local_error += merge_acl(entry->acl, &acl,
				    p->fts_accpath);
				need_mask = 1;
				break;
			case OP_REMOVE_EXT:
				/*
				 * Don't try to call remove_ext() for empty
				 * default ACL.
				 */
				if (acl_type == ACL_TYPE_DEFAULT &&
				    acl_get_entry(acl, ACL_FIRST_ENTRY,
				    &unused_entry) == 0) {
					local_error += remove_default(&acl,
					    p->fts_accpath);
					break;
				}
				remove_ext(&acl, p->fts_accpath);
				need_mask = 0;
				break;
			case OP_REMOVE_DEF:
				if (acl_type == ACL_TYPE_NFS4) {
					warnx("%s: there are no default entries in NFSv4 ACLs; "
					    "cannot remove", p->fts_accpath);
					local_error++;
					break;
				}
				if (acl_delete_def_file(p->fts_accpath) == -1) {
					warn("%s: acl_delete_def_file() failed",
					    p->fts_accpath);
					local_error++;
				}
				if (acl_type == ACL_TYPE_DEFAULT)
					local_error += remove_default(&acl,
					    p->fts_accpath);
				need_mask = 0;
				break;
			case OP_REMOVE_ACL:
				local_error += remove_acl(entry->acl, &acl,
				    p->fts_accpath);
				need_mask = 1;
				break;
			case OP_REMOVE_BY_NUMBER:
				local_error += remove_by_number(entry->entry_number,
				    &acl, p->fts_accpath);
				need_mask = 1;
				break;
			}
		}

		/*
		 * Don't try to set an empty default ACL; it will always fail.
		 * Use acl_delete_def_file(3) instead.
		 */
		if (acl_type == ACL_TYPE_DEFAULT &&
		    acl_get_entry(acl, ACL_FIRST_ENTRY, &unused_entry) == 0) {
			if (acl_delete_def_file(p->fts_accpath) == -1) {
				warn("%s: acl_delete_def_file() failed",
				    p->fts_accpath);
				carried_error++;
			}
			continue;
		}

		/* don't bother setting the ACL if something is broken */
		if (local_error) {
			carried_error++;
			continue;
		}

		if (acl_type != ACL_TYPE_NFS4 && need_mask &&
		    set_acl_mask(&acl, p->fts_accpath) == -1) {
			warnx("%s: failed to set ACL mask", p->fts_accpath);
			carried_error++;
		} else if (h_flag) {
			if (acl_set_link_np(p->fts_accpath, acl_type,
			    acl) == -1) {
				carried_error++;
				warn("%s: acl_set_link_np() failed",
				    p->fts_accpath);
			}
		} else {
			if (acl_set_file(p->fts_accpath, acl_type,
			    acl) == -1) {
				carried_error++;
				warn("%s: acl_set_file() failed",
				    p->fts_accpath);
			}
		}

		acl_free(acl);
	}

	return (carried_error);
}
