
use strict;
use warnings;

use Test::More;
use Test::Fatal qw( exception );

# ABSTRACT: Make sure we have a working CHI
use CHI;

is(
  exception {
    CHI->new(
      driver => 'Memory',
      global => 0
    );
  },
  undef,
  "global => 0 is ok"
);

is(
  exception {
    CHI->new(
      driver => 'Memory',
      global => 1
    );
  },
  undef,
  "global => 1 is ok"
);

is(
  exception {
    CHI->new(
      driver    => 'Memory',
      datastore => {},
    );
  },
  undef,
  "datastore => {} is ok"
);

done_testing;

