#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More 'no_plan';
#use Test::More tests => 176;

my $CLASS;
BEGIN { 
    $CLASS = 'FSA::Rules';
    use_ok($CLASS) or die;
}

ok my $fsa = $CLASS->new, "Construct an empty state machine";
isa_ok $fsa, $CLASS;

ok $fsa = $CLASS->new(
    foo => {},
), "Construct with a single state";

is $fsa->state, undef, "... The current state should be undefined";
ok my $state =  $fsa->state('foo'), "... We should be able to set the state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $state->machine, $fsa, '... The state object should return the machine';
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->done, undef, "... It should not be done";
is $fsa->done(1), $fsa, "... But we can set doneness";
is $fsa->done, 1, "... And then retreive that value";

# Try a bogus state.
eval { $fsa->state('bogus') };
ok my $err = $@, "... Assigning a bogus state should fail";
like $err, qr/No such state "bogus"/, "... And throw the proper exception";

# Try a do code ref.
ok $fsa = $CLASS->new(
    foo => {
        do => sub { shift->machine->{foo}++ }
    },
), "Construct with a single state with an action";

is $fsa->state, undef, "... The current state should be undefined";
is $fsa->{foo}, undef, "... The code should not have been executed";
ok $state = $fsa->state('foo'), "... We should be able to set the state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->{foo}, 1, "... The code should now have been executed";

# Try a do code array ref.
ok $fsa = $CLASS->new(
    foo => {
        do => [ sub { shift->machine->{foo}++ },
                sub { shift->machine->{foo}++ } ],
    },
), "Construct with a single state with two actions";

is $fsa->state, undef, "... The current state should be undefined";
is $fsa->{foo}, undef, "... The code should not have been executed";
ok $state = $fsa->state('foo'), "... We should be able to set the state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->{foo}, 2, "... Both actions should now have been executed";

# Try a single enter action.
ok $fsa = $CLASS->new(
    foo => {
        on_enter => sub { shift->machine->{foo_enter}++ },
        do => sub { shift->machine->{foo}++ }
    },
), "Construct with a single state with an enter action";

is $fsa->state, undef, "... The current state should be undefined";
is $fsa->{foo}, undef, "... The code should not have been executed";
is $fsa->{foo_enter}, undef, "... The enter code should not have executed";
ok $state = $fsa->state('foo'), "... We should be able to set the state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->{foo}, 1, "... The code should now have been executed";
is $fsa->{foo_enter}, 1, "... The enter code should have executed";

# Try an enter action array ref.
ok $fsa = $CLASS->new(
    foo => {
        on_enter => [ sub { shift->machine->{foo_enter}++ },
                      sub { shift->machine->{foo_enter}++ }
                    ],
        do => sub { shift->machine->{foo}++ }
    },
), "Construct with a single state with multiple enter actions";

is $fsa->state, undef, "... The current state should be undefined";
is $fsa->{foo}, undef, "... The code should not have been executed";
is $fsa->{foo_enter}, undef, "... The enter code should not have executed";
ok $state = $fsa->state('foo'), "... We should be able to set the state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->{foo}, 1, "... The code should now have been executed";
is $fsa->{foo_enter}, 2, "... Both enter actions should have executed";

# Try a second state with exit actions in the first state.
ok $fsa = $CLASS->new(
    foo => {
        on_enter => sub { shift->machine->{foo_enter}++ },
        do => sub { shift->machine->{foo}++ },
        on_exit => sub { shift->machine->{foo_exit}++ },
    },
    bar => {
        on_enter => sub { shift->machine->{bar_enter}++ },
        do => sub { $_[0]->machine->{bar} = $_[0]->machine->{bar_enter} }
    },
), "Construct with a two states and a exit action";

