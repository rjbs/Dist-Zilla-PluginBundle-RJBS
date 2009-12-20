use strict;
use warnings;
package Pod::Weaver::PluginBundle::RJBS;
# ABSTRACT: RJBS's default Pod::Weaver config

=head1 OVERVIEW

Equivalent to:

=for :list
* C<@Default>
* C<-WikiDoc>
* C<-List>

=cut

sub mvp_bundle_config {
  return (
    [ '@RJBS/Default', 'Pod::Weaver::PluginBundle::Default', {} ],
    [ '@RJBS/WikiDoc', 'Pod::Weaver::Plugin::WikiDoc',       {} ],
    [ '@RJBS/List',    'Pod::Weaver::Plugin::List',          {} ],
  );
}

1;
