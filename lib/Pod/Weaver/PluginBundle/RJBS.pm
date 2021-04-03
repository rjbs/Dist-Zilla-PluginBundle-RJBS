use v5.20.0;
use warnings;
package Pod::Weaver::PluginBundle::RJBS;
# ABSTRACT: RJBS's default Pod::Weaver config

=head1 OVERVIEW

I<Roughly> equivalent to:

=for :list
* C<@Default>
* C<-Transformer> with L<Pod::Elemental::Transformer::List>

=cut

use Pod::Weaver::Config::Assembler;
sub _exp { Pod::Weaver::Config::Assembler->expand_package($_[0]) }

sub mvp_bundle_config {
  my ($self, $arg) = @_;

  my @plugins;
  push @plugins, (
    [ '@RJBS/CorePrep',       _exp('@CorePrep'),        {} ],
    [ '@RJBS/SingleEncoding', _exp('-SingleEncoding'),  {} ],
    [ '@RJBS/Name',           _exp('Name'),             {} ],
    [ '@RJBS/Version',        _exp('Version'),          {} ],

    [ '@RJBS/Prelude',     _exp('Region'),  { region_name => 'prelude'     } ],
    [ '@RJBS/Synopsis',    _exp('Generic'), { header      => 'SYNOPSIS'    } ],
    [ '@RJBS/Description', _exp('Generic'), { header      => 'DESCRIPTION' } ],
    [ '@RJBS/Overview',    _exp('Generic'), { header      => 'OVERVIEW'    } ],

    [ '@RJBS/Stability',   _exp('Generic'), { header      => 'STABILITY'   } ],
  );

  if (my $stability = $Dist::Zilla::PluginBundle::RJBS::stability) {
    push @plugins, $self->_stability_plugin($stability);
  }

  for my $plugin (
    [ 'Attributes', _exp('Collect'), { command => 'attr'   } ],
    [ 'Methods',    _exp('Collect'), { command => 'method' } ],
    [ 'Functions',  _exp('Collect'), { command => 'func'   } ],
  ) {
    $plugin->[2]{header} = uc $plugin->[0];
    push @plugins, $plugin;
  }

  push @plugins, (
    [ '@RJBS/Leftovers', _exp('Leftovers'), {} ],
    [ '@RJBS/postlude',  _exp('Region'),    { region_name => 'postlude' } ],
    [ '@RJBS/Authors',   _exp('Authors'),   {} ],
    [ '@RJBS/Contributors', _exp('Contributors'), {} ],
    [ '@RJBS/Legal',     _exp('Legal'),     {} ],
    [ '@RJBS/List',      _exp('-Transformer'), { 'transformer' => 'List' } ],
  );

  return @plugins;
}

my %STABILITY;

$STABILITY{toolchain} = <<'END';
This module is part of CPAN toolchain, or is treated as such.  As such, it
follows the agreement of the Perl Toolchain Gang to require no newer version of
perl than v5.8.1.  This version may change by agreement of the Toolchain Gang,
but for now is governed by the L<Lancaster
Consensus|https://github.com/Perl-Toolchain-Gang/toolchain-site/blob/master/lancaster-consensus.md>
of 2013.
END

my $STOCK = <<'END';
Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.
END

$STABILITY{extreme} = <<"END";
This module has an extremely long-term perl support period.  That means it will
not require a version of perl released fewer than ten years ago.

$STOCK
END

$STABILITY{longterm} = <<"END";
This module has a long-term perl support period.  That means it will not
require a version of perl released fewer than five years ago.

$STOCK
END

$STABILITY{standard} = <<"END";
This module has the same support period as perl itself:  it supports the two
most recent versions of perl.  (That is, if the most recently released version
is v5.40, then this module should work on both v5.40 and v5.38.)

$STOCK
END

sub _stability_plugin {
  my ($self, $name) = @_;

  Carp::confess("unknown stability level $name") unless exists $STABILITY{$name};

  return [
    '@RJBS/StockStability',
    _exp('GenerateSection'),
    {
      title  => 'STABILITY',
      text   => $STABILITY{$name},
    }
  ];
}

1;
