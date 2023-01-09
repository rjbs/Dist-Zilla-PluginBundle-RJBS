package Dist::Zilla::App::Command::workflower;
# ABSTRACT: install rjbs's usual GitHub Actions workflow

use Dist::Zilla::Pragmas;

use Dist::Zilla::App -command;

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

sub execute {
  my ($self, $opt, $arg) = @_;

  my $zilla = $self->zilla;

  $_->before_build       for $zilla->plugins_with(-BeforeBuild)->@*;
  $_->gather_files       for $zilla->plugins_with(-FileGatherer)->@*;
  $_->set_file_encodings for $zilla->plugins_with(-EncodingProvider)->@*;
  $_->prune_files        for $zilla->plugins_with(-FilePruner)->@*;
  $_->munge_files        for $zilla->plugins_with(-FileMunger)->@*;
  $_->register_prereqs   for $zilla->plugins_with(-PrereqSource)->@*;

  my $prereqs = $zilla->prereqs;

  my $minimum_perl = $prereqs->merged_prereqs;

  for (my $i = 8; $i <= 36; $i += 2) {
    say $i;
  }
}

1;
