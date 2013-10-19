use strict;
use warnings;
package Pod::Weaver::PluginBundle::RJBS;
# ABSTRACT: RJBS's default Pod::Weaver config

=head1 OVERVIEW

Roughly equivalent to:

=for :list
* C<@Default>
* C<-Transformer> with L<Pod::Elemental::Transformer::List>

=cut

use Pod::Weaver::Config::Assembler;
sub _exp { Pod::Weaver::Config::Assembler->expand_package($_[0]) }

sub mvp_bundle_config {
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
    [ '@RJBS/Legal',     _exp('Legal'),     {} ],
    [ '@RJBS/List',      _exp('-Transformer'), { 'transformer' => 'List' } ],
  );

  return @plugins;
}

1;
