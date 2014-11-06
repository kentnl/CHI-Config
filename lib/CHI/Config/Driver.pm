use 5.006;
use strict;
use warnings;

package CHI::Config::Driver;

our $VERSION = '0.001000'; # TRIAL

# ABSTRACT: Container for Driver configuration

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moo qw( has );

has 'name'     => ( is => 'ro', required => 1 );
has 'file'     => ( is => 'ro', required => 1 );
has 'entry_no' => ( is => 'ro', required => 1 );
has 'config'   => ( is => 'ro', required => 1 );
has 'memoize'  => ( is => 'ro', lazy     => 1, default => undef );

sub get_cache {
  my ($self) = @_;
  return $self->{_cache} if exists $self->{_cache};

  require CHI;
  require Storable;

  my $instance = CHI->new( %{ Storable::dclone( $self->config ) } );

  $self->{_cache} = $instance if $self->memoize;

  return $instance;
}

sub source {
  my ($self) = @_;
  return sprintf '%s ( entry #%s )', $self->file, $self->entry_no;
}

no Moo;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

CHI::Config::Driver - Container for Driver configuration

=head1 VERSION

version 0.001000

=head1 SYNOPSIS

  my $config = CHI::Config::Driver->new(
    name     => 'my.name.here',
    file     => '/path/config_was_loaded_from',    # for debugging
    entry_no => 5,                                 # entry number in 5 for debugging
    config   => {},                                # CHI Payload
    memoize  => 0 || 1,                            # whether multiple calls make singular objects
  );

This is mostly an implementation detail for C<CHI::Config>.

Each instance directly maps to an entry in the configuration file.

Two parameters C<file> and C<entry_no> are provided automatically by the infrastructure.

=head1 METHODS

=head2 C<get_cache>

Returns a C<CHI> cache object using the definition in C<config>.

This may return the same object across multiple calls ( if C< L</memoize> > is true ).

Otherwise returns a new C<CHI> instance with every call.

=head2 C<source>

Returns a string

=head1 ATTRIBUTES

=head2 C<name>

The name of this driver for look-up purposes.

B<Strongly> Recommended format ( I<especially> for CPAN ) is some sort
of alias path with a prefix, i.e:

  name => 'dist-zilla-cache.www-objects'

=head2 C<config>

This is a raw hash payload that gets passed to C<< CHI->new() >>.

  config => {
    driver => 'Memory',
    ...                   # For example
  }

=head2 C<memoize>

This attribute dictates whether multiple calls to C<get_cache> will return
I<different> cache objects ( which may happen to share implementation details ),
or whether it will return a I<single> cache object for multiple calls.

  memoize => 0  # Default, each call to get_cache returns a new CHI instance
  memoize => 1  # Construct CHI cache once and return it multiple times.

=head2 C<file>

Pertains to the location this C<Driver> configuration was determined from.

This is an implementation detail used for debug purposes in C<CHI::Config>
and is normally provided by the various configuration sourcing tools.

=head2 C<entry_no>

Pertains to the placement in the array of configuration details ( in C<file> )
where the configuration for this C<Driver> was found.

This is an implementation detail used for debug purposes in C<CHI::Config>
and is normally provided by the various configuration sourcing tools.

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
