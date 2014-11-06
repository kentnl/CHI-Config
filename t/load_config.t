use strict;
use warnings;

use Test::More;

# ABSTRACT: Test basic config loading

use Path::Tiny qw(path);
use Test::TempDir::Tiny qw( tempdir );

my $scratch = path(tempdir);

$scratch->child('config.json')->spew_raw(<<'EOF');
[
  {
    "type":"version",
    "min":"0.001000"
  },
  {
    "type": "driver",
    "name": "myapp.cache_a",
    "config": {
      "driver": "Memory",
      "datastore": {}
    }
  }
]
EOF

$scratch->child('config_b.json')->spew_raw(<<'EOF');
[{
  "type": "driver",
  "name": "myapp.cache_a",
  "config": {
    "driver": "Memory",
    "datastore": {}
  }
}]
EOF

use CHI::Config;

my $cfg = CHI::Config->new(
  config_paths => [ $scratch->child('config_b'), $scratch->child('config') ],
  defaults     => [
    {
      name   => 'myapp.cache_b',
      type   => 'driver',
      config => {
        'driver'    => 'Memory',
        'datastore' => {},
      },
    },
    {
      type   => 'driver',
      name   => 'myapp.cache_a',
      config => {
        'driver'    => 'Memory',
        'datastore' => {},
      },
    }
  ]
);

my $cache   = $cfg->get_cache('myapp.cache_b');
my $cache_c = $cfg->get_cache('myapp.cache_b');

$cache->compute( 'a', undef, sub { return 1 } );
cmp_ok( $cache_c->compute( 'a', undef, sub { return 2 } ), '==', 2, 'Caches independent' );

done_testing;

