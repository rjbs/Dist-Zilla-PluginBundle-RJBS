package Dist::Zilla::PluginBundle::RJBS;
# ABSTRACT: BeLike::RJBS when you build your dists

use Moose;
use Moose::Autobox;
use Dist::Zilla 2.100922; # TestRelease
with 'Dist::Zilla::Role::PluginBundle';

=head1 DESCRIPTION

This is the plugin bundle that RJBS uses.  It is equivalent to:

  [TestRelease]

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

sub bundle_config {
  my ($self, $section) = @_;
  my $class = (ref $self) || $self;

  my $arg     = $section->{payload};
  my $is_task = $arg->{task};
  my $prefix  = 'Dist::Zilla::Plugin::';

  my @plugins;

  push @plugins, [
    "$section->{name}/TestRelease" => "${prefix}TestRelease" => {}
  ];

  push @plugins, Dist::Zilla::PluginBundle::Basic->bundle_config({
    name    => $section->{name} . '/@Basic',
    payload => { },
  });

  my $version_format;
  my $major_version = 0;

  if ($is_task) {
    $version_format = q<{{ cldr('yyyyMMdd') }}.>
                    . sprintf('%03u', ($ENV{N} || 0))
                    . ($ENV{DEV} ? (sprintf '_%03u', $ENV{DEV}) : '') ;
  } else {
    $major_version  = defined $arg->{version} ? $arg->{version} : 0;
    $version_format = q<{{ $major }}.{{ cldr('yyDDD') }}>
                    . sprintf('%01u', ($ENV{N} || 0))
                    . ($ENV{DEV} ? (sprintf '_%03u', $ENV{DEV}) : '') ;
  }

  my @extra = map {[ "$section->{name}/$_->[0]" => "$prefix$_->[0]" => $_->[1] ]}
  (
    [ AutoPrereq  => {} ],
    ($arg->{manual_version} ? () :
      [
        AutoVersion => {
          major     => $major_version,
          format    => $version_format,
          time_zone => 'America/New_York',
        }
      ]
    ),
    [ PkgVersion     => { } ],
    [ MetaConfig     => { } ],
    [ MetaJSON       => { } ],
    [ NextRelease    => { } ],
    [ PodSyntaxTests => { } ],
    [ ($is_task ? 'TaskWeaver' : 'PodWeaver') => { config_plugin => '@RJBS' } ],
    [ Repository   => { } ],
  );

  push @plugins, @extra;

  push @plugins, Dist::Zilla::PluginBundle::Git->bundle_config({
    name    => "$section->{name}/\@Git",
    payload => {
      tag_format => '%v',
    },
  });

  return @plugins;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
