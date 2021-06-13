package Dist::Zilla::PluginBundle::RJBS;
# ABSTRACT: BeLike::RJBS when you build your dists

use Moose;
use Dist::Zilla 2.100922; # TestRelease
with
    'Dist::Zilla::Role::PluginBundle::Easy',
    'Dist::Zilla::Role::PluginBundle::PluginRemover' => { -version => '0.103' },
    'Dist::Zilla::Role::PluginBundle::Config::Slicer';

use v5.20.0;
use experimental 'postderef'; # Not really an experiment anymore.

=head1 DESCRIPTION

This is the plugin bundle that RJBS uses.  It is more or less equivalent to:

  [Git::GatherDir]
  [@Basic]
  ; ...but without GatherDir and ExtraTests and MakeMaker

  [MakeMaker]
  default_jobs = 9
  eumm_version = 6.78

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

This bundle makes use of L<Dist::Zilla::Role::PluginBundle::PluginRemover> and
L<Dist::Zilla::Role::PluginBundle::Config::Slicer> to allow further customization.

=cut

use Dist::Zilla::PluginBundle::Basic;
use Dist::Zilla::PluginBundle::Filter;
use Dist::Zilla::PluginBundle::Git;

{
  package Dist::Zilla::Plugin::RJBSMisc;

  use Moose;
  with 'Dist::Zilla::Role::BeforeBuild';

  has perl_support => (is => 'ro');

  sub before_build {
    my ($self) = @_;

    if (grep {; /rjbs\@cpan\.org/ } $self->zilla->authors->@*) {
      $self->log_fatal('Authors still contain rjbs@cpan.org!  Needs an update.');
    }

    if (($self->perl_support // '') eq 'toolchain' && $self->package_name_version) {
      $self->log_fatal('This dist claims to be toolchain but uses "package NAME VERSION"');
    }
  }
}

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

sub mvp_aliases {
  return {
    'is-task'       => 'is_task',
    'major-version' => 'major_version',
    'perl-support'  => 'perl_support',
    'dont-compile'  => 'dont_compile',
    'weaver-config' => 'weaver_config',
    'manual-version'       => 'manual_version',
    'package-name-version' => 'package_name_version',
  }
}

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
  default => sub { $_[0]->payload->{package_name_version} // 1 },
);

has perl_support => (
  is      => 'ro',
  default => sub { $_[0]->payload->{perl_support} },
);

sub configure {
  my ($self) = @_;

  # It'd be nice to have a Logger here... -- rjbs, 2021-04-24
  die "you must not specify both weaver_config and is_task"
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

  $self->add_plugins([
    MakeMaker => {
      default_jobs  => 9,
      eumm_version  =>  6.78, # Stop using -w when running tests.
    }
  ]);

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
          version_by_branch => 1,
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
    our $perl_support = $self->perl_support;
    $self->add_plugins([
      PodWeaver => {
        config_plugin => $self->weaver_config,
        replacer      => 'replace_with_comment',
      }
    ]);
  }

  $self->add_plugins(
    [ RJBSMisc => {
        perl_support => $self->perl_support,
    } ],
  );

  $self->add_plugins(
    [ GithubMeta => {
      remote => [ qw(github) ],
      issues => $self->github_issues,
      (length $self->homepage ? (homepage => $self->homepage) : ()),
    } ],
  );

  $self->add_bundle('@Git' => {
    tag_format => '%v',
    remotes_must_exist => 0,
    push_to    => [
      'github :',
    ],
  });

  $self->add_plugins('Git::Contributors');
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
