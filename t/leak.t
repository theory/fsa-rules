#!/usr/bin/perl -w

use strict;
use Test::More;

eval 'use Test::Weaken qw(leaks)';
plan skip_all => 'Test Weaken required to test for memory leaks' if $@;

plan tests => 2;

use FSA::Rules;

my $leaks = leaks(sub {
    ok my $fsa = +FSA::Rules->new(
        foo => {},
    ), "Construct with a single state";
    return $fsa;
});

ok !$leaks, 'There should be no leaks' or
    diag sprintf '%d of %d original references were not freed',
    $leaks->unfreed_count, $leaks->probe_count;
