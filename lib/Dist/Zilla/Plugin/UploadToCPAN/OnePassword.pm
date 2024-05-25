package Dist::Zilla::Plugin::UploadToCPAN::OnePassword;
# ABSTRACT: upload the dist to CPAN, credentials in 1Password

use Moose;
extends 'Dist::Zilla::Plugin::UploadToCPAN';

use v5.36.0;

use Password::OnePassword::OPCLI;

has op_item_id => (
  is  => 'ro',
  isa => 'Str',
  default => sub {
    my $item_id = $ENV{DZIL_PAUSE_1P_ITEM_ID};

    confess "no op_item_id given and no DZIL_PAUSE_1P_ITEM_ID env var"
      unless length $item_id;

    confess "bogus-looking 1Password item id in DZIL_PAUSE_1P_ITEM_ID"
      unless $item_id =~ /\A\p{PosixAlnum}+\z/;

    $item_id;
  },
);

has _op_item_fields => (
  is => 'ro',
  isa => 'HashRef',
  lazy    => 1,
  default => sub ($self) {
    my $item_id = $self->op_item_id;

    confess "bogus-looking 1Password item id"
      unless $item_id =~ /\A\p{PosixAlnum}+\z/;

    my $struct = Password::OnePassword::OPCLI->new->get_item($item_id);

    my $field_aref = $struct->{fields};
    my %fields = map {; $_->{id} => $_->{value} } @$field_aref;

    return \%fields;
  },
);

sub username ($self) {
  $self->_op_item_fields->{username}
    // Carp::croak("no username field in 1Password credential")
}

sub password ($self) {
  $self->_op_item_fields->{password}
    // Carp::croak("no password field in 1Password credential")
}

# Overriding this method is just more of a show of how this plugin is kind of a
# grody hack.  The version of this method in UploadToCPAN does the checks in a
# try block with no catch, so it wasn't saying "getting pw from 1P is throwing
# an error, it was saying "you need to supply a password".  Ugh.
#
# I think the real solution is to use the normal UploadToCPAN but with a
# smarter stash. -- rjbs, 2024-05-25
sub before_release {
  my $self = shift;

  my $problem;

  for my $attr (qw(username password)) {
    unless (length $self->$attr) {
      $self->log_fatal(['You need to supply a %s', $attr]);
    }
  }
}

1;
