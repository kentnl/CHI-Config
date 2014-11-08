use 5.006;
use strict;
use warnings;

package CHI::Config::DriverPool;

our $VERSION = '0.001001'; # TRIAL

# ABSTRACT: A Collection of Driver definitions

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moo qw( has );
use Carp qw( carp croak );

## no critic (ValuesAndExpressions::ProhibitConstantPragma)
use constant DEBUGGING => $ENV{CHI_CONFIG_DEBUG};

has '_drivers' => ( is => ro =>, lazy => 1, default => sub { {} } );

sub add_driver {
  my ( $self, %config ) = @_;

  require CHI::Config::Driver;

  my $instance = CHI::Config::Driver->new(%config);
  my $name     = $instance->name;

  if ( not exists $self->_drivers->{$name} ) {
    $self->_drivers->{$name} = $instance;
    return;
  }
  return unless DEBUGGING;
  ## Shadowing should be default anyway.
  my $template = '%s: %s';
  my $old      = sprintf $template, '   Kept', $self->_drivers->{$name}->source;
  my $new      = sprintf $template, 'Ignored', $instance->source;
  carp "Duplicate Driver definition ignored\n\t$old\n\t$new\n";
  return;
}

sub get_driver {
  my ( $self, $name ) = @_;
  return $self->_drivers->{$name} if exists $self->_drivers->{$name};
  croak "No default for driver <$name> defined and none specified in configuration";
}

sub get_cache {
  my ( $self, $name ) = @_;
  return $self->get_driver($name)->get_cache;
}

no Moo;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

CHI::Config::DriverPool - A Collection of Driver definitions

=head1 VERSION

version 0.001001

=head1 SYNOPSIS

  use CHI::Config::DriverPool;

  my $dp = CHI::Config::DriverPool->new();

  $dp->add_driver(
    name => ...    # See CHI::Config::Driver for arguments
  );

  $dp->get_driver($name);    # Fetches a CHI::Config::Driver instance

  $dp->get_cache($name);     # Shorthand for $dp->get_driver($name)->get_cache

=head1 DESCRIPTION

This container serves to aggregate configuration of all driver
configurations across multiple files.

It is assumed that the consumer is traversing a tree of configurations of
some kind in order of "most relevant" to "least relevant", for example,
"most relevant" would be the files in C<./> , second-most relevant
would be C<~/> somewhere, somewhere later is C</etc/> and least relevant
is any defaults provided by the program itself.

As such, the first definition seen of any given name is considered
"the one" to be used and subsequent ones are ignored.

=head1 METHODS

=head2 C<add_driver>

Create and inject a unique driver configuration in the dictionary.

First come first served.

  $pool->add_driver( %config );

Arguments for C<%config> are the same as for L<< C<< CHI::Config::Driver->new() >>|CHI::Config::Driver >>.

=head2 C<get_driver>

Fetch a named driver configuration from the dictionary.

  $pool->get_driver( $name );

This will return a L<< C<CHI::Config::Driver>|CHI::Config::Driver >> instance, or C<croak> if one does not exist.

=head2 C<get_cache>

Fetch and a named C<CHI> cache object by requesting one from the named C<CHI::Config::Driver> object.

=head1 ENVIRONMENT

=head2 CHI_CONFIG_DEBUG

Enables reporting where driver definitions are being shadowed.

This will show shadowing everywhere there is user defined configuration
in addition to a default, so is potentially more noisy than intended,
but it is hopefully useful in diagnosing misplaced identifiers.

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