is $fsa->state, undef, "... The current state should be undefined";
is $fsa->{foo}, undef, "... The foo code should not have been executed";
is $fsa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $fsa->{bar}, undef, "... The bar code should not have been executed";
is $fsa->{bar_enter}, undef, "... The enter code should not have executed";
ok $state = $fsa->state('foo'), "... We should be able to set the state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->{foo}, 1, "... The 'foo' code should now have been executed";
is $fsa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $fsa->{foo_exit}, undef, "... The  'foo' exit action should not have executed";
ok $state = $fsa->state('bar'), "... We should be able to change the state to 'bar'";
isa_ok $state, 'FSA::State';
is $state->name, 'bar', "... The name of the current state should be 'bar'";
is $fsa->state, $state, "... The current state should be 'bar'";
is $fsa->{foo_exit}, 1, "... The 'foo' exit action should have executed";
is $fsa->{bar}, 1, "... The 'bar' code should now have been executed";
is $fsa->{bar_enter}, 1, "... The 'bar' enter action should have executed";

# Try a second state with multiple exit actions in the first state.
ok $fsa = $CLASS->new(
    foo => {
        on_enter => sub { shift->machine->{foo_enter}++ },
        do => sub { shift->machine->{foo}++ },
        on_exit => [sub { shift->machine->{foo_exit}++ }, sub { shift->machine->{foo_exit}++ } ],
    },
    bar => {
        on_enter => sub { shift->machine->{bar_enter}++ },
        do => sub { $_[0]->machine->{bar} = $_[0]->machine->{bar_enter} }
    },
), "Construct with a two states and multiple exit actions";

is $fsa->state, undef, "... The current state should be undefined";
is $fsa->{foo}, undef, "... The foo code should not have been executed";
is $fsa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $fsa->{bar}, undef, "... The bar code should not have been executed";
is $fsa->{bar_enter}, undef, "... The enter code should not have executed";
ok $state = $fsa->state('foo'), "... We should be able to set the state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->{foo}, 1, "... The 'foo' code should now have been executed";
is $fsa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $fsa->{foo_exit}, undef, "... The  'foo' exit action should not have executed";
ok $state = $fsa->state('bar'), "... We should be able to change the state to 'bar'";
isa_ok $state, 'FSA::State';
is $state->name, 'bar', "... The name of the current state should be 'bar'";
is $fsa->state, $state, "... The current state should be 'bar'";
is $fsa->{foo_exit}, 2, "... Both 'foo' exit actions should have executed";
is $fsa->{bar}, 1, "... The 'bar' code should now have been executed";
is $fsa->{bar_enter}, 1, "... The  'bar' enter action should have executed";

# Set up switch rules (rules).
ok $fsa = $CLASS->new(
    foo => {
        on_enter => sub { shift->machine->{foo_enter}++ },
        do => sub { shift->machine->{foo}++ },
        on_exit => sub { shift->machine->{foo_exit}++ },
        rules => [
            bar => sub { shift->machine->{foo} },
        ],
    },
    bar => {
        on_enter => sub { shift->machine->{bar_enter}++ },
        do => sub { $_[0]->machine->{bar} = $_[0]->machine->{bar_enter} },
    },
), "Construct with a two states and a switch rule";

is $fsa->state, undef, "... The current state should be undefined";
is $fsa->{foo}, undef, "... The foo code should not have been executed";
is $fsa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $fsa->{bar}, undef, "... The bar code should not have been executed";
is $fsa->{bar_enter}, undef, "... The enter code should not have executed";
ok $state = $fsa->state('foo'), "... We should be able to set the state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->{foo}, 1, "... The 'foo' code should now have been executed";
is $fsa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $fsa->{foo_exit}, undef, "... The 'foo' exit action should not have executed";
ok $state =  $fsa->try_switch, "... The try_switch method should return the 'bar' state";
isa_ok $state, 'FSA::State';
is $state->name, 'bar', "... The name of the current state should be 'bar'";
is $fsa->state, $state, "... The current state should be 'bar'";
is $fsa->{foo_exit}, 1, "... Now the 'foo' exit action should have executed";
is $fsa->{bar}, 1, "... And the 'bar' code should now have been executed";
is $fsa->{bar_enter}, 1, "... And the 'bar' enter action should have executed";

