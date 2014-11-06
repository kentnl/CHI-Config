use 5.006;
use strict;
use warnings;

package CHI::Config;

our $VERSION = '0.001000'; # TRIAL

# ABSTRACT: Define CHI configuration outside your code

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Carp qw( croak );
use Moo qw( has around );

has '_constructor_caller' => (
  is       => 'ro',
  required => 1,
);

has '_config_paths' => (
  init_arg => 'config_paths',
  is       => 'ro',
  lazy     => 1,
  builder  => '_build_config_paths',
);

has '_config_files' => (
  init_arg => 'config_files',
  is       => 'ro',
  lazy     => 1,
  builder  => '_build_config_files',
);

has '_config' => (
  init_arg => undef,
  is       => 'ro',
  lazy     => 1,
  builder  => '_build_config',
);

has '_defaults' => (
  init_arg => 'defaults',
  is       => ro =>,
  lazy     => 1,
  builder  => '_build_defaults',
);

has '_drivers' => (
  is       => 'ro',
  init_arg => undef,
  lazy     => 1,
  builder  => '_build_drivers',
  handles  => {
    '_add_driver' => 'add_driver',
    '_get_driver' => 'get_driver',
    'get_cache'   => 'get_cache',
  },
);

sub BUILDARGS {
  my ( undef, @args ) = @_;
  my (@caller) = caller 1;    # +1 for Moo
  if ( 1 == @args and ref $args[0] ) {
    $args[0]->{_constructor_caller} = $caller[1];
    return $args[0];
  }
  return { @args, _constructor_caller => $caller[1] };
}

sub BUILD {
  my ($self) = @_;
  ## no critic (Variables::ProhibitPackageVars)
  local $Carp::CarpLevel = $Carp::CarpLevel + 1;
  $self->_load_config;
  $self->_load_defaults;
  return;
}

sub _build_config_paths {
  require File::HomeDir;
  my (@scan_paths) = (
    ( exists $ENV{CHI_CONFIG_DIR} ? $ENV{CHI_CONFIG_DIR} . '/config' : () ),    # From ENV
    './chi_config',                                                             # ./
    File::HomeDir->my_home . '/.chi/config',                                    # ~/.chi/
    '/etc/chi/config',                                                          # /etc/chi/
  );
  return \@scan_paths;
}

sub _build_config_files { return [] }

sub _build_config {
  my ($self) = @_;
  require Config::Any;
  my %extras = ( use_ext => 1 );
  return Config::Any->load_files( { files => $self->_config_files, %extras } ) if @{ $self->_config_files };
  return Config::Any->load_stems( { stems => $self->_config_paths, %extras } );
}

sub _build_defaults {
  return [];
}

sub _build_drivers {
  require CHI::Config::DriverPool;
  return CHI::Config::DriverPool->new();
}

sub _load_version {
  my ( undef, %entry ) = @_;

  my $spec      = '0.1.0';
  my $entry_msg = "$entry{file} ( entry #$entry{entry_no} )";

  if ( $entry{spec} and $entry{spec} ne $spec ) {
    croak "Spec version required by $entry_msg is ==$entry{spec}, this is $spec";
  }
  if ( $entry{min} ) {
    require version;
    my $min = version->parse( $entry{min} );
    if ( $min > $VERSION ) {
      croak "Minimum version required by $entry_msg is $min, we have $VERSION";
    }
  }
  if ( $entry{max} ) {
    require version;
    my $max = version->parse( $entry{max} );
    if ( $max < $VERSION ) {
      croak "Maximum version required by $entry_msg is $max, we have $VERSION";
    }
  }
  return;
}

