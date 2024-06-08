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

This file is static, and should only need to be rebuilt when C<workflower>
itself has had notable changes.

=cut

sub opt_spec {
}

sub abstract { "install rjbs's usual GitHub Actions workflow" }

sub execute ($self, $opt, $arg) {
  my $template = $self->section_data('workflow.yml')->$*;

  my $workflow_dir = path(".github/workflows");
  $workflow_dir->mkpath;

  $workflow_dir->child('multiperl-test.yml')->spew_utf8($template);

  $self->zilla->log("Workflow installed.");
  return;
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
    outputs:
      perl-versions: ${{ steps.build-archive.outputs.perl-versions }}
    steps:
    - name: Build archive
      id: build-archive
      uses: rjbs/dzil-build@main

  multiperl-test:
    needs: build-tarball
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        perl-version: ${{ fromJson(needs.build-tarball.outputs.perl-versions) }}

    container:
      image: perldocker/perl-tester:${{ matrix.perl-version }}

    steps:
    - name: Test distribution
      uses: rjbs/test-perl-dist@v0
