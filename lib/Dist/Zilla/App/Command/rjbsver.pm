use strict;
use warnings;
package Dist::Zilla::App::Command::rjbsver;
# ABSTRACT: see what the mantissa for an rjbs-style version is today
use Dist::Zilla::App -command;

use DateTime ();

sub command_names { qw(rjbsver rjv) }

sub run {
  my $now = DateTime->now(time_zone => 'GMT');

  printf "Current version mantissa, assuming N=0, is %s0\n",
    $now->format_cldr('yyDDD');
}

1;
