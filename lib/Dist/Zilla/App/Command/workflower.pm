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
  my $content = $self->section_data('workflow.yml')->$*;

  my $workflow_dir = path(".github/workflows");
  $workflow_dir->mkpath;

  my $target = $workflow_dir->child('dzil-matrix.yaml');

  if ($target->exists) {
    if (grep {; /\A\s*#+\s*do-not-regen/ } $target->lines) {
      $self->zilla->log('Workflow contains "do-not-regen", aborting.');
      return;
    }
  }

  my $old_digest = $target->exists ? $target->digest : undef;

  if ($old_digest) {
    require Digest::SHA;
    if (Digest::SHA::sha256_hex($content) eq $old_digest) {
      $self->zilla->log("Workflow already present and up to date.");
      return;
    }
  }

  $target->spew_utf8($content);
  my $verb = $old_digest ? "update" : "create";
  my $message = "Workflow ${verb}d.";
  $self->zilla->log($message);

  system("git", "add", "$target");
  system("git", "commit", "-m", "$target: $verb", "$target");

  return;
}

1;
__DATA__
___[ workflow.yml ]___
name: "dzil matrix"
on:
  workflow_dispatch: ~
  push:
    branches: "*"
    tags-ignore: "*"
  pull_request: ~

jobs:
  build-and-test:
    name: dzil-matrix
    uses: rjbs/dzil-actions/.github/workflows/dzil-matrix.yaml@v0
