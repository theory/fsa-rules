package FSA::Rules;

# $Id$

use strict;
$FSA::Rules::VERSION = '0.07';

=begin comment

Fake-out Module::Build. Delete if it ever changes to support =head1 headers
other than all uppercase.

=head1 NAME

FSA::Rules - Build simple state machines in Perl

=end comment

=head1 Name

FSA::Rules - Build simple state machines in Perl

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
         rules    => [
             pong => sub { shift->{goto} eq 'pong' },
         ],
     },

     pong => {
         on_enter => [ sub { print "Entering pong\n" },
                       sub { shift->{goto} = 'ping' } ],
         do       => sub { print "pong!\n"; },
         on_exit  => sub { print "Exiting 'pong'\n" },
         rules    => [
             ping => [ sub { shift->{goto} eq 'ping' },
                       sub { print "pong to ping\n" },
             ],
         ],
     },
  );

  $fsa->start;
  $fsa->done(sub { shift->{count} <= 21 });
  $fsa->switch until $fsa->done;

=head1 Description

This class implements a simple FSA state machine pattern, allowing you to
quickly build state machines in Perl. As a simple implementation of a powerful
concept, it differs slightly from an ideal DFA model in that it does not
enforce a single possible switch from one state to another. Rather, it short
circuits the evaluation of the rules for such switches, so that the first rule
to return a true value will trigger its switch and no other switch rules will
be checked. It differs from an NFA model in that it offers no back-tracking.
But in truth, you can use it to build a state machine that adheres to either
model.

FSA::Rules uses named states so that it's easy to tell what state you're in
and what state you want to go to. Each state may optionally define actions
that are triggered upon entering the state, after entering the state, and upon
exiting the state. They may also define rules for switching to other states,
and these rules may specify the execution of switch-specific actions. All
actions are defined in terms of anonymous subroutines that should expect the
FSA::Rules object itself to be passed as the sole argument.

FSA::Rules objects are implemented as empty hash references, so the action
subroutines can use the FSA::Rules object passed as the sole argument to stash
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
be executed when entering the state, after any switch actions defined by the
C<rules> of the previous state. The FSA::Rules object will be passed to each
code reference as the sole argument.

=item do

  do => sub { ... }
  do => [ sub {... }, sub { ... } ]

Optional. A code reference or array reference of code references. These are
the actions to be taken while in the state, and will execute after any
C<on_enter> actions. The FSA::Rules object will be passed to each code
reference as the sole argument.

=item on_exit

  on_exit => sub { ... }
  on_exit => [ sub {... }, sub { ... } ]

Optional. A code reference or array reference of code references. These will
be executed when exiting the state, before any switch actions (defined by
C<rules>). The FSA::Rules object will be passed to each code reference as the
sole argument.

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
rules will be executed in the order specified in the array reference, and
I<they will short-circuit.> So for the sake of efficiency it's worthwhile to
specify the switch rules most likely to evaluate to true before those more
likely to evaluate to false.

A rule may take the form of a code reference or an array reference of code
references. The code reference (or first code reference in the array) must
return a true value to trigger the switch to the new state, and false not to
switch to the new state. When executed, it will be passed the FSA::Rules
object, along with any other arguments passed to C<try_switch()> or
C<switch()>, the methods that execute the rule code references. These
arguments may be inputs that are specifically tested to determine whether to
switch states. To be polite, the rules should not transform the passed values
if they're returning false, as other rules may need to evaluate them (unless
you're building some sort of chaining rules--but those aren't really rules,
are they?).

Any other code references in the array will be executed during the switch,
after the C<on_exit> actions have been executed in the current state, but
before the C<on_enter> actions execute in the new state. The FSA::Rules object
will be passed in as the sole argument.

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
        done  => sub { return },
        stack => [],
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

=head2 Machine Interface

These methods generally apply to the FSA::Rules machine, and will be called by
users of the machine, rather than by the state actions. See L<State
Interface|"State Interface"> for the interface for state actions.

=head3 start

  my $state = $fsa->start;

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

    # Push the new state onto the stack.
    push @{$states{$self}->{stack}}
      => [$state => { result => undef, message => undef}];

    # Set the new state.
    $states{$self}->{current} = $state;
    $_->($self) for @{$def->{on_enter}};
    $_->($self) for @{$def->{do}};
    return $self;
}

##############################################################################

=head3 try_switch

  my $state = $fsa->try_switch;
  $state = $fsa->try_switch(@inputs);

Checks the switch rules of the current state and switches to the first new
state for which a rule returns a true value. All arguments passed to
C<try_switch> will be passed to the switch rule code reference as inputs. If
the switch rule evaluates to true and there are additional switch actions,
these will be executed after the C<on_exit> actions of the current state (if
there is one) but before the C<on_enter> actions of the new state.

