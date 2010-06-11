package Dist::Zilla::PluginBundle::RJBS;
# ABSTRACT: BeLike::RJBS when you build your dists

use Moose;
use Moose::Autobox;
use Dist::Zilla 2.100922; # TestRelease
with 'Dist::Zilla::Role::PluginBundle::Easy';

=head1 DESCRIPTION

This is the plugin bundle that RJBS uses.  It is equivalent to:

  [@Basic]

  [AutoPrereq]
  [AutoVersion]
  [PkgVersion]
  [MetaConfig]
  [MetaJSON]
  [NextRelease]
  [PodSyntaxTests]

  [PodWeaver]
  config_plugin = @RJBS

  [Repository]

  [@Git]
  tag_format = %v

If the C<task> argument is given to the bundle, PodWeaver is replaced with
TaskWeaver.  If the C<manual_version> argument is given, AutoVersion is
omitted.

=cut

use Dist::Zilla::PluginBundle::Basic;
use Dist::Zilla::PluginBundle::Git;

has manual_version => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => sub { $_[0]->payload->{manual_version} },
);

has major_version => (
  is      => 'ro',
  isa     => 'Int',
  lazy    => 1,
  default => sub { $_[0]->payload->{version} || 0 },
);

has is_task => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => sub { $_[0]->payload->{task} },
);

has weaver_config => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default => sub { $_[0]->payload->{weaver_config} || '@RJBS' },
);

sub configure {
  my ($self) = @_;

  $self->log_fatal("you must not specify both weaver_config and is_task")
    if $self->is_task and $self->weaver_config ne '@RJBS';

  $self->add_bundle('@Basic');

  my $v_format = $self->is_task
    ? q<{{ cldr('yyyyMMdd') }}.> . sprintf('%03u', ($ENV{N} || 0))
    : q<{{ $major }}.{{ cldr('yyDDD') }}> . sprintf('%01u', ($ENV{N} || 0));

  # XXX: This can go away now that we have --trial, right? -- rjbs, 2010-04-13
  $v_format .= ($ENV{DEV} ? (sprintf '_%03u', $ENV{DEV}) : '');

  $self->add_plugins('AutoPrereq');

  unless ($self->manual_version) {
    $self->add_plugins([
      AutoVersion => {
        major     => $self->major_version,
        format    => $v_format,
        time_zone => 'America/New_York',
      }
    ]);
  }

  $self->add_plugins(qw(
    PkgVersion
    MetaConfig
    MetaJSON
    NextRelease
    PodSyntaxTests
    Repository
  ));

  if ($self->is_task) {
    $self->add_plugins('TaskWeaver');
  } else {
    $self->add_plugins([
      PodWeaver => { config_plugin => $self->weaver_config }
    ]);
  }

  $self->add_bundle('@Git' => { tag_format => '%v' });
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
