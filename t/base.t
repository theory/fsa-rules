#!/usr/bin/perl -w

# $Id$

use strict;
#use Test::More 'no_plan';
use Test::More tests => 147;

BEGIN { use_ok('DFA::StateMachine') }

ok my $dfa = DFA::StateMachine->new, "Construct an empty state machine";
isa_ok $dfa, 'DFA::StateMachine';

ok $dfa = DFA::StateMachine->new(
    foo => {},
), "Construct with a single state";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->state('foo'), $dfa, "... We should be able to se the state";
is $dfa->state, 'foo', "... The current state should be 'foo'";

# Try a bogus state.
eval { $dfa->state('bogus') };
ok my $err = $@, "... Assigning a bogus state should fail";
like $err, qr/No such state "bogus"/, "... And throw the proper exception";

# Try a do code ref.
ok $dfa = DFA::StateMachine->new(
    foo => {
        do => sub { shift->{foo}++ }
    },
), "Construct with a single state with an action";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The code should not have been executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The code should now have been executed";

# Try a do code array ref.
ok $dfa = DFA::StateMachine->new(
    foo => {
        do => [ sub { shift->{foo}++ }, sub { shift->{foo} ++ } ],
    },
), "Construct with a single state with two actions";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The code should not have been executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 2, "... Both actions should now have been executed";

