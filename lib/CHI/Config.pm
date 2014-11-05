use 5.006;
use strict;
use warnings;

package CHI::Config;

our $VERSION = '0.001000';

# ABSTRACT: Define CHI configuration outside your code

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Carp qw( croak );
use Moo qw( has around );

sub BUILDARGS {
  my ( $class, @args ) = @_;
  my (@caller) = caller(1);    # +1 for Moo
  if ( @args == 1 and ref $args[0] ) {
    $args[0]->{_constructor_caller} = $caller[1];
    return $args[0];
  }
  return { @args, _constructor_caller => $caller[1] };
}

has '_constructor_caller' => (
  is       => 'ro',
  required => 1,
);

has '_config_paths' => (
  init_arg => 'config_paths',
  is       => 'ro',
  lazy     => 1,
  builder  => '_build_config_paths'
);

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

has '_config_files' => (
  init_arg => 'config_files',
  is       => 'ro',
  lazy     => 1,
  builder  => '_build_config_files'
);

sub _build_config_files { return [] }

has '_config' => (
  init_arg => undef,
  is       => 'ro',
  lazy     => 1,
  builder  => '_build_config'
);

sub _build_config {
  my ($self) = @_;
  require Config::Any;
  my %extras = ( use_ext => 1 );
  return Config::Any->load_files( { files => $self->_config_files, %extras } ) if @{ $self->_config_files };
  return Config::Any->load_stems( { stems => $self->_config_paths, %extras } );
}

has '_defaults' => (
  init_arg => 'defaults',
  is       => ro =>,
  lazy     => 1,
  builder  => '_build_defaults',
);

sub _build_defaults {
  return [];
}

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

sub _build_drivers {
  my ($self) = @_;
  require CHI::Config::DriverPool;
  my $pool = CHI::Config::DriverPool->new();
}

sub BUILD {
  my ($self) = @_;
  local $Carp::CarpLevel = $Carp::CarpLevel + 1;
  $self->_load_config;
  $self->_load_defaults;
}

sub _load_version {
  my ( $self, %entry ) = @_;
  if ( $entry{min} ) {
    require version;
    my $min = version->parse( $entry{min} );
    if ( $min > $VERSION ) {
      croak "Minimum version required by $entry{file} ( entry #$entry{entry_no} ) is $min, we have $VERSION";
    }
  }
  if ( $entry{max} ) {
    require version;
    my $max = version->parse( $entry{max} );
    if ( $max < $VERSION ) {
      croak "Maximum version required by $entry{file} ( entry #$entry{entry_no} ) is $max, we have $VERSION";
    }
  }
  return;
}

sub _load_entry {
  my ( $self, %entry ) = @_;
  my $context = sprintf "%s ( entry #%s )", $entry{file}, $entry{entry_no};
  my $name = ( $entry{name} ? ' named ' . $entry{name} : ' ' );
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
      file     => $file,       #
      entry_no => $entry_no    #
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

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
