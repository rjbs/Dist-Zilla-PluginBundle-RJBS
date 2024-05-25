package Dist::Zilla::PluginBundle::RJBS;
# ABSTRACT: BeLike::RJBS when you build your dists

use Moose;
use Dist::Zilla 2.100922; # TestRelease
with
    'Dist::Zilla::Role::PluginBundle::Easy',
    'Dist::Zilla::Role::PluginBundle::PluginRemover' => { -version => '0.103' },
    'Dist::Zilla::Role::PluginBundle::Config::Slicer';

use v5.34.0;
use Dist::Zilla::Pragmas;
use utf8;

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

package Dist::Zilla::Plugin::RJBSMisc {
  use Moose;
  with 'Dist::Zilla::Role::BeforeBuild',
       'Dist::Zilla::Role::AfterBuild',
       'Dist::Zilla::Role::MetaProvider',
       'Dist::Zilla::Role::PrereqSource';

  use v5.34.0;
  use Dist::Zilla::Pragmas;

  has perl_window => (is => 'ro');
  has package_name_version => (is => 'ro');

  sub metadata ($self) {
    return { x_rjbs_perl_window => $self->perl_window };
  }

  sub register_prereqs ($self) {
    if ($self->package_name_version) {
      $self->zilla->register_prereqs(
        { phase => 'runtime', type => 'requires' },
        perl => '5.012',
      );
    }
  }

  sub before_build ($self, @) {
    unless (defined $self->perl_window) {
      $self->log("❗️ did not set perl-window!");
    }
  }

  sub after_build ($self, @) {
    if (grep {; /rjbs\@cpan\.org/ } $self->zilla->authors->@*) {
      $self->log('Authors still contain rjbs@cpan.org!  Needs an update.');
    }
  }
}

has manual_version => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => sub ($self) { $self->payload->{manual_version} },
);

has major_version => (
  is      => 'ro',
  isa     => 'Int',
  lazy    => 1,
  default => sub ($self) { $self->payload->{version} || 0 },
);

has is_task => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => sub ($self) { $self->payload->{task} },
);

has github_issues => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => sub ($self) { $self->payload->{github_issues} // 1 },
);

has homepage => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default => sub ($self) { $self->payload->{homepage} // '' },
);

has weaver_config => (
  is      => 'ro',
  isa     => 'Str',
  lazy    => 1,
  default => sub ($self) { $self->payload->{weaver_config} || '@RJBS' },
);

sub mvp_multivalue_args { qw(dont_compile) }

sub mvp_aliases {
  return {
    'is-task'       => 'is_task',
    'major-version' => 'major_version',
    'perl-window'   => 'perl_window',
    'dont-compile'  => 'dont_compile',
    'weaver-config' => 'weaver_config',
    'manual-version'       => 'manual_version',
    'primary-branch'       => 'primary_branch',
    'package-name-version' => 'package_name_version',
  }
}

has dont_compile => (
  is      => 'ro',
  isa     => 'ArrayRef[Str]',
  lazy    => 1,
  default => sub ($self) { $self->payload->{dont_compile} || [] },
);

has package_name_version => (
  is      => 'ro',
  isa     => 'Bool',
  lazy    => 1,
  default => sub ($self) { $self->payload->{package_name_version}
                // $self->payload->{'package-name-version'}
                // 1
  },
);

has perl_window => (
  is      => 'ro',
  lazy    => 1,
  default => sub ($self) {
    # XXX: Fix this better.
    # See, we have all these mvp aliases to convert foo-bar to foo_bar, but
    # those aliases aren't run on the bundle options when passed through a
    # @Filter.  So:
    #
    # [@Filter]
    # -bundle = @RJBS
    # perl-window = no-mercy
    #
    # ...didn't work, because the payload had 'perl-window' and not
    # 'perl_window'.  Probably this aliasing should happen during the @Filter
    # process, but it's kind of a hot mess in here.  This key is the most
    # important one, and this comment is here to remind me what happened if I
    # ever hear this on some other library.
    $self->payload->{perl_window} // $self->payload->{'perl-window'}
  },
);

has primary_branch => (
  is      => 'ro',
  lazy    => 1,
  default => sub ($self) {
    # XXX: Fix this better.  See matching comment in perl_window attr.
    return $self->payload->{primary_branch}
        // $self->payload->{'primary-branch'}
        // 'main'
  },
);

sub configure ($self) {
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
      skip  => [ 'Dist::Zilla::Plugin::RJBSMisc' ],
      # check_all_prereqs => 1, # <-- not sure yet -- rjbs, 2013-09-23
    } ],
  );

  $self->add_bundle('@Filter', {
    '-bundle' => '@Basic',
    '-remove' => [
      'GatherDir',
      'ExtraTests',
      'MakeMaker',
    ],
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
    [
      'Git::Remote::Check' => {
        remote_name   => 'github',
        remote_branch => $self->primary_branch,
        branch        => $self->primary_branch,
        do_update     => 1,
      },
    ],
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
    our $perl_window = $self->perl_window;
    $self->add_plugins([
      PodWeaver => {
        config_plugin => $self->weaver_config,
        replacer      => 'replace_with_comment',
      }
    ]);
  }

  $self->add_plugins(
    [ RJBSMisc => {
        map {; $_ => scalar $self->$_ } qw(
          package_name_version
          perl_window
        )
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
