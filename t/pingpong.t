#!/usr/bin/perl -w

# $Id$

use strict;
#use Test::More tests => 53;
use Test::More 'no_plan';

BEGIN { use_ok('DFA::StateMachine') }

my @msgs;

ok my $dfa = DFA::StateMachine->new(
    ping => {
        enter => sub { push @msgs, "Entering ping\n" },
        do    => [ sub { push @msgs, "ping!\n" },
                   sub { shift->{goto} = 'pong'; },
                   sub { shift->{count}++ }
               ],
        leave => sub { push @msgs, "Leaving ping\n" },
        goto => [
            pong => sub { shift->{goto} eq 'pong' },
        ],
    },

    pong => {
        enter => [ sub { push @msgs, "Entering pong\n" },
                   sub { shift->{goto} = 'ping' } ],
        do    => sub { push @msgs, "pong!\n"; },
        leave => sub { push @msgs, "Leaving pong\n" },
        goto => [
            ping => [ sub { shift->{goto} eq 'ping' },
                      sub { push @msgs, "pong to ping\n" },
                  ],
        ],
    },
), "Create the ping pong DFA machine";

is $dfa->start, $dfa, "Start the game";
is $dfa->check, $dfa, "Number $dfa->{count}: " . $dfa->state
  while $dfa->{count} <= 5;
is_deeply \@msgs, [<DATA>], "Check that the messages are in the right order";

__DATA__
Entering ping
ping!
Leaving ping
Entering pong
pong!
Leaving pong
pong to ping
Entering ping
ping!
Leaving ping
Entering pong
pong!
Leaving pong
pong to ping
Entering ping
ping!
Leaving ping
Entering pong
pong!
Leaving pong
pong to ping
Entering ping
ping!
Leaving ping
Entering pong
pong!
Leaving pong
pong to ping
Entering ping
ping!
Leaving ping
Entering pong
pong!
Leaving pong
pong to ping
Entering ping
ping!
