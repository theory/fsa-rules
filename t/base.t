#!/usr/bin/perl -w

# $Id$

use strict;
#use Test::More 'no_plan';
use Test::More tests => 164;

BEGIN { use_ok('DFA::Rules') }

ok my $dfa = DFA::Rules->new, "Construct an empty state machine";
isa_ok $dfa, 'DFA::Rules';

ok $dfa = DFA::Rules->new(
    foo => {},
), "Construct with a single state";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->state('foo'), $dfa, "... We should be able to se the state";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->done, undef, "... It should not be done";
is $dfa->done(1), $dfa, "... But we can set doneness";
is $dfa->done, 1, "... And then retreive that value";

# Try a bogus state.
eval { $dfa->state('bogus') };
ok my $err = $@, "... Assigning a bogus state should fail";
like $err, qr/No such state "bogus"/, "... And throw the proper exception";

# Try a do code ref.
ok $dfa = DFA::Rules->new(
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
ok $dfa = DFA::Rules->new(
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
ok $dfa = DFA::Rules->new(
    foo => {
        on_enter => sub { shift->{foo_enter}++ },
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
ok $dfa = DFA::Rules->new(
    foo => {
        on_enter => [ sub { shift->{foo_enter}++ }, sub { shift->{foo_enter}++ } ],
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

# Try a second state with exit actions in the first state.
ok $dfa = DFA::Rules->new(
    foo => {
        on_enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ },
        on_exit => sub { shift->{foo_exit}++ },
    },
    bar => {
        on_enter => sub { shift->{bar_enter}++ },
        do => sub { $_[0]->{bar} = $_[0]->{bar_enter} }
    },
), "Construct with a two states and a exit action";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The foo code should not have been executed";
is $dfa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $dfa->{bar}, undef, "... The bar code should not have been executed";
is $dfa->{bar_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state to 'foo'";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The 'foo' code should now have been executed";
is $dfa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $dfa->{foo_exit}, undef, "... The  'foo' exit action should not have executed";
is $dfa->state('bar'), $dfa, "... We should be able to change the state to 'bar'";
is $dfa->{foo_exit}, 1, "... The 'foo' exit action should have executed";
is $dfa->{bar}, 1, "... The 'bar' code should now have been executed";
is $dfa->{bar_enter}, 1, "... The 'bar' enter action should have executed";

# Try a second state with multiple exit actions in the first state.
ok $dfa = DFA::Rules->new(
    foo => {
        on_enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ },
        on_exit => [sub { shift->{foo_exit}++ }, sub { shift->{foo_exit}++ } ],
    },
    bar => {
        on_enter => sub { shift->{bar_enter}++ },
        do => sub { $_[0]->{bar} = $_[0]->{bar_enter} }
    },
), "Construct with a two states and multiple exit actions";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The foo code should not have been executed";
is $dfa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $dfa->{bar}, undef, "... The bar code should not have been executed";
is $dfa->{bar_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state to 'foo'";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The 'foo' code should now have been executed";
is $dfa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $dfa->{foo_exit}, undef, "... The  'foo' exit action should not have executed";
is $dfa->state('bar'), $dfa, "... We should be able to change the state to 'bar'";
is $dfa->{foo_exit}, 2, "... Both 'foo' exit actions should have executed";
is $dfa->{bar}, 1, "... The 'bar' code should now have been executed";
is $dfa->{bar_enter}, 1, "... The  'bar' enter action should have executed";

# Set up switch rules (rules).
ok $dfa = DFA::Rules->new(
    foo => {
        on_enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ },
        on_exit => sub { shift->{foo_exit}++ },
        rules => [
            bar => sub { shift->{foo} },
        ],
    },
    bar => {
        on_enter => sub { shift->{bar_enter}++ },
        do => sub { $_[0]->{bar} = $_[0]->{bar_enter} },
    },
), "Construct with a two states and a switch rule";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The foo code should not have been executed";
is $dfa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $dfa->{bar}, undef, "... The bar code should not have been executed";
is $dfa->{bar_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state to 'foo'";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The 'foo' code should now have been executed";
is $dfa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $dfa->{foo_exit}, undef, "... The 'foo' exit action should not have executed";
is $dfa->try_switch, 'bar', "... The try_switch method should return 'bar'";
is $dfa->{foo_exit}, 1, "... Now the 'foo' exit action should have executed";
is $dfa->{bar}, 1, "... And the 'bar' code should now have been executed";
is $dfa->{bar_enter}, 1, "... And the 'bar' enter action should have executed";

# There are no switchs from bar.
eval { $dfa->switch };
ok $err = $@, "... Another attempt to switch should fail";
like $err, qr/Cannot determine transition from state "bar"/,
  "... And throw the proper exception";

# Try switch actions.
ok $dfa = DFA::Rules->new(
    foo => {
        on_enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ },
        on_exit => sub { shift->{foo_exit}++ },
        rules => [
            bar => [sub { shift->{foo} } => sub { shift->{foo_bar}++ } ],
        ],
    },
    bar => {
        on_enter => sub { $_[0]->{bar_enter} = $_[0]->{foo_bar} },
        do => sub { $_[0]->{bar} = $_[0]->{bar_enter} }
    },
), "Construct with a two states and a switch rule with its own action";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The foo code should not have been executed";
is $dfa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $dfa->{bar}, undef, "... The bar code should not have been executed";
is $dfa->{bar_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state to 'foo'";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The 'foo' code should now have been executed";
is $dfa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $dfa->{foo_exit}, undef, "... The 'foo' exit action should not have executed";
is $dfa->switch, 'bar', "... The switch method should return 'bar'";
is $dfa->{foo_exit}, 1, "... Now the 'foo' exit action should have executed";
is $dfa->{bar}, 1, "... And the 'bar' code should now have been executed";
is $dfa->{foo_bar}, 1, "... And the 'foo' to 'bar' switch action should have executed";
is $dfa->{bar_enter}, 1, "... And the 'bar' enter action should have executed";

# Try a simple true value switch rule.
ok $dfa = DFA::Rules->new(
    foo => {
        on_enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ },
        on_exit => sub { shift->{foo_exit}++ },
        rules => [
            bar => 1
        ],
    },
    bar => {
        on_enter => sub { shift->{bar_enter}++ },
        do => sub { $_[0]->{bar} = $_[0]->{bar_enter} }
    },
), "Construct with a two states and a switch rule of '1'";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The foo code should not have been executed";
is $dfa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $dfa->{bar}, undef, "... The bar code should not have been executed";
is $dfa->{bar_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state to 'foo'";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The 'foo' code should now have been executed";
is $dfa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $dfa->{foo_exit}, undef, "... The 'foo' exit action should not have executed";
is $dfa->switch, 'bar', "... The switch method should return 'bar'";
is $dfa->{foo_exit}, 1, "... Now the 'foo' exit action should have executed";
is $dfa->{bar}, 1, "... And the 'bar' code should now have been executed";
is $dfa->{bar_enter}, 1, "... And the 'bar' enter action should have executed";

# Try a simple true value switch rule with switch actions.
ok $dfa = DFA::Rules->new(
    foo => {
        on_enter => sub { shift->{foo_enter}++ },
        do => sub { shift->{foo}++ },
        on_exit => sub { shift->{foo_exit}++ },
        rules => [
            bar => [1, sub { shift->{foo_bar}++ } ],
        ],
    },
    bar => {
        on_enter => sub { $_[0]->{bar_enter} = $_[0]->{foo_bar} },
        do => sub { $_[0]->{bar} = $_[0]->{bar_enter} }
    },
), "Construct with a two states, a switch rule of '1', and a switch action";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The foo code should not have been executed";
is $dfa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $dfa->{bar}, undef, "... The bar code should not have been executed";
is $dfa->{bar_enter}, undef, "... The enter code should not have executed";
is $dfa->state('foo'), $dfa, "... We should be able to set the state to 'foo'";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The 'foo' code should now have been executed";
is $dfa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $dfa->{foo_exit}, undef, "... The 'foo' exit action should not have executed";
is $dfa->switch, 'bar', "... The switch method should return 'bar'";
is $dfa->{foo_exit}, 1, "... Now the 'foo' exit action should have executed";
is $dfa->{foo_bar}, 1, "... And the 'foo' to 'bar' switch action should have executed";
is $dfa->{bar}, 1, "... And the 'bar' code should now have been executed";
is $dfa->{bar_enter}, 1, "... And the 'bar' enter action should have executed";

# Try start().
ok $dfa = DFA::Rules->new(
    foo => {
        do => sub { shift->{foo}++ }
    },
), "Construct with a single state with an enter action";

is $dfa->state, undef, "... The current state should be undefined";
is $dfa->{foo}, undef, "... The code should not have been executed";
is $dfa->start, 'foo', "... The start method should return the start state";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The code should now have been executed";

# Try start() with a second state.
ok $dfa = DFA::Rules->new(
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
is $dfa->start, 'foo', "... The start method should return the start state";
is $dfa->state, 'foo', "... The current state should be 'foo'";
is $dfa->{foo}, 1, "... The code should now have been executed";
is $dfa->{bar}, undef, "... The 'bar' code still should not have been executed";

# Try a bad switch state name.
eval {
    DFA::Rules->new(
        foo => { rules => [bad => 1] }
    )
};

ok $err = $@, "A bad state name in rules should fail";
like $err, qr/Unknown state "bad" referenced by state "foo"/,
  "... And give the appropriate error message";

# Try numbered states.
ok $dfa = DFA::Rules->new(
    0 => { rules => [ 1 => 1 ] },
    1 => {},
), "Construct with numbered states";
is $dfa->start, 0, "... Call to start() should return state '0'";
is $dfa->state, 0, "... Call to state() should also return '0'";
is $dfa->switch, 1, "... Call to switch should return '1'";
is $dfa->state, 1, "... Call to state() should now return '1'";

# Try run().
ok $dfa = DFA::Rules->new(
    0 => { rules => [ 1 => [ 1, sub { shift->{count}++ } ] ] },
    1 => { rules => [ 0 => [ 1, sub { $_[0]->done($_[0]->{count} == 3 ) } ] ] },
), "Construct with simple states to run";

is $dfa->run, $dfa, "... Run should return the DFA object";
is $dfa->{count}, 3,
  "... And it should have run through the proper number of iterations.";
# Reset and try again.
$dfa->{count} = 0;
is $dfa->done(0), $dfa, "... We should be able to reset done";
is $dfa->state, 0, "... We should be left in state '0'";
is $dfa->run, $dfa, "... Run should still work.";
is $dfa->{count}, 3,
  "... And it should have run through the proper number of again.";

# Check for duplicate states.
eval { DFA::Rules->new( foo => {}, foo => {}) };
ok $err = $@, 'Attempt to specify the same state twice should throw an error';
like $err, qr/The state "foo" already exists/,
  '... And that exception should have the proper message';
