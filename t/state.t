#!/usr/bin/perl -w

# $Id$

use strict;
#use Test::More 'no_plan';
use Test::More tests => 40;

my $CLASS;
BEGIN { 
    $CLASS = 'FSA::Rules';
    use_ok($CLASS) or die;
}

ok my $fsa = $CLASS->new, "Construct an empty state machine";

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

is $fsa->start, 'foo', "... It should start with 'foo'";
is $fsa->switch('bar'), 'bar',
  "... It should switch to 'bar' when passed 'bar'";
is $fsa->state, 'bar', "... So the state should now be 'bar'";
is $fsa->switch('bar'), 'bar',
  "... It should stay as 'bar' when passed 'bar' again";
is $fsa->state, 'bar', "... So the state should still be 'bar'";
is $fsa->try_switch('foo'), 'foo',
  "... It should switch back to 'foo' when passed 'foo'";
is $fsa->state, 'foo', "... So the state should now be back to 'foo'";

can_ok $CLASS, 'stack';
is_deeply $fsa->stack, [qw/foo bar bar foo/],
  "... and it should have a stack of the state transformations";

can_ok $CLASS, 'reset';
$fsa->reset;
is_deeply $fsa->stack, [],
  '... It should clear out the stack';
is $fsa->state, undef, '... It set the current state to undef';

# these are not duplicate tests.  We need to ensure that the state machine
# behavior is deterministic
is $fsa->start, 'foo', "... It should start with 'foo'";
is $fsa->switch('bar'), 'bar',
  "... It should switch to 'bar' when passed 'bar'";
is $fsa->state, 'bar', "... So the state should now be 'bar'";
is $fsa->switch('bar'), 'bar',
  "... It should stay as 'bar' when passed 'bar' again";
is $fsa->state, 'bar', "... So the state should still be 'bar'";
is $fsa->try_switch('foo'), 'foo',
  "... It should switch back to 'foo' when passed 'foo'";
is $fsa->state, 'foo', "... So the state should now be back to 'foo'";
is_deeply $fsa->stack, [qw/foo bar bar foo/],
  "... and it should have a stack of the state transformations";

can_ok $fsa, 'set_result';
can_ok $fsa, 'result';
can_ok $fsa, 'set_message';
can_ok $fsa, 'message';

undef $fsa;
my $counter  = 1;
my $acounter = 'a';
ok $fsa = $CLASS->new(
    foo => {
        do    => sub {
            my $fsa = shift;
            $fsa->set_result($acounter++);
        },
        rules => [
            bar => [ sub { $_[1]  eq 'bar' } ],
            foo => [ sub { $_[1]  eq 'foo' } ],
        ]
    },
    bar => {
        do    => sub {
            my $fsa = shift;
            $fsa->set_message("bar has been called $counter times");
            $fsa->set_result($counter++);
        },
        rules => [
            foo => [ sub { $_[1]  eq 'foo' } ],
            bar => [ sub { $_[1]  eq 'bar' } ],
        ]
    }
), 'Construct with switch rules that expect parameters.';

$fsa->start;
$fsa->switch('bar');
$fsa->switch('bar');
$fsa->switch('foo');

is $fsa->result, 'b', '... and result() should return us the last result';
is scalar $fsa->result('bar'), 2,
  '... or the last result of the named state if called in scalar context';
is_deeply [$fsa->result('bar')], [1,2],
  '... or all results of of the named state if called in list context';

is $fsa->message, undef, 
  '... and message should return undef if the last state had no message set';
is scalar $fsa->message('bar'), 'bar has been called 2 times',
  '... or the last message of the named state if called in scalar context';
is_deeply [$fsa->message('bar')], [
    'bar has been called 1 times',
    'bar has been called 2 times',
],
  '... or all messages of of the named state if called in list context';

can_ok $fsa, 'stacktrace';
my $stacktrace = $fsa->stacktrace;
is $stacktrace, <<"END_TRACE", '... and it should return a human readable trace';
State: foo
{
  message => undef,
  result => 'a'
}

State: bar
{
  message => 'bar has been called 1 times',
  result => 1
}

State: bar
{
  message => 'bar has been called 2 times',
  result => 2
}

State: foo
{
  message => undef,
  result => 'b'
}

END_TRACE

can_ok $fsa, 'raw_stacktrace';
my $expected = [
  [
    'foo',
    {
      'message' => undef,
      'result' => 'a'
    }
  ],
  [
    'bar',
    {
      'message' => 'bar has been called 1 times',
      'result' => 1
    }
  ],
  [
    'bar',
    {
      'message' => 'bar has been called 2 times',
      'result' => 2
    }
  ],
  [
    'foo',
    {
      'message' => undef,
      'result' => 'b'
    }
  ]
];

is_deeply $fsa->raw_stacktrace, $expected,
  '... and it should return the raw data structure of the state stack.';

can_ok $fsa, 'prev_state';
is $fsa->prev_state, 'bar',
  '... and it should correctly return the name of the previous state';
