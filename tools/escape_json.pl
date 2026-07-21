#!/usr/bin/env perl
# Read text (from a file argument or stdin) and print it JSON-string-escaped
# WITHOUT surrounding quotes. Used by tools/open_pr.sh to build PR payloads.
#
# IMPORTANT: this exists as a *script file* on purpose. Doing the same escaping
# with an inline `perl -e '...'` one-liner gets mangled by the shell / MSYS
# (backslashes are eaten), which silently produces an empty PR body.
undef $/;
my $s = <>;
$s =~ s/\\/\\\\/g;   # backslashes first
$s =~ s/"/\\"/g;     # double quotes
$s =~ s/\r//g;       # strip CR (CRLF -> LF)
$s =~ s/\n/\\n/g;    # newlines
$s =~ s/\t/\\t/g;    # tabs
print $s;