Returns the name of the state to which it switched and C<undef> if it cannot
switch to another state.

=cut

sub try_switch {
    my $self = shift;
    my $def = $states{$self}->{table}{$states{$self}->{current}};
    for my $rule (@{$def->{rules}}) {
        my $code = $rule->{rule};
        next unless $code->($self, @_);
        $states{$self}->{exec} = $rule->{exec};
        $self->state($rule->{state});
        return $rule->{state};
    }
    return undef;
}

##############################################################################

=head3 switch

  my $state = eval { $fsa->switch(@inputs) };
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
  $fsa->done( sub {...} );

Get or set a value to indicate whether the engine is done running. Or set it
to a code reference to have that code reference called each time C<done()> is
called without arguments and have I<its> return value returned. A code
reference should expect the FSA::Rules object passed in as its only argument.

This method can be useful for checking to see if your state engine is done
running, and calling C<switch()> when it isn't. States can set it to a true
value when they consider processing complete, or you can use a code reference
that evaluates "done-ness" itself. Something like this:

  my $fsa = FSA::Rules->new(
      foo => {
          do    => { $_[0]->done(1) if ++$_[0]->{count} >= 5 },
          rules => [ do => 1 ],
      }
  );

Or this:

  my $fsa = FSA::Rules->new(
      foo => {
          do    => { ++shift->{count} },
          rules => [ do => 1 ],
      }
  );
  $fsa->done( sub { shift->{count} >= 5 });

Then you can just run the state engine, checking C<done()> to find out when
it's, uh, done.

  $fsa->start;
  $fsa->switch until $fsa->done;

Although you could just use the C<run()> method if you wanted to do that.

=cut

sub done {
    my $self = shift;
    if (@_) {
        my $done = shift;
        $states{$self}->{done} = ref $done eq 'CODE' ? $done : sub { $done };
        return $self;
    }
    my $code = $states{$self}->{done};
    return $code->($self);
}

##############################################################################

=head3 run

  $fsa->run;

This method starts the FSA::Rules engine (if it hasn't already been set to a
state) by calling C<start()>, and then calls the C<switch()> method repeatedly
until C<done()> returns a true value. In other words, it's a convenient
shortcut for:

    $fsa->start unless $self->state;
    $fsa->switch until $self->done;

But be careful when calling this method. If you have no failed switches
between states and the states never set the C<done> attribute to a true value,
then this method will never die or return, but run forever. So plan carefully!

Returns the FSA::Rules object.

=cut

sub run {
    my $self = shift;
    $self->start unless $self->state;
    $self->switch until $self->done;
    return $self;
}

##############################################################################

=head3 reset

  $fsa->reset;

The C<reset()> method will clear the stack and set the current state to
C<undef>. Use this method when you want to reuse your state machine. Returns
the DFA::Rules object.

  my $fsa = FSA::Rules->new(@state_machine);
  $fsa->done(sub {$done});
  $fsa->run;
  # do a bunch of stuff
  $fsa->reset->run;

=cut

sub reset {
    my $self = shift;
    $states{$self}->{stack}   = [];
    $states{$self}->{current} = undef;
    return $self;
}

##############################################################################

=head2 State Interface

Eventually states will be objects. For the time being they're not. This
interface may therefore change, particularly the output of
C<raw_stacktrace()>.

##############################################################################

=head3 set_result

  my @states = (
    # ...
    some_state => {
        do => sub {
            my $fsa = shift;
            $fsa->set_result(1);
        },
        rules => [
            bad  => sub { ! shift->result },
            good => sub {   shift->result },
        ]
    },
    # ...
  );

This is a useful method to store results on a per-state basis. Anything can be
stored in the result slot. The contents of the result slot can be returned
with C<message()> or viewed in a C<stacktrace> or C<raw_stacktrace>.

Note that C<set_result()> operates on a per-state basis. Calling it in an
C<on_entry> action, a C<do> action and an C<on_exit> action will result in
only the C<on_exit> value remaining.

=cut

sub set_result {
    my $self = shift;
    $states{$self}->{stack}[-1][1]{result} = shift;
    return $self;
}

##############################################################################

=head3 set_message

  my @states = (
    # ...
    some_state => {
        do => sub {
            my $fsa = shift;
            $fsa->set_message('Success!');
        },
        rules => [
            bad  => sub { ! shift->message },
            good => sub {   shift->message },
        ]
    },
    # ...
  );

This is a useful method to store messages on a per-state basis. Anything can
be stored in the message slot. The contents of the message slot can be
returned with C<message()> or viewed in a C<stacktrace> or C<raw_stacktrace>.

