package Acceptessa2::Mail::Parameter;
use Moose;

has from       => (is => 'ro', isa => 'Str',     required => 1);
has to         => (is => 'ro', isa => 'Str',     required => 1);
has cc         => (is => 'ro', isa => 'Str',     required => 0);
has template   => (is => 'ro', isa => 'Str',     required => 1);
has data       => (is => 'ro', isa => 'HashRef', required => 1);
has attachment => (is => 'ro', isa => 'HashRef', required => 0);

1;