sub _load_entry {
  my ( $self, %entry ) = @_;
  my $context = sprintf q[%s ( entry #%s )], $entry{file}, $entry{entry_no};
  my $name = ( $entry{name} ? q[ named ] . $entry{name} : q[ ] );
  croak "No type specified for entry$name in $context" unless defined $entry{type};
  return $self->_load_version(%entry) if 'version' eq $entry{type};
  return $self->_add_driver(%entry)   if 'driver' eq $entry{type};
  croak "Unknown type $entry{type} in $context";
}

sub _load_array {
  my ( $self, $array, $file ) = @_;
  if ( not 'ARRAY' eq ref $array ) {
    return croak "Payload in $file should be an ARRAY of HASH";
  }
  my $entry_no = 1;
  for my $entry ( @{$array} ) {
    if ( not 'HASH' eq ref $entry ) {
      return croak "Entry $entry_no in $file is not a HASH";
    }
    $self->_load_entry(
      %{$entry},
      file     => $file,        #
      entry_no => $entry_no,    #
    );
    $entry_no++;
  }
  return;
}

sub _load_config {
  my ( $self, ) = @_;

  # Load from config first.
  for my $result ( @{ $self->_config } ) {
    for my $file ( keys %{$result} ) {
      $self->_load_array( $result->{$file}, $file );
    }
  }
  return;
}

sub _load_defaults {
  my ( $self, ) = @_;
  return $self->_load_array( $self->_defaults, $self->_constructor_caller );
}

no Moo;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

CHI::Config - Define CHI configuration outside your code

=head1 VERSION

version 0.001000

=head1 SYNOPSIS

  use CHI::Config;

  my $config = CHI::Config->new(
    defaults => [
      # Defaults indeed has to mimic the source file for future purposes
      # ie: I plan to make some objects ( such as serializers )
      # be configurable as well and they can't really be defined as-is in JSON
      {
          type => 'driver',
          name => 'myproject.roflmayo',
          config => {
              # Arguments to CHI->new()
          },
      },
    ],
  );

  my $cache = $config->get_cache('myproject.roflmayo');

  # Do stuff with $cache and get default behaviour

  # User creates ~/.chi/config.json
  [
    {
      'type' : 'driver',
      'name' : 'myproject.roflmayo',
      'config': {
         # CHI CONFIG HERE
      },
    }
  ]

  my $cache = $config->get_cache('myproject.roflmayo');  # Now gets user defined copy

=head1 CONSTRUCTOR ARGUMENTS

=head2 C<config_paths>

I<Optional>: An ArrayRef of path prefixes to scan and load.

For instance:

  ( config_paths => ['./foo'] )

Would automatically attempt to load any files called

  foo.yml
  foo.json
  foo.ini

And load them with the relevant helpers.

See L<< C<Config::Any>|Config::Any >> for details on this mechanism.

Paths will be interpreted in the order specified, with the first one
taking precedence over the latter ones for any given driver name,
with C<defaults> being taken only if they're needed.

Default paths loaded are as follows:

    $ENV{CHI_CONFIG_DIR}/config.*
    ./chi_config.*
    ~/.chi/config.*
    /etc/chi/config.*

=head2 C<config_files>

I<Optional>: An ArrayRef of files to scan and load.

If specified, this list entirely overrules that provided by
L<< C<config_paths>|/config_paths >>

=head2 C<defaults>

I<Recommended>: An ArrayRef of defaults in the same notation as the configuration spec.

  defaults => [
       $entry,
       $entry,
       $entry,
  ],

See L</ENTRIES>

=head1 METHODS

=head2 C<get_cache>

Retrieve an instance of a cache object for consumption.

  my $cache = $config->get_cache('myproject.myname');

  $cache-># things with CHI

=for Pod::Coverage BUILD BUILDARGS

=head1 ENTRIES

Both the internal array based interface and the configuration file
are a list of C<Entries>. Design somewhat inspired by C<Config::MVP>'s
sequence model, but much more lightweight.

=head2 C<driver> entry

These make up the core of a configuration.

  {
    type => 'driver',

    # The following are all passed through to
    # CHI::Config::Driver

    # STRONGLY recommended
    name => 'mynamespace.mycachename',

    # RAW CHI arguments
    config => {
      %CONFIG    #
    },

    # return singleton or new caches?
    memoize => 0,
  }

See L<< C<CHI::Config::Driver>|CHI::Config::Driver >> for details.

=head2 C<version> entry

This is a mostly unnecessary element simply designed to give
some kind of informal API in the event there are changes in
how the configuration is parsed.

Currently, Spec version is == C<0.1.0>

  {
    type => 'version',

    # Declare a minimum version of CHI::Config
    min => 0.001000,

    # Declare a maximum version of CHI::Config
    max => 1.000000,

    # Require exactly specification 0.1.0
    spec => '0.1.0',
  }

C<max> and C<min> give range controls on the version of C<CHI::Config> itself.

C<spec> gives an exact match on the I<interface> provided by C<CHI::Config>, and is processed as an exact string match.

Any of the criteria not being satisfied will result in a C<croak>

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