# There are no switchs from bar.
eval { $fsa->switch };
ok $err = $@, "... Another attempt to switch should fail";
like $err, qr/Cannot determine transition from state "bar"/,
  "... And throw the proper exception";

# Try switch actions.
ok $fsa = $CLASS->new(
    foo => {
        on_enter => sub { shift->machine->{foo_enter}++ },
        do => sub { shift->machine->{foo}++ },
        on_exit => sub { shift->machine->{foo_exit}++ },
        rules => [
            bar => [sub { shift->machine->{foo} } => sub { shift->machine->{foo_bar}++ } ],
        ],
    },
    bar => {
        on_enter => sub { $_[0]->machine->{bar_enter} = $_[0]->machine->{foo_bar} },
        do => sub { $_[0]->machine->{bar} = $_[0]->machine->{bar_enter} }
    },
), "Construct with a two states and a switch rule with its own action";

is $fsa->state, undef, "... The current state should be undefined";
is $fsa->{foo}, undef, "... The foo code should not have been executed";
is $fsa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $fsa->{bar}, undef, "... The bar code should not have been executed";
is $fsa->{bar_enter}, undef, "... The enter code should not have executed";
ok $state = $fsa->state('foo'), "... We should be able to set the state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->{foo}, 1, "... The 'foo' code should now have been executed";
is $fsa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $fsa->{foo_exit}, undef, "... The 'foo' exit action should not have executed";
ok $state =  $fsa->switch, "... The switch method should return the 'bar' state";
isa_ok $state, 'FSA::State';
is $state->name, 'bar', "... The name of the current state should be 'bar'";
is $fsa->state, $state, "... The current state should be 'bar'";
is $fsa->{foo_exit}, 1, "... Now the 'foo' exit action should have executed";
is $fsa->{bar}, 1, "... And the 'bar' code should now have been executed";
is $fsa->{foo_bar}, 1, "... And the 'foo' to 'bar' switch action should have executed";
is $fsa->{bar_enter}, 1, "... And the 'bar' enter action should have executed";

# Try a simple true value switch rule.
ok $fsa = $CLASS->new(
    foo => {
        on_enter => sub { shift->machine->{foo_enter}++ },
        do => sub { shift->machine->{foo}++ },
        on_exit => sub { shift->machine->{foo_exit}++ },
        rules => [
            bar => 1
        ],
    },
    bar => {
        on_enter => sub { shift->machine->{bar_enter}++ },
        do => sub { $_[0]->machine->{bar} = $_[0]->machine->{bar_enter} }
    },
), "Construct with a two states and a switch rule of '1'";

is $fsa->state, undef, "... The current state should be undefined";
is $fsa->{foo}, undef, "... The foo code should not have been executed";
is $fsa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $fsa->{bar}, undef, "... The bar code should not have been executed";
is $fsa->{bar_enter}, undef, "... The enter code should not have executed";
ok $state = $fsa->state('foo'), "... We should be able to set the state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->{foo}, 1, "... The 'foo' code should now have been executed";
is $fsa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $fsa->{foo_exit}, undef, "... The 'foo' exit action should not have executed";
ok $state =  $fsa->switch, "... The switch method should return the 'bar' state";
isa_ok $state, 'FSA::State';
is $state->name, 'bar', "... The name of the current state should be 'bar'";
is $fsa->state, $state, "... The current state should be 'bar'";
is $fsa->{foo_exit}, 1, "... Now the 'foo' exit action should have executed";
is $fsa->{bar}, 1, "... And the 'bar' code should now have been executed";
is $fsa->{bar_enter}, 1, "... And the 'bar' enter action should have executed";