# Try a single enter action.
ok $dfa = DFA::StateMachine->new(
    foo => {
        enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ }
    },
), "Construct with a single state with an enter action";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The code should not have been executed";
is $dfa->{foo_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The code should now have been executed";
is $dfa->{foo_enter}, 1, "... The enter code should have executed";

# Try an enter action array ref.
ok $dfa = DFA::StateMachine->new(
    foo => {
        enter => [ sub { shift->{foo_enter}++ }, sub { shift->{foo_enter}++ } ],
        do => sub { shift->{foo}++ }
    },
), "Construct with a single state with multiple enter actions";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The code should not have been executed";
is $dfa->{foo_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The code should now have been executed";
is $dfa->{foo_enter}, 2, "... Both enter actions should have executed";

# Try a second state with leave actions in the first state.
ok $dfa = DFA::StateMachine->new(
    foo => {
        enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ },
        leave => sub { shift->{foo_leave}++ },
    },
    bar => {
        enter => sub { shift->{bar_enter}++ },
        do => sub { $_[0]->{bar} = $_[0]->{bar_enter} }
    },
), "Construct with a two states and a leave action";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The foo code should not have been executed";
is $dfa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $dfa->{bar}, undef, "... The bar code should not have been executed";
is $dfa->{bar_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state to 'foo'";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The 'foo' code should now have been executed";
is $dfa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $dfa->{foo_leave}, undef, "... The  'foo' leave action should not have executed";
is $dfa->state('bar'), $dfa, "... We should be able to change the state to 'bar'";
is $dfa->{foo_leave}, 1, "... The 'foo' leave action should have executed";
is $dfa->{bar}, 1, "... The 'bar' code should now have been executed";
is $dfa->{bar_enter}, 1, "... The 'bar' enter action should have executed";

# Try a second state with multiple leave actions in the first state.
ok $dfa = DFA::StateMachine->new(
    foo => {
        enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ },
        leave => [sub { shift->{foo_leave}++ }, sub { shift->{foo_leave}++ } ],
    },
    bar => {
        enter => sub { shift->{bar_enter}++ },
        do => sub { $_[0]->{bar} = $_[0]->{bar_enter} }
    },
), "Construct with a two states and multiple leave actions";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The foo code should not have been executed";
is $dfa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $dfa->{bar}, undef, "... The bar code should not have been executed";
is $dfa->{bar_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state to 'foo'";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The 'foo' code should now have been executed";
is $dfa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $dfa->{foo_leave}, undef, "... The  'foo' leave action should not have executed";
is $dfa->state('bar'), $dfa, "... We should be able to change the state to 'bar'";
is $dfa->{foo_leave}, 2, "... Both 'foo' leave actions should have executed";
is $dfa->{bar}, 1, "... The 'bar' code should now have been executed";
is $dfa->{bar_enter}, 1, "... The  'bar' enter action should have executed";

# Set up transition rules (gotos).
ok $dfa = DFA::StateMachine->new(
    foo => {
        enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ },
        leave => sub { shift->{foo_leave}++ },
        goto => [
            bar => sub { shift->{foo} },
        ],
    },
    bar => {
        enter => sub { shift->{bar_enter}++ },
        do => sub { $_[0]->{bar} = $_[0]->{bar_enter} },
    },
), "Construct with a two states and a transition rule";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The foo code should not have been executed";
is $dfa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $dfa->{bar}, undef, "... The bar code should not have been executed";
is $dfa->{bar_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state to 'foo'";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The 'foo' code should now have been executed";
is $dfa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $dfa->{foo_leave}, undef, "... The 'foo' leave action should not have executed";
is $dfa->check, $dfa, "... The check method should return the DFA object";
is $dfa->{foo_leave}, 1, "... Now the 'foo' leave action should have executed";
is $dfa->{bar}, 1, "... And the 'bar' code should now have been executed";
is $dfa->{bar_enter}, 1, "... And the 'bar' enter action should have executed";
eval { $dfa->check };

# There are no transitions from bar.
eval { $dfa->check };
ok $err = $@, "... Another check should fail";
like $err, qr/Cannot determine transition from state "bar"/,
  "... And throw the proper exception";

# Try transition actions.
ok $dfa = DFA::StateMachine->new(
    foo => {
        enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ },
        leave => sub { shift->{foo_leave}++ },
        goto => [
            bar => [sub { shift->{foo} } => sub { shift->{foo_bar}++ } ],
        ],
    },
    bar => {
        enter => sub { $_[0]->{bar_enter} = $_[0]->{foo_bar} },
        do => sub { $_[0]->{bar} = $_[0]->{bar_enter} }
    },
), "Construct with a two states and a transition rule with its own action";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The foo code should not have been executed";
is $dfa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $dfa->{bar}, undef, "... The bar code should not have been executed";
is $dfa->{bar_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state to 'foo'";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The 'foo' code should now have been executed";
is $dfa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $dfa->{foo_leave}, undef, "... The 'foo' leave action should not have executed";
is $dfa->check, $dfa, "... The check method should return the DFA object";
is $dfa->{foo_leave}, 1, "... Now the 'foo' leave action should have executed";
is $dfa->{bar}, 1, "... And the 'bar' code should now have been executed";
is $dfa->{foo_bar}, 1, "... And the 'foo' to 'bar' transition action should have executed";
is $dfa->{bar_enter}, 1, "... And the 'bar' enter action should have executed";

# Try a simple true value transition check.
ok $dfa = DFA::StateMachine->new(
    foo => {
        enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ },
        leave => sub { shift->{foo_leave}++ },
        goto => [
            bar => 1
        ],
    },
    bar => {
        enter => sub { shift->{bar_enter}++ },
        do => sub { $_[0]->{bar} = $_[0]->{bar_enter} }
    },
), "Construct with a two states and a transition rule of '1'";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The foo code should not have been executed";
is $dfa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $dfa->{bar}, undef, "... The bar code should not have been executed";
is $dfa->{bar_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state to 'foo'";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The 'foo' code should now have been executed";
is $dfa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $dfa->{foo_leave}, undef, "... The 'foo' leave action should not have executed";
is $dfa->check, $dfa, "... The check method should return the DFA object";
is $dfa->{foo_leave}, 1, "... Now the 'foo' leave action should have executed";
is $dfa->{bar}, 1, "... And the 'bar' code should now have been executed";
is $dfa->{bar_enter}, 1, "... And the 'bar' enter action should have executed";

# Try a simple true value transition check with transition actions.
ok $dfa = DFA::StateMachine->new(
    foo => {
        enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ },
        leave => sub { shift->{foo_leave}++ },
        goto => [
            bar => [1, sub { shift->{foo_bar}++ } ],
        ],
    },
    bar => {
        enter => sub { $_[0]->{bar_enter} = $_[0]->{foo_bar} },
        do => sub { $_[0]->{bar} = $_[0]->{bar_enter} }
    },
), "Construct with a two states, a transition rule of '1', and a transition action";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The foo code should not have been executed";
is $dfa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $dfa->{bar}, undef, "... The bar code should not have been executed";
is $dfa->{bar_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state to 'foo'";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The 'foo' code should now have been executed";
is $dfa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $dfa->{foo_leave}, undef, "... The 'foo' leave action should not have executed";
is $dfa->check, $dfa, "... The check method should return the DFA object";
is $dfa->{foo_leave}, 1, "... Now the 'foo' leave action should have executed";
is $dfa->{foo_bar}, 1, "... And the 'foo' to 'bar' transition action should have executed";
is $dfa->{bar}, 1, "... And the 'bar' code should now have been executed";
is $dfa->{bar_enter}, 1, "... And the 'bar' enter action should have executed";

# Try start().
ok $dfa = DFA::StateMachine->new(
    foo => {
        do => sub { shift->{foo}++ }
    },
), "Construct with a single state with an enter action";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The code should not have been executed";
is $dfa->start, $dfa, "... The start method should return the DFA object";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The code should now have been executed";

# Try start() with a second state.
ok $dfa = DFA::StateMachine->new(
    foo => {
        do => sub { shift->{foo}++ }
    },
    bar => {
        do => sub { shift->{bar}++ }
    },
), "Construct with a single state with an enter action";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The 'foo' code should not have been executed";
is $dfa->{bar}, undef, "... The 'bar' code should not have been executed";
is $dfa->start, $dfa, "... The start method should return the DFA object";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The code should now have been executed";
is $dfa->{bar}, undef, "... The 'bar' code still should not have been executed";

# Try a bad transition state name.
eval {
    DFA::StateMachine->new(
        foo => { goto => [bad => 1] }
    )
};

ok $err = $@, "A bad state name in goto rules should fail";
like $err, qr/Unknown state "bad" referenced by state "foo"/,
  "... And give the appropriate error message";
