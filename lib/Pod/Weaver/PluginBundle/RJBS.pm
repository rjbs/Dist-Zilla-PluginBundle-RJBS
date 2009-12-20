use strict;
use warnings;
package Pod::Weaver::PluginBundle::RJBS;
# ABSTRACT: RJBS's default Pod::Weaver config

=head1 OVERVIEW

Equivalent to:

=for :list
* C<@Default>
* C<-Transformer> with L<Pod::Elemental::Transformer::List>

=cut

sub mvp_bundle_config {
  return (
    [ '@RJBS/Default', 'Pod::Weaver::PluginBundle::Default', {} ],
    [ '@RJBS/List',    'Pod::Weaver::Plugin::Transformer',
      { 'transformer' => 'List' }
    ],
  );
}

1;
