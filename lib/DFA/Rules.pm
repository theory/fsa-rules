package DFA::Rules;

# $Id$

use strict;
$DFA::Rules::VERSION = '0.02';

=head1 Name

=begin comment

Fake-out Module::Build. Delete if it ever changes to support =head1 headers
other than all uppercase.

=head1 NAME

=end comment

DFA::Rules - A simple Perl state machine

=head1 Synopsis

  use DFA::Rules;

  my $dfa = DFA::Rules->new(
     ping => {
         enter => sub { print "Entering ping\n" },
         do    => [ sub { print "ping!\n" },
                    sub { shift->{goto} = 'pong'; },
                    sub { shift->{count}++ }
         ],
         leave => sub { print "Leaving 'ping'\n" },
         goto => [
             pong => sub { shift->{goto} eq 'pong' },
         ],
     },

     pong => {
         enter => [ sub { print "Entering pong\n" },
                    sub { shift->{goto} = 'ping' } ],
         do    => sub { print "pong!\n"; },
         leave => sub { print "Leaving 'pong'\n" },
         goto => [
             ping => [ sub { shift->{goto} eq 'ping' },
                       sub { print "pong to ping\n" },
             ],
         ],
     },
  );

  $dfa->start;
  $dfa->check while $dfa->{count} <= 21;

=head1 Description

This class implements a simple DFA state machine. I wrote it when Ovid and I
were getting fed up with the weirdness of L<DFA::Simple|DFA::Simple>, in which
the only things worse than the documentation are the interface and the
implementation. 'Nuff said.

DFA::Rules uses named states so that it's easy to tell what state you're in
and what state you want to go to. Each state may define actions that are
triggered upon entering the state, while in the state, and upon leaving the
state. They may also define rules for transitioning to other actions, and
these rules may specify the execution of transition-specific actions. All
actions are defined in terms of anonymous subroutines that should expect the
DFA object itself to be passed as the sole argument.

DFA::Rules objects are implemented as empty hash references, so the action
subroutines can use it to store data for other states to retreive without the
possibility of interfering with the state machine itself.


=head1 Class Interface

=head2 Constructor

=head3 new

  my $dfa = DFA::Rules->new(%state_table);

Constructs and returns a new DFA::Rulesy object. The parameters define the
state table, where each key is the name of a state and the following hash
reference defines the state, its actions, transitions, and rules. The first
state parameter is considered to be the start state. The supported keys in the
state definition hash references are:

=over

=item enter

  enter => sub { ... }
  enter => [ sub {... }, sub { ... } ]

A code reference or array reference of code references. These will be executed
when entering the state. The state object will be passed to each code
reference as the sole argument.

=item do

  do => sub { ... }
  do => [ sub {... }, sub { ... } ]

A code reference or array reference of code references. These are the actions
to be taken in the state, and will execute after any C<enter> code references
and any transition code references (defined by C<goto>). The state object will
be passed to each code reference as the sole argument.

=item leave

  leave => sub { ... }
  leave => [ sub {... }, sub { ... } ]

A code reference or array reference of code references. These will be executed
when leaving the state. The state object will be passed to each code reference
as the sole argument.

=item goto

  goto => [
      state1 => \&state1_rule,
      state2 => [ \&state2_rule, \&action ],
      state3 => undef,
      state4 => [ undef, \&action ],
  ]

The rules for transfering from the state to other states. This is an array
reference but shaped like a hash. The keys are the states to consider moving
to, while the values are the rules for transfergin to that state. The rules
will be executed in the order specified in the array reference, and will
short-circuit.

A rule may take the form of a code reference or of an array reference of code
references. The code reference or first code reference in the array must
return true to trigger transfer to the state, and false not to transfer to the
state. Any other code references in the array reference will be executed
during the transfer, after the C<leave> subroutines have been executed in the
current state, but before the C<enter> subroutines execute in the new state.

A rule may also be simply C<undef>, in which case it I<always> triggers the
transfer.

=back

=cut

my %states;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $states{$self} = { table => {}};
    while (@_) {
        my $state = shift;
        my $def = shift;
        $states{$self}->{start} ||= $state;

        # Setup enter, leave, and do actions.
        for (qw(enter do leave)) {
            if (my $ref = ref $def->{$_}) {
                $def->{$_} = [$def->{$_}] if $ref eq 'CODE';
            } else {
                $def->{$_} = [];
            }
        }

        $states{$self}->{table}{$state} = $def;
    }

    # Setup goto rules. We process the table a second time to catch invalid
    # references.
    while (my ($key, $def) = each %{$states{$self}->{table}}) {
        if (my $goto_spec = $def->{goto}) {
            my @gotos;
            while (@$goto_spec) {
                my $state = shift @$goto_spec;
                require Carp &&Carp::croak(
                    qq{Unknown state "$state" referenced by state "$key"}
                ) unless $states{$self}->{table}{$state};

                my $rules = shift @$goto_spec;
                my $exec = ref $rules eq 'ARRAY' ? $rules : [$rules];
                my $rule = shift @$exec;
                $rule = sub { $rule } unless ref $rule eq 'CODE';
                push @gotos, {
                    state => $state,
                    rule  => $rule,
                    exec  => $exec,
                };
            }
            $def->{goto} = \@gotos;
        } else {
            $def->{goto} = [];
        }
    }

    return $self;
}

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 start

  $dfa->start;

Starts the state machine by setting the state to the first state defined in
the call to C<new()>.

=cut

sub start {
    my $self = shift;
    my $state = $states{$self}->{start} or return $self;
    $self->state($state);
}

##############################################################################

=head3 state

  my $state = $dfa->state;
  $dfa->state($state);

Get or set the current state. Setting the state causes the C<leave> actions
of the current state to be executed, if there is a current state, and then
executes the C<enter> and C<do> actions of the new state.

=cut

sub state {
    my $self = shift;
    return $states{$self}->{current} unless @_;

    my $state = shift;
    my $def = $states{$self}->{table}{$state}
      or require Carp && Carp::croak(qq{No such state "$state"});

    if (my $state = $states{$self}->{current}) {
        # Leave the current state.
        my $def = $states{$self}->{table}{$state};
        $_->($self) for @{$def->{leave}};
    }

    # Run any transition actions.
    if (my $exec = delete $states{$self}->{exec}) {
        $_->($self) for @$exec;
    }

    # Set the new state.
    $states{$self}->{current} = $state;
    $_->($self) for @{$def->{enter}};
    $_->($self) for @{$def->{do}};
    return $self;
}

##############################################################################

=head3 check

  $dfa->check;

Checks the transition rules of the current state and transitions to the first
new state for which a rule returns a true value. If the transition rule has
transition actions, they will be executed after the C<leave> actions of the
current state (if there is one) but before the C<enter> actions of the new
state.

=cut

sub check {
    my $self = shift;
    my $def = $states{$self}->{table}{$states{$self}->{current}};
    for my $goto (@{$def->{goto}}) {
        my $code = $goto->{rule};
        next unless $code->($self);
        $states{$self}->{exec} = $goto->{exec};
        return $self->state($goto->{state});
    }
    require Carp;
    Carp::croak(qq{Cannot determine transition from state "$states{$self}->{current}"});
}

1;
__END__

=head1 Bugs

Please send bug reports to <bug-dfa-statemachine@rt.cpan.org>.

=head1 Author

=begin comment

Fake-out Module::Build. Delete if it ever changes to support =head1 headers
other than all uppercase.

=head1 AUTHOR

=end comment

David Wheeler <david@kineticode.com>

=head1 Copyright and License

Copyright (c) 2004 Kineticode, Inc. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