Note that C<set_message()> operates on a per-state basis. Calling it in an
C<on_entry> action, a C<do> action and an C<on_exit> action will result in
only the C<on_exit> value remaining.

There is no difference between the interface of this method and that of the
C<set_result()> method other than storing their values in different slots
(that is, they don't set each other's values).

=cut

sub set_message {
    my $self = shift;
    $states{$self}->{stack}[-1][1]{message} = shift;
    return $self;
}

##############################################################################

=head3 result

  $fsa->result([$state]);

Fetch the contents of the result slot. If no state is specified, it will
always return the results for the current state. If a state name is provided,
it will return the I<last> result for the named state if called in scalar
context. Otherwise, it will return I<all> of the results for the given state,
from first to last.

=cut

sub result {
    my $self = shift;
    my @results = $self->_state_slot('result', @_);
    return wantarray ? @results : $results[-1];
}

##############################################################################

=head3 message

  $fsa->message([$state]);

Fetch the contents of the message slot. If no state is specified, it will
always return the messages for the current state. If a state name is provided,
it will return the I<last> message for the named state if called in scalar
context. Otherwise, it will return I<all> of the messages for the given state,
from first to last.

There is no difference between the interface of this method and that of the
C<result()> method other than storing their values in different slots (that
is, they don't return each other's values).

=cut

sub message {
    my $self = shift;
    my @messages = $self->_state_slot('message', @_);
    return wantarray ? @messages : $messages[-1];
}

# not documented because this *will* change when state objects
# are introduced.

sub _state_slot {
    my $self = shift;
    my $slot = shift;
    return $states{$self}->{stack}[-1][1]{$slot} unless @_;
    my $state = shift;
    return
      map  { $_->[1]{$slot} }
      grep { $_->[0] eq $state }
        @{$self->raw_stacktrace};
}

##############################################################################

=head3 stack

  my $stack = $fsa->stack;

Returns an array reference of all states the machine has been in since it was
created or since C<reset()> was last called, beginning with the first state
and ending with the current state. No state name will be added to the stack
until the machine has been in that state. This method is useful for debugging.

=cut

sub stack {
    my $self = shift;
    return [map { $_->[0] } @{$states{$self}->{stack}}];
}

##############################################################################

=head3 raw_stacktrace

  my $stacktrace = $fsa->raw_stacktrace;

Similar to C<stack()>, This method returns an array reference of the states
that the machine has been in. Each state is an array reference with two
elements. The first element is the name of the state and the second element is
a hash reference with two keys, "result" and "message". These are set to the
values (if used) set by the C<set_result()> and C<set_message()> methods.

A sample state:

 [
     some_state,
     {
         result  => 7,
         message => 'A human readable message'
     }
 ]

=cut

sub raw_stacktrace {
    my $self = shift;
    return $states{$self}->{stack};
}

##############################################################################

=head3 stacktrace

  my $trace = $fsa->stacktrace;

Similar to the C<stack()> method, but it also includes all C<result>s and
C<message>s. However, this returns a human readable stacktrace with nicely
formatted data (using Data::Dumper). If you need the raw data, see
C<raw_stacktrace()>.

For example, if your state machine ran for only three states, the output may
resemble the following:

 print $fsa->stacktrace;

State: foo
{
  message => 'some message',
  result => 'a'
}

State: bar
{
  message => 'another message',
  result => 1
}

State: bar
{
  message => 'and yet another message',
  result => 2
}

=cut

sub stacktrace {
    my $states     = shift->raw_stacktrace;
    my $stacktrace = '';
    require Data::Dumper;
    local $Data::Dumper::Terse     = 1;
    local $Data::Dumper::Indent    = 1;
    local $Data::Dumper::Quotekeys = 0;
    foreach my $state (@$states) {
        $stacktrace .= "State: $state->[0]\n";
        $stacktrace .= Data::Dumper::Dumper($state->[1]);
        $stacktrace .= "\n";
    }
    return $stacktrace;
}

##############################################################################

=head3 prev_state

  my $prev_state = $fsa->prev_state;

This returns the name of the previous state. This is useful in states where
you need to know the state you came from. Very useful in "fail" states.

=cut

sub prev_state {
    my $self = shift;
    my $stacktrace = $self->raw_stacktrace;
    return unless @$stacktrace > 1;
    return $stacktrace->[-2][0];
}

1;
__END__

=head1 To Do

=over

=item Add optional parameters to new(). Paramters include:

=over

=item done

=item start_state

=item strict

=item error_handler

=back

=item Create state objects.

=item Have start() not set the state if there is already a state?

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
