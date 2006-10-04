#!perl -w

# $Id: pod-coverage.t 932 2004-12-15 07:11:30Z theory $

use strict;
use Test::More;
use Test::Spelling;

add_stopwords(<DATA>);
all_pod_files_spelling_ok();

__DATA__
DFA
FSA
GraphViz
NFA
prepends
stacktrace
Kineticode
Storable