# Try a simple true value switch rule with switch actions.
ok $fsa = $CLASS->new(
    foo => {
        on_enter => sub { shift->machine->{foo_enter}++ },
        do => sub { shift->machine->{foo}++ },
        on_exit => sub { shift->machine->{foo_exit}++ },
        rules => [
            bar => [1, sub { shift->machine->{foo_bar}++ } ],
        ],
    },
    bar => {
        on_enter => sub { $_[0]->machine->{bar_enter} = $_[0]->machine->{foo_bar} },
        do => sub { $_[0]->machine->{bar} = $_[0]->machine->{bar_enter} }
    },
), "Construct with a two states, a switch rule of '1', and a switch action";

is $fsa->state, undef, "... The current state should be undefined";
is $fsa->{foo}, undef, "... The foo code should not have been executed";
is $fsa->{foo_enter}, undef, "... The 'foo' enter code should not have executed";
is $fsa->{bar}, undef, "... The bar code should not have been executed";
is $fsa->{bar_enter}, undef, "... The enter code should not have executed";
ok $state = $fsa->state('foo'), "... We should be able to set the state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->{foo}, 1, "... The 'foo' code should now have been executed";
is $fsa->{foo_enter}, 1, "... The  'foo' enter action should have executed";
is $fsa->{foo_exit}, undef, "... The 'foo' exit action should not have executed";
ok $state =  $fsa->switch, "... The switch method should return the 'bar' state";
isa_ok $state, 'FSA::State';
is $state->name, 'bar', "... The name of the current state should be 'bar'";
is $fsa->state, $state, "... The current state should be 'bar'";
is $fsa->{foo_exit}, 1, "... Now the 'foo' exit action should have executed";
is $fsa->{foo_bar}, 1, "... And the 'foo' to 'bar' switch action should have executed";
is $fsa->{bar}, 1, "... And the 'bar' code should now have been executed";
is $fsa->{bar_enter}, 1, "... And the 'bar' enter action should have executed";

# Try start().
ok $fsa = $CLASS->new(
    foo => {
        do => sub { shift->machine->{foo}++ }
    },
), "Construct with a single state with an enter action";

is $fsa->state, undef, "... The current state should be undefined";
is $fsa->{foo}, undef, "... The code should not have been executed";
ok $state = $fsa->start, "... The start method should return the start state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->{foo}, 1, "... The code should now have been executed";

# Try start() with a second state.
ok $fsa = $CLASS->new(
    foo => {
        do => sub { shift->machine->{foo}++ }
    },
    bar => {
        do => sub { shift->machine->{bar}++ }
    },
), "Construct with a single state with an enter action";

is $fsa->state, undef, "... The current state should be undefined";
is $fsa->{foo}, undef, "... The 'foo' code should not have been executed";
is $fsa->{bar}, undef, "... The 'bar' code should not have been executed";
ok $state = $fsa->start, "... The start method should return the start state";
isa_ok $state, 'FSA::State';
is $state->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $state, "... The current state should be 'foo'";
is $fsa->{foo}, 1, "... The code should now have been executed";
is $fsa->{bar}, undef, "... The 'bar' code still should not have been executed";

# Try a bad switch state name.
eval {
    $CLASS->new(
        foo => { rules => [bad => 1] }
    )
};

ok $err = $@, "A bad state name in rules should fail";
like $err, qr/Unknown state "bad" referenced by state "foo"/,
  "... And give the appropriate error message";

# Try numbered states.
ok $fsa = $CLASS->new(
    0 => { rules => [ 1 => 1 ] },
    1 => {},
), "Construct with numbered states";
ok $state = $fsa->start, "... Call to start() should return state '0'";
isa_ok $state, 'FSA::State';
is $state->name, 0, "... The name of the current state should be '0'";
is $fsa->state, $state, "... The current state should be '0'";

ok $state = $fsa->switch, "... Call to switch should return '1' state";
isa_ok $state, 'FSA::State';
is $state->name, 1, "... The name of the current state should be '1'";
is $fsa->state, $state, "... The current state should be '1'";

