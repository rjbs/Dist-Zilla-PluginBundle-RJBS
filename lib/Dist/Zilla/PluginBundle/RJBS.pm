package Dist::Zilla::PluginBundle::RJBS;
# ABSTRACT: BeLike::RJBS when you build your dists

use Moose;
use Dist::Zilla 2.100922; # TestRelease
with 'Dist::Zilla::Role::PluginBundle::Easy';

=head1 DESCRIPTION

This is the plugin bundle that RJBS uses.  It is more or less equivalent to:

  [Git::GatherDir]
  [@Basic]
  ; ...but without GatherDir and ExtraTests and MakeMaker

  [MakeMaker]
  default_jobs = 9

  [AutoPrereqs]
  [Git::NextVersion]
  [PkgVersion]
  die_on_existing_version = 1
  die_on_line_insertion   = 1
  [MetaConfig]
  [MetaJSON]
  [NextRelease]

  [Test::ChangesHasContent]
  [PodSyntaxTests]
  [Test::ReportPrereqs]

  [PodWeaver]
  config_plugin = @RJBS

  [GithubMeta]
  remote = github
  remote = origin

  [@Git]
  tag_format = %v

  [Git::Contributors]

If the C<task> argument is given to the bundle, PodWeaver is replaced with
TaskWeaver and Git::NextVersion is replaced with AutoVersion.  If the
C<manual_version> argument is given, AutoVersion is omitted.

If the C<github_issues> argument is given, and true, the F<META.*> files will
point to GitHub issues for the dist's bugtracker.

=cut

use Dist::Zilla::PluginBundle::Basic;
use Dist::Zilla::PluginBundle::Filter;
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

has github_issues => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => sub { $_[0]->payload->{github_issues} // 1 },
);

has homepage => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default => sub { $_[0]->payload->{homepage} // '' },
);

has weaver_config => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default => sub { $_[0]->payload->{weaver_config} || '@RJBS' },
);

sub mvp_multivalue_args { qw(dont_compile) }

has dont_compile => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  lazy    => 1,
  default => sub { $_[0]->payload->{dont_compile} || [] },
);

has package_name_version => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => sub { $_[0]->payload->{package_name_version} // 0 },
);

sub configure {
  my ($self) = @_;

  $self->log_fatal("you must not specify both weaver_config and is_task")
    if $self->is_task and $self->weaver_config ne '@RJBS';

  $self->add_plugins('Git::GatherDir');
  $self->add_plugins('CheckPrereqsIndexed');
  $self->add_plugins('CheckExtraTests');
  $self->add_plugins(
    [ PromptIfStale => 'RJBS-Outdated' => {
      phase  => 'build',
      module => 'Dist::Zilla::PluginBundle::RJBS',
    } ],
    [ PromptIfStale => 'CPAN-Outdated' => {
      phase => 'release',
      check_all_plugins => 1,
      # check_all_prereqs => 1, # <-- not sure yet -- rjbs, 2013-09-23
    } ],
  );
  $self->add_bundle('@Filter', {
    '-bundle' => '@Basic',
    '-remove' => [ 'GatherDir', 'ExtraTests', 'MakeMaker' ],
  });

  $self->add_plugins([ MakeMaker => { default_jobs => 9 } ]);

  $self->add_plugins('AutoPrereqs');

  unless ($self->manual_version) {
    if ($self->is_task) {
      my $v_format = q<{{cldr('yyyyMMdd')}}>
                   . sprintf('.%03u', ($ENV{N} || 0));

      $self->add_plugins([
        AutoVersion => {
          major     => $self->major_version,
          format    => $v_format,
          time_zone => 'America/New_York',
        }
      ]);
    } else {
      $self->add_plugins([
        'Git::NextVersion' => {
          version_regexp => '^([0-9]+\.[0-9]+)$',
        }
      ]);
    }
  }

  $self->add_plugins(
    [
      PkgVersion => {
        die_on_existing_version => 1,
        die_on_line_insertion   => 1,
        ($self->package_name_version ? (use_package => 1) : ()),
      },
    ],
    qw(
      MetaConfig
      MetaJSON
      NextRelease
      Test::ChangesHasContent
      PodSyntaxTests
      Test::ReportPrereqs
    ),
  );

  $self->add_plugins(
    [ Prereqs => 'TestMoreWithSubtests' => {
      -phase => 'test',
      -type  => 'requires',
      'Test::More' => '0.96'
    } ],
  );

  if ($self->is_task) {
    $self->add_plugins('TaskWeaver');
  } else {
    $self->add_plugins([
      PodWeaver => {
        config_plugin => $self->weaver_config,
        replacer      => 'replace_with_comment',
      }
    ]);
  }

  $self->add_plugins(
    [ GithubMeta => {
      remote => [ qw(github origin) ],
      issues => $self->github_issues,
      (length $self->homepage ? (homepage => $self->homepage) : ()),
    } ],
  );

  $self->add_bundle('@Git' => {
    tag_format => '%v',
    remotes_must_exist => 0,
    push_to    => [
      'origin :',
      'github :',
    ],
  });

  $self->add_plugins('Git::Contributors');
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
