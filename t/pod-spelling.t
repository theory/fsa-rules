#!perl -w

# $Id$

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
