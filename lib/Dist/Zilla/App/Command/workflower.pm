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

# FUTURE ENHANCEMENT(s):
# * install faster (see below)
# * use github.event.repository.name or ${GITHUB_REPOSITORY#*/} as the
#   tarball/build name instead of Dist-To-Test

jobs:
  build-tarball:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
    steps:
      - name: Check out repo
        uses: actions/checkout@v4
      - name: Install cpm
        run: |
          curl https://raw.githubusercontent.com/skaji/cpm/main/cpm > /tmp/cpm
          chmod u+x /tmp/cpm
      - name: Install Dist::Zilla
        run: sudo apt-get install -y libdist-zilla-perl libdist-zilla-plugin-git-perl libpod-weaver-perl
      - name: Install authordeps
        run: |
          dzil authordeps --missing > /tmp/deps-phase-1.txt
          echo "---BEGIN AUTHORDEPS---"
          cat /tmp/deps-phase-1.txt
          echo "---END AUTHORDEPS---"
          sudo /tmp/cpm install -g - < /tmp/deps-phase-1.txt
      - name: Install missing prereqs
        run: |
          dzil listdeps --author --missing > /tmp/deps-phase-2.txt
          echo "---BEGIN PREREQS---"
          cat /tmp/deps-phase-2.txt
          echo "---END PREREQS---"
          sudo /tmp/cpm install -g - < /tmp/deps-phase-2.txt
      - name: Build tarball
        run: |
          dzil build --in Dist-To-Test
          tar zcvf Dist-To-Test.tar.gz Dist-To-Test
      - name: Upload tarball
        uses: actions/upload-artifact@v4
        with:
          name: Dist-To-Test.tar.gz
          path: Dist-To-Test.tar.gz

  multiperl-test:
    needs: build-tarball
    env:
      # some plugins still needs this to run their tests...
      PERL_USE_UNSAFE_INC: 0
      AUTHOR_TESTING: 1
      AUTOMATED_TESTING: 1

    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        perl-version: %%VERSIONS%%

    container:
      image: perldocker/perl-tester:${{ matrix.perl-version }}

    steps:
      - name: Download tarball
        uses: actions/download-artifact@v4
        with:
          name: Dist-To-Test.tar.gz
      - name: Extract tarball
        run: tar zxvf Dist-To-Test.tar.gz
      - name: Install dependencies
        working-directory: ./Dist-To-Test
        run: cpm install -g
      - name: Makefile.PL
        working-directory: ./Dist-To-Test
        run: perl Makefile.PL
      - name: Install yath
        run: cpm install -g Test2::Harness Test2::Harness::Renderer::JUnit
      - name: Run the tests
        working-directory: ./Dist-To-Test
        run: |
          JUNIT_TEST_FILE="/tmp/test-output.xml" ALLOW_PASSING_TODOS=1 yath test --renderer=Formatter --renderer=JUnit -D
      - name: Publish test report
        uses: mikepenz/action-junit-report@v4
        if: always() # always run even if the previous step fails
        with:
          check_name: JUnit Report (${{ matrix.perl-version }})
          report_paths: /tmp/test-output.xml
