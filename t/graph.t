#!/usr/bin/perl -w

# $Id$

use strict;
use Test::More;

BEGIN { 
    eval "use GraphViz";
    plan $@ 
        ? (skip_all => "GraphViz cannot be loaded.") 
        #: ('no_plan');
        : (tests => 10);
    use_ok 'FSA::Rules' or die;
}

ok my $fsa = FSA::Rules->new(
    ping => {
        do => sub { state->machine->{count}++ },
        rules     => [
            end  => sub { shift->machine->{count} >= 20 },
            pong => sub { 1 },
        ],
    },
    pong => {
        do => sub { shift->machine->{count}++ },
        rules     => [
            end  => sub { shift->machine->{count} >= 20 },
            ping => sub { 1 },
        ],
    },
    end => {}
), "Create the ping pong FSA machine";

can_ok $fsa, 'graph';
isa_ok $fsa->graph, 'GraphViz';
#open FOO, '>', 'pingpong.png' or die $!;
#print FOO $fsa->graph->as_png;
#close FOO;
my $expected = <<'END_TEXT';
digraph test {
        node [label="\N"];
        graph [bb="0,0,92,180"];
        ping [label=ping, pos="65,162", width="0.75", height="0.50"];
        end [label=end, pos="37,18", width="0.75", height="0.50"];
        pong [label=pong, pos="65,90", width="0.75", height="0.50"];
        ping -> end [pos="e,32,36 47,149 37,137 34,127 29,108 24,87 26,64 30,46"];
        ping -> pong [pos="e,59,108 59,144 58,136 58,127 58,118"];
        pong -> end [pos="e,44,35 58,73 55,64 51,54 47,45"];
        pong -> ping [pos="e,71,144 71,108 72,116 72,125 72,134"];
}
END_TEXT
my $graph_text = $fsa->graph->as_text;
$graph_text    =~ s/\t/        /g;
is $graph_text, $expected,
  '... and it should return a text version of the graph.';
$graph_text = $fsa->graph->as_text;
$graph_text    =~ s/\t/        /g;
is $graph_text, $expected,
  '... and I should be able to call it multiple times and get the same results.';

ok $fsa = FSA::Rules->new(
    ping => {
        do => sub { state->machine->{count}++ },
        rules     => [
            end  => { 'Enough Iterations (ping)' => sub { shift->machine->{count} >= 20 } },
            pong => sub { 1 },
        ],
    },
    pong => {
        do => sub { shift->machine->{count}++ },
        rules     => [
            end  => { 'Enough Iterations' => sub { shift->machine->{count} >= 20 } },
            ping => sub { 1 },
        ],
    },
    end => {}
), "We can use rule labels in creating the state machine.";

can_ok $fsa, 'graph';
isa_ok $fsa->graph, 'GraphViz';
$expected = <<'END_TEXT';
digraph test {
        graph [bgcolor=magenta];
        node [label="\N", shape=circle];
        graph [bb="0,0,235,262"];
        ping [label=ping, pos="204,233", width="0.81", height="0.81"];
        end [label=end, pos="76,26", width="0.69", height="0.71"];
        pong [label=pong, pos="204,135", width="0.86", height="0.86"];
        ping -> end [label="Enough Iterations (ping)", pos="e,59,45 175,226 130,215 44,191 27,166 3,131 30,83 53,53", lp="99,135"];
        ping -> pong [pos="e,198,166 198,205 197,196 197,186 197,176"];
        pong -> end [label="Enough Iterations", pos="e,93,44 178,117 163,106 144,92 136,86 124,75 111,63 100,52", lp="190,78"];
        pong -> ping [pos="e,210,205 210,166 211,175 211,185 211,195"];
}
END_TEXT
my $graph = $fsa->graph(
    bgcolor => 'magenta',
    node    => {shape => 'circle'},
);
#open FOO, '>', 'pingpong.png' or die $!;
#print FOO $graph->as_png;
#close FOO;
$graph_text = $graph->as_text;
$graph_text    =~ s/\t/        /g;
is $graph_text, $expected,
  '... and it should also be able to pass the proper arguments to the GraphViz constructor';
