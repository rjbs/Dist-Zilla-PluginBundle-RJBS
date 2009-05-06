package Dist::Zilla::PluginBundle::RJBS;

# ABSTRACT: BeLike::RJBS when you build your dists
use Moose;
use Moose::Autobox;
with 'Dist::Zilla::Role::PluginBundle';

=head1 DESCRIPTION

This is the plugin bundle that RJBS uses.  It is equivalent to:

  [@Filter]
  bundle = @Classic
  remove = PodVersion

  [AutoVersion]
  [PodPurler]
  [Repository]

=cut

use Dist::Zilla::PluginBundle::Filter;

sub bundle_config {
  my ($self, $arg) = @_;
  my $class = (ref $self) || $self;

  my $major_version;
  $major_version = defined $arg->{version} ? $arg->{version} : 0;

  my @plugins = Dist::Zilla::PluginBundle::Filter->bundle_config({
    bundle => '@Classic',
    remove => [ 'PodVersion' ],
  });

  push @plugins, (
    [ 'Dist::Zilla::Plugin::AutoVersion' => { major => $major_version } ],
    [ 'Dist::Zilla::Plugin::PodPurler'   => {                         } ],
    [ 'Dist::Zilla::Plugin::Repository'  => {                         } ],
  );

  eval "require $_->[0]" or die for @plugins; ## no critic Carp

  @plugins->map(sub { $_->[1]{'=name'} = "$class/$_->[0]" });

  return @plugins;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
