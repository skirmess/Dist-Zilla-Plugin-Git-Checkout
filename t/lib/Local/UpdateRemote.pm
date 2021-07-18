package Local::UpdateRemote;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.001';

use Moose;

with 'Dist::Zilla::Role::Plugin';

use Git::Wrapper;
use MooseX::Types::Moose qw(Str);
use Path::Tiny;

use namespace::autoclean;

has repo => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

around plugin_from_config => sub {
    my $orig         = shift @_;
    my $plugin_class = shift @_;

    my $instance = $plugin_class->$orig(@_);

    my $repo_path = $instance->repo;

    my $file_c = path($repo_path)->child('C');
    $file_c->spew('1087');

    my $git = Git::Wrapper->new($repo_path);
    $git->add('C');
    $git->commit( { message => 'third commit' } );

    $git->tag( '-d', 'my-tag' );
    $git->tag('my-tag');

    return $instance;
};

__PACKAGE__->meta->make_immutable;

1;

__END__

# vim: ts=4 sts=4 sw=4 et: syntax=perl
