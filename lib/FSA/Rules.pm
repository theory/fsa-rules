package FSA::Rules;

# $Id$

use strict;
$FSA::Rules::VERSION = '0.02';

=head1 Name

=begin comment

Fake-out Module::Build. Delete if it ever changes to support =head1 headers
other than all uppercase.

=head1 NAME

=end comment

FSA::Rules - A simple Perl state machine

=head1 Synopsis

  use FSA::Rules;

  my $fsa = FSA::Rules->new(
     ping => {
         on_enter => sub { print "Entering ping\n" },
         do       => [ sub { print "ping!\n" },
                       sub { shift->{goto} = 'pong'; },
                       sub { shift->{count}++ }
         ],
         on_exit  => sub { print "Exiting 'ping'\n" },
         rules   => [
             pong => sub { shift->{goto} eq 'pong' },
         ],
     },

     pong => {
         on_enter => [ sub { print "Entering pong\n" },
                       sub { shift->{goto} = 'ping' } ],
         do       => sub { print "pong!\n"; },
         on_exit  => sub { print "Exiting 'pong'\n" },
         rules   => [
             ping => [ sub { shift->{goto} eq 'ping' },
                       sub { print "pong to ping\n" },
             ],
         ],
     },
  );

  $fsa->start;
  $fsa->check while $fsa->{count} <= 21;

=head1 Description

This class implements a simple FSA state machine. As a simple implementation
of a powerful concept, it differs slightly from the ideal FSA model in that it
does not enforce a single possible switch from one state to another. Rather,
it short circuits the evaluation of the rules for such switches, so that the
first rule to return a true value will trigger its switch and no other
switch rules will be checked.

FSA::Rules uses named states so that it's easy to tell what state you're in
and what state you want to go to. Each state may optionally define actions
that are triggered upon entering the state, after entering the state, and upon
exiting the state. They may also define rules for switching to other states,
and these rules may specify the execution of switch-specific actions. All
actions are defined in terms of anonymous subroutines that should expect the
FSA object itself to be passed as the sole argument.

FSA::Rules objects are implemented as empty hash references, so the action
subroutines can use the FSA::Rules object passed as the sole argument to store
data for other states to access, without the possibility of interfering with
the state machine itself.

=cut

##############################################################################

=head1 Class Interface

=head2 Constructor

=head3 new

  my $fsa = FSA::Rules->new(@state_table);

Constructs and returns a new FSA::Rules object. The parameters define the
state table, where each key is the name of a state and the following hash
reference defines the state, its actions and its switch rules. The first state
parameter is considered to be the start state; call the C<start()> method to
automatically enter that state.

The supported keys in the state definition hash references are:

=over

=item on_enter

  on_enter => sub { ... }
  on_enter => [ sub {... }, sub { ... } ]

Optional. A code reference or array reference of code references. These will
be executed when entering the state. The state object will be passed to each
code reference as the sole argument.

=item do

  do => sub { ... }
  do => [ sub {... }, sub { ... } ]

Optional. A code reference or array reference of code references. These are
the actions to be taken while in the state, and will execute after any
C<on_enter> actions and switch actions (defined by C<rules>). The state
object will be passed to each code reference as the sole argument.

=item on_exit

  on_exit => sub { ... }
  on_exit => [ sub {... }, sub { ... } ]

Optional. A code reference or array reference of code references. These will
be executed when exiting the state, before any switch actions (defined by
C<rules>). The state object will be passed to each code reference as the sole
argument.

=item rules

  rules => [
      state1 => \&state1_rule,
      state2 => [ \&state2_rule, \&action ],
      state3 => 1,
      state4 => [ 1, \&action ],
  ]

Optional. The rules for switching from the state to other states. This is an
array reference but shaped like a hash. The keys are the states to consider
moving to, while the values are the rules for switching to that state. The
rules will be executed in the order specified in the array reference, and will
short-circuit. So for efficiency it's worthwhile to specify the switch rules
most likely to evaluate to true before those less likely to evaluate to true.

A rule may take the form of a code reference or an array reference of code
references. The code reference or first code reference in the array must
return true to trigger the switch to the new state, and false not to switch to
the new state. Any other code references in the array will be executed during
the switch, after the C<on_exit> actions have been executed in the current
state, but before the C<on_enter> actions execute in the new state.

A rule may also be simply specify scalar variable, in which case that value
will be used to determine whether the rule evaluates to a true or false value.
You may also use a simple scalar as the first item in an array reference if
you also need to specify switch actions. Either way, a true value always
triggers the switch, while a false value never will.

=back

=cut

