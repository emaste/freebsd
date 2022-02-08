#!/bin/sh

from_branch=freebsd/main
to_branch=freebsd/stable/13
author=$USER

# If pwd is a stable branch tree, default to it.
cur_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
case $cur_branch in
stable/*)
	to_branch=$cur_branch
	;;
esac

params()
{
	echo "from:             $from_branch"
	echo "to:               $to_branch"
	if [ -n "$author" ]; then
		echo "author/committer: $author"
	else
		echo "author/committer: <all>"
	fi
}

usage()
{
	echo "usage: $(basename $0) [-ah] [-f from_branch] [-t to_branch] [-u user] [path ...]"
	echo
	params
	exit 0
}


while getopts "af:ht:u:v" opt; do
	case $opt in
	a)
		# All authors/committers
		author=
		;;
	f)
		from_branch=$OPTARG
		;;
	h)
		usage
		;;
	t)
		to_branch=$OPTARG
		;;
	u)
		author=$OPTARG
		;;
	v)
		verbose=1
		;;
	esac
done
shift $(($OPTIND - 1))

if [ $verbose ]; then
	params
	echo
fi

authorarg=
if [ -n "$author" ]; then
	authorarg="--author $author --committer $author"
fi

# Commits in from_branch after branch point
git rev-list --first-parent $authorarg $to_branch..$from_branch "$@" |\
    sort > from_list

# "cherry picked from" hashes from commits in to_branch after branch point
git log $from_branch..$to_branch --grep 'cherry picked from' "$@" |\
    sed -E -n 's/^[[:space:]]*\(cherry picked from commit ([0-9a-f]+)\)[[:space:]]*$/\1/p' |\
    sort > to_list

comm -23 from_list to_list > candidates

# Sort by (but do not print) commit time
while read hash; do
	git show --pretty='%ct %h %s' --no-patch $hash
done < candidates | sort -n | cut -d ' ' -f 2-
