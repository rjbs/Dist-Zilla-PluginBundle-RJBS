package Dist::Zilla::App::Command::workflower;
# ABSTRACT: install rjbs's usual GitHub Actions workflow

use v5.34.0;
use Dist::Zilla::Pragmas;

use Dist::Zilla::App -command;

use Sub::Exporter::ForMethods ();
use Data::Section
  { installer => Sub::Exporter::ForMethods::method_installer },
  -setup => {};
use Path::Tiny;

=head1 SYNOPSIS

  dzil workflower

=head1 DESCRIPTION

This command will make sure that F<.github/workflows> exists and contains
F<multiperl-test.yml>, and that I<that> contains the latest version of RJBS's
usual workflow for testing Dist::Zilla-built dists.

The only customization, for now, is that the list of Perl versions tested will
not include anything before the minimum perl required for the dist being built.

=cut

sub opt_spec {
}

sub abstract { "install rjbs's usual GitHub Actions workflow" }

sub execute ($self, $opt, $arg) {
  my $template = $self->section_data('workflow.yml')->$*;
  my $versions = sprintf '[ %s ]',
                  join q{, }, map {; qq{"$_"} } $self->_perl_versions_to_test;

  $template =~ s/%%VERSIONS%%/$versions/g;

  my $workflow_dir = path(".github/workflows");
  $workflow_dir->mkpath;

  $workflow_dir->child('multiperl-test.yml')->spew_utf8($template);

  $self->zilla->log("Workflow installed.");
  return;
}

sub _perl_versions_to_test ($self) {
  my $zilla = $self->zilla;

  $_->before_build       for $zilla->plugins_with(-BeforeBuild)->@*;
  $_->gather_files       for $zilla->plugins_with(-FileGatherer)->@*;
  $_->set_file_encodings for $zilla->plugins_with(-EncodingProvider)->@*;
  $_->prune_files        for $zilla->plugins_with(-FilePruner)->@*;
  $_->munge_files        for $zilla->plugins_with(-FileMunger)->@*;
  $_->register_prereqs   for $zilla->plugins_with(-PrereqSource)->@*;

  my $prereqs = $zilla->prereqs;
  $prereqs->finalize;

  my $merged = $prereqs->merged_requires;

  my @test = ('devel');

  for (my $i = 38; $i >= 8; $i -= 2) {
    last unless $merged->accepts_module(perl => "v5.$i");
    push @test, "5.$i";
  }

  return @test;
}

1;
__DATA__
___[ workflow.yml ]___
name: "multiperl test"
on:
  push:
    branches: "*"
    tags-ignore: "*"
  pull_request: ~

jobs:
  build-tarball:
    runs-on: ubuntu-latest
    steps:
      - name: Build archive
        uses: rjbs/dzil-build@v0

  multiperl-test:
    needs: build-tarball
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        perl-version: %%VERSIONS%%

    container:
      image: perldocker/perl-tester:${{ matrix.perl-version }}

    steps:
      - name: Test distribution
        uses: rjbs/test-perl-dist@v0