my %states;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $states{$self} = {
        table => {},
        start => $_[0],
    };

    while (@_) {
        my $state = shift;
        my $def = shift;
        require Carp && Carp::croak(qq{The state "$state" already exists})
          if $states{$self}->{table}{$state};

        # Setup enter, exit, and do actions.
        for (qw(on_enter do on_exit)) {
            if (my $ref = ref $def->{$_}) {
                $def->{$_} = [$def->{$_}] if $ref eq 'CODE';
            } else {
                $def->{$_} = [];
            }
        }

        $states{$self}->{table}{$state} = $def;
    }

    # Setup rules. We process the table a second time to catch invalid
    # references.
    while (my ($key, $def) = each %{$states{$self}->{table}}) {
        if (my $rule_spec = $def->{rules}) {
            my @rules;
            while (@$rule_spec) {
                my $state = shift @$rule_spec;
                require Carp &&Carp::croak(
                    qq{Unknown state "$state" referenced by state "$key"}
                ) unless $states{$self}->{table}{$state};

                my $rules = shift @$rule_spec;
                my $exec = ref $rules eq 'ARRAY' ? $rules : [$rules];
                my $rule = shift @$exec;
                $rule = sub { $rule } unless ref $rule eq 'CODE';
                push @rules, {
                    state => $state,
                    rule  => $rule,
                    exec  => $exec,
                };
            }
            $def->{rules} = \@rules;
        } else {
            $def->{rules} = [];
        }
    }

    return $self;
}

##############################################################################

=head1 Instance Interface

=head2 Instance Methods

=head3 start

  $fsa->start;

Starts the state machine by setting the state to the first state defined in
the call to C<new()>. Returns the name of the start state.

=cut

sub start {
    my $self = shift;
    my $state = $states{$self}->{start};
    return $self unless defined $state;
    $self->state($state);
    return $state;
}

##############################################################################

=head3 state

  my $state = $fsa->state;
  $fsa->state($state);

Get or set the current state. Setting the state causes the C<on_exit> actions
of the current state to be executed, if there is a current state, and then
executes the C<on_enter> and C<do> actions of the new state. Returns the
FSA::Rules object when setting the state.

=cut

sub state {
    my $self = shift;
    return $states{$self}->{current} unless @_;

    my $state = shift;
    my $def = $states{$self}->{table}{$state}
      or require Carp && Carp::croak(qq{No such state "$state"});

    if (my $state = $states{$self}->{current}) {
        # Exit the current state.
        my $def = $states{$self}->{table}{$state};
        $_->($self) for @{$def->{on_exit}};
    }

    # Run any switch actions.
    if (my $exec = delete $states{$self}->{exec}) {
        $_->($self) for @$exec;
    }

    # Set the new state.
    $states{$self}->{current} = $state;
    $_->($self) for @{$def->{on_enter}};
    $_->($self) for @{$def->{do}};
    return $self;
}

##############################################################################

=head3 try_switch

  my $state = $fsa->try_switch;

Checks the switch rules of the current state and switches to the first new
state for which a rule returns a true value. If the switch rule has switch
actions, they will be executed after the C<on_exit> actions of the current
state (if there is one) but before the C<on_enter> actions of the new state.
Returns the name of the state to which it switched and C<undef> if it cannot
switch to another state.

=cut

sub try_switch {
    my $self = shift;
    my $def = $states{$self}->{table}{$states{$self}->{current}};
    for my $rule (@{$def->{rules}}) {
        my $code = $rule->{rule};
        next unless $code->($self);
        $states{$self}->{exec} = $rule->{exec};
        $self->state($rule->{state});
        return $rule->{state};
    }
    return undef;
}

##############################################################################

=head3 switch

  my $state = eval { $fsa->switch };
  print "No can do" if $@;

The fatal form of C<try_switch()>. This method attempts to switch states and
returns the name of the new state on success and throws an exception on
failure.

=cut

sub switch {
    my $self = shift;
    my $ret = $self->try_switch(@_);
    return $ret if defined $ret;
    require Carp;
    Carp::croak(
        qq{Cannot determine transition from state "$states{$self}->{current}"}
    );
}

##############################################################################

=head3 done

  my $done = $fsa->done;
  $fsa->done($done);

Get or set a value to indicate whether the engine is done running. This can be
useful for state actions to set to the appropriate value, and then the user of
the state object can simply call done as appropriate. Something like this:

  $fsa->start;
  $fsa->switch until $fsa->done;

Although you could just use the C<run()> method if you wanted to do that.

=cut

sub done {
    my $self = shift;
    return $states{$self}->{done} unless @_;
    $states{$self}->{done} = shift;
    return $self;
}

##############################################################################

=head3 run

  $fsa->run;

This method starts the FSA engine (if it hasn't already been set to a state)
and then calls the C<switch()> method repeatedly until C<done()> returns a
true value. IOW, it's a convenient shortcut for:

    $fsa->start unless $states{$self}->{current};
    $fsa->switch until $self->done;

But be careful when calling this method. If you have no failed swtiches
between states and the states never set the C<done> attribute to a true value,
then this method will never die or return, but run forever. So plan carefully!

Returns the FSA object.

=cut

sub run {
    my $self = shift;
    $self->start unless $states{$self}->{current};
    $self->switch until $self->done;
    return $self;
}

1;
__END__

=head1 To Do

=over

=item Add tracing.

=back

=head1 Bugs

Please send bug reports to <bug-fsa-statemachine@rt.cpan.org>.

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
