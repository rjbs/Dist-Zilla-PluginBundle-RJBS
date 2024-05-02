package Dist::Zilla::Plugin::UploadToCPAN::OnePassword;
# ABSTRACT: upload the dist to CPAN, credentials in 1Password

use Moose;
extends 'Dist::Zilla::Plugin::UploadToCPAN';

use JSON::MaybeXS ();

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

has op_items => (
  is => 'ro',
  isa => 'HashRef',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    my $item_id = $self->op_item_id;

    confess "bogus-looking 1Password item id"
      unless $item_id =~ /\A\p{PosixAlnum}+\z/;

    my $json = `op item get --format json $item_id --fields username,password`;

    my $field_aref = JSON::MaybeXS->new->decode($json);

    my %item = map {; $_->{id} => $_->{value} } @$field_aref;

    \%item;
  },
);

has '+username' => (
  default => sub {
    my ($self) = @_;
    $self->op_items->{username};
  }
);

has '+password' => (
  default => sub {
    my ($self) = @_;
    $self->op_items->{password};
  }
);

1;
