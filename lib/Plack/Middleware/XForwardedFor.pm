package Plack::Middleware::XForwardedFor;
# ABSTRACT: Plack middleware to handle X-Forwarded-For headers

use strict;
use warnings;
use parent qw(Plack::Middleware);
use Plack::Util::Accessor qw( trust header );
use Regexp::Common qw /net/;
use Net::Netmask;

sub prepare_app {
  my $self = shift;

  if (my $trust = $self->trust) {
    my @trust = map { Net::Netmask->new($_) } ref($trust) ? @$trust : ($trust);
    $self->trust(\@trust);
  }
  if (my $header = $self->header) {
    $header = uc $header;
    $header =~ s/-/_/g;
    $header = "HTTP_$header" unless $header =~ m/^HTTP_/;
    $self->header($header);
  }
  else {
    $self->header('HTTP_X_FORWARDED_FOR') unless $self->header();
  }
}

sub call {
  my ($self, $env) = @_;

  my @forward = ($env->{ $self->header() } || '') =~ /\b($RE{net}{IPv4})\b/g;

  if (@forward) {
    my $addr = $env->{REMOTE_ADDR};
    if (my $trust = $self->trust) {
    ADDR: {
        if (my $next = pop @forward) {
          foreach my $netmask (@$trust) {
            if ($netmask->match($addr)) {
              $addr = $next;
              redo ADDR;
            }
          }
        }
      }
    }
    else {    # trust everything, so use first in list
      $addr = shift @forward;
    }
    $env->{REMOTE_ADDR} = $addr;
  }

  $self->app->($env);
}

1;

=head1 NAME

Plack::Middleware::XForwardedFor - Plack middleware to handle X-Forwarded-For headers

=head1 SYNOPSIS

  builder {
    enable "Plack::Middleware::XForwardedFor",
      trust => [qw(127.0.0.1/8)];
  };

=head1 DESCRIPTION

C<Plack::Middleware::XForwardedFor> will look for C<X-Forwarded-For>
header in the incoming request and change C<REMOTE_ADDR> to the
real client IP

=head1 PARAMETERS

=over

=item trust

If not specified then all addressed are trusted and C<REMOTE_ADDR> will be set to the
first IP in the C<X-Forwarded-For> header.

If given, it should be a list of IPs or Netmasks that can be trusted. Starting with the IP
of the client in C<REMOTE_ADDR> then the IPs in the C<X-Forwarded-For> header from right to left.
The first untrusted IP found is set to be C<REMOTE_ADDR>

=item header

If you'd like to check for a header other than C<X-Forwarded-For>, then use this parameter.
It will automatically clean up the header name to match what's in C<$env>, so
both C<X-Your-Forwarding-Header> and C<HTTP_X_YOUR_FORWARDING_HEADER> are valid.

=back

=head1 SEE ALSO

L<Plack::Middleware>, L<Net::Netmask>

=head1 AUTHOR

Graham Barr <gbarr@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Graham Barr.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
