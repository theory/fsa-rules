#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More tests => 14;
#use Test::More 'no_plan';

BEGIN { use_ok('FSA::Rules') }

my @msgs;

ok my $fsa = FSA::Rules->new(
    ping => {
        on_enter => sub { push @msgs, "Entering ping\n" },
        do       => [ sub { push @msgs, "ping!\n" },
                      sub { shift->{goto} = 'pong'; },
                      sub { shift->{count}++ }
                  ],
        on_exit  => sub { push @msgs, "Exiting ping\n" },
        rules     => [
            pong => sub { shift->{goto} eq 'pong' },
        ],
    },

    pong => {
        on_enter => [ sub { push @msgs, "Entering pong\n" },
                      sub { shift->{goto} = 'ping' } ],
        do       => sub { push @msgs, "pong!\n"; },
        on_exit  => sub { push @msgs, "Exiting pong\n" },
        rules     => [
            ping => [ sub { shift->{goto} eq 'ping' },
                      sub { push @msgs, "pong to ping\n" },
                      sub { $_[0]->done($_[0]->{count} == 5 ) },
                  ],
        ],
    },
), "Create the ping pong FSA machine";

is $fsa->start, 'ping', "Start the game";
is $fsa->switch, $fsa->state, "Number $fsa->{count}: " . $fsa->state
  until $fsa->done;
my @check = <DATA>;
is_deeply \@msgs, \@check, "Check that the messages are in the right order";

__DATA__
Entering ping
ping!
Exiting ping
Entering pong
pong!
Exiting pong
pong to ping
Entering ping
ping!
Exiting ping
Entering pong
pong!
Exiting pong
pong to ping
Entering ping
ping!
Exiting ping
Entering pong
pong!
Exiting pong
pong to ping
Entering ping
ping!
Exiting ping
Entering pong
pong!
Exiting pong
pong to ping
Entering ping
ping!
Exiting ping
Entering pong
pong!
Exiting pong
pong to ping
Entering ping
ping!
