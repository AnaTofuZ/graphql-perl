#!perl -T
use 5.014;
use strict;
use warnings;
use Test::More;
use Test::Exception;
use JSON;
use Data::Dumper;

BEGIN {
  use_ok( 'GraphQL::Schema' ) || print "Bail out!\n";
  use_ok( 'GraphQL::Type::Object' ) || print "Bail out!\n";
  use_ok( 'GraphQL::Type::Scalar', qw($String $Int) ) || print "Bail out!\n";
  use_ok( 'GraphQL::Execution' ) || print "Bail out!\n";
}

$Data::Dumper::Sortkeys = $Data::Dumper::Indent = $Data::Dumper::Terse = 1;
my $JSON = JSON->new->allow_nonref;

sub make_schema {
  my ($field) = @_;
  GraphQL::Schema->new(
    query => GraphQL::Type::Object->new(
      name => 'Query',
      fields => { test => $field },
    ),
  );
}

sub run_test {
  my ($args, $expected) = @_;
  my $got = GraphQL::Execution->execute(@$args);
  is_deeply $got, $expected or diag Dumper $got;
}

subtest 'default function accesses properties', sub {
  my $schema = make_schema({ type => $String });
  my $root_value = { test => 'testvalue' };
  my $expected = { %$root_value }; # copy in case of mutations
  run_test([$schema, '{ test }', $root_value], { data => $expected });
  done_testing;
};

subtest 'default function calls methods', sub {
  my $schema = make_schema({ type => $String });
  use constant SECRETVAL => 'secretValue';
  {
    package MyTest1;
    sub new { bless { _secret => ::SECRETVAL }, shift; }
    sub test { shift->{_secret} }
  }
  my $root_value = MyTest1->new;
  is $root_value->test, SECRETVAL; # fingers and toes
  run_test([$schema, '{ test }', $root_value], { data => { test => SECRETVAL } });
  done_testing;
};

subtest 'default function passes args and context', sub {
  my $schema = make_schema({
    type => $Int,
    args => { addend1 => { type => $Int } },
  });
  {
    package Adder;
    sub new { bless { _num => $_[1] }, $_[0]; }
    sub test { shift->{_num} + shift->{addend1} + shift->{addend2} }
  }
  my $root_value = Adder->new(700);
  is $root_value->test({ addend1 => 80 }, { addend2 => 9 }), 789;
  run_test(
    [$schema, '{ test(addend1: 80) }', $root_value, { addend2 => 9 }],
    { data => { test => 789 } },
  );
  done_testing;
};

done_testing;