# Try run().
ok $fsa = $CLASS->new(
    0 => { rules => [ 1 => [ 1, sub { shift->machine->{count}++ } ] ] },
    1 => { rules => [ 0 => [ 1, sub { $_[0]->machine->done($_[0]->machine->{count} == 3 ) } ] ] },
), "Construct with simple states to run";

is $fsa->run, $fsa, "... Run should return the FSA object";
is $fsa->{count}, 3,
  "... And it should have run through the proper number of iterations.";
# Reset and try again.
$fsa->{count} = 0;
is $fsa->done(0), $fsa, "... We should be able to reset done";
ok $state = $fsa->state,  "... We should be left in state '0'";
isa_ok $state, 'FSA::State';
is $state->name, 0, "... The name of the current state should be '0'";
is $fsa->run, $fsa, "... Run should still work.";
is $fsa->{count}, 3,
  "... And it should have run through the proper number of again.";

# Try done with a code refernce.
ok $fsa = $CLASS->new(
    0 => { rules => [ 1 => [ 1, sub { shift->machine->{count}++ } ] ] },
    1 => { rules => [ 0 => [ 1 ] ] },
), "Construct with simple states to test a done code ref";


is $fsa->done( sub { shift->{count} == 3 }), $fsa,
  "Set done to a code reference";
$fsa->{count} = 0;
is $fsa->run, $fsa, "... Run should still work.";
is $fsa->{count}, 3,
  "... And it should have run through the proper number of again.";

# Check for duplicate states.
eval { $CLASS->new( foo => {}, foo => {}) };
ok $err = $@, 'Attempt to specify the same state twice should throw an error';
like $err, qr/The state "foo" already exists/,
  '... And that exception should have the proper message';

# Try try_switch with parameters.
ok $fsa = $CLASS->new(
    foo => {
        rules => [
            bar => [ sub { $_[1]  eq 'bar' } ],
            foo => [ sub { $_[1]  eq 'foo' } ],
        ]
    },
    bar => {
        rules => [
            foo => [ sub { $_[1]  eq 'foo' } ],
            bar => [ sub { $_[1]  eq 'bar' } ],
        ]
    }
), 'Construct with switch rules that expect parameters.';


ok my $foo = $fsa->start, "... It should start with 'foo'";
isa_ok $foo, 'FSA::State';
is $foo->name, 'foo', "... The name of the current state should be 'foo'";
is $fsa->state, $foo, "... The current state should be 'foo'";
ok my $bar = $fsa->switch('bar'),
  "... It should switch to 'bar' when passed 'bar'";
isa_ok $bar, 'FSA::State';
is $bar->name, 'bar', "... The name of the current state should be 'bar'";
is $fsa->state, $bar, "... The current state should be 'bar'";
is $fsa->switch('bar'), $bar,
  "... It should stay as 'bar' when passed 'bar' again";
is $fsa->state, $bar, "... So the state should still be 'bar'";
is $fsa->try_switch('foo'), $foo,
  "... It should switch back to 'foo' when passed 'foo'";
is $fsa->state, $foo, "... So the state should now be back to 'foo'";

# Try some notes.
is_deeply $fsa->notes, {}, "Notes should start out empty";
is $fsa->notes( key => 'val' ), $fsa,
  "... And should get the machine back when setting a note";
is $fsa->notes('key'), 'val',
  "... And passing in the key should return the corresponding value";
is $fsa->notes( my => 'machine' ), $fsa,
  "We should get the machine back when setting another note";
is $fsa->notes('my'), 'machine',
  "... And passing in the key should return the new value";
is_deeply $fsa->notes, { key => 'val', my => 'machine' },
  "... And passing in no arguments should return the complete notes hashref";
$fsa->reset, $fsa, "... Calling reset() should return the machine";
is $fsa->notes('key'), undef, '... And now passing in a key should return undef';
is_deeply $fsa->notes, {}, "... and with no arguments, we should get an empty hash";
