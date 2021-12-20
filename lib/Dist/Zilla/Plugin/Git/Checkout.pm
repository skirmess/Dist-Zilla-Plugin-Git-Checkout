package Dist::Zilla::Plugin::Git::Checkout;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.003';

use Moose;

with 'Dist::Zilla::Role::BeforeRelease';

use Git::Background;
use Git::Version::Compare qw(ge_git);
use MooseX::Types::Moose qw(Bool Str);
use Path::Tiny;
use Term::ANSIColor qw(colored);

use namespace::autoclean;

has checkout => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    default => 'master',
);

has dir => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    default => sub { path( shift->repo )->basename('.git') },
);

has push_url => (
    is  => 'ro',
    isa => Str,
);

has repo => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has _is_dirty => (
    is      => 'rw',
    isa     => Bool,
    default => 0,
);

sub before_release {
    my ($self) = @_;

    return if !$self->_is_dirty;

    return if $self->zilla->chrome->prompt_yn(
        'Workspace ' . $self->dir . ' is dirty and was not updated. Release anyway?',
        { default => 0 },
    );

    $self->log_fatal('Aborting release');

    return;
}

sub _checkout {
    my ($self) = @_;

    my $git_version = Git::Background->version;
    $self->log_fatal(q{No 'git' in PATH}) if !defined $git_version;

    # https://stackoverflow.com/a/6978402/8173111
    # git status --porcelain, commit 6f15787, September 2009, git 1.7.0,
    # https://github.com/git/git/commit/6f15787181a163e158c6fee1d79085b97692ac2f
    $self->log_fatal(q{Your 'git' is to old. At least Git 1.7.0 is needed.}) if !ge_git( $git_version, '1.7.0' );

    my $dir      = path( $self->zilla->root )->child( path( $self->dir ) )->absolute;
    my $repo     = $self->repo;
    my $checkout = $self->checkout;

    my $git = Git::Background->new($dir);

    if ( -d $dir ) {
        $self->log_fatal("Directory $dir exists but is not a Git repository") if !-d $dir->child('.git');

        my ($origin) = $git->run( 'config', 'remote.origin.url' )->stdout;
        $self->log_fatal("Directory $dir is not a Git repository for $repo") if $origin ne $repo;

        if ( $git->run( 'status', '--porcelain' )->stdout ) {
            $self->log( colored( "Git workspace $dir is dirty - skipping checkout", 'yellow' ) );
            $self->_is_dirty(1);
            return;
        }

        $self->log("Fetching $repo in $dir");
        $git->run( 'fetch', '--tags', '-f' )->get;
    }
    else {
        $self->log("Cloning $repo into $dir");
        $git->run( 'clone', $repo, $dir->stringify, { dir => undef } )->get;
    }

    # Configure or remove the push url
    if ( defined $self->push_url ) {
        $git->run( 'remote', 'set-url', '--push', 'origin', $self->push_url )->get;
    }
    else {
        my ($push_url) = eval { $git->run( 'config', 'remote.origin.pushurl' )->stdout; };
        if ( defined $push_url ) {
            $git->run( 'remote', 'set-url', '--delete', '--push', 'origin', $push_url )->get;
        }
    }

    # We don't know what the default branch is. It's easier to just check it out again.
    $self->log("Checking out $checkout in $dir");
    $git->run( 'checkout', $checkout )->get;

    # This fails if we're not on a tracking branch - ignore the failure
    eval { $git->run( 'pull', '--ff-only' )->get; };    ## no critic (ErrorHandling::RequireCheckingReturnValueOfEval)

    return;
}

around plugin_from_config => sub {
    my ( $orig, $plugin_class, $name, $payload, $section ) = @_;

    my $instance = $plugin_class->$orig( $name, $payload, $section );

    $instance->_checkout;

    return $instance;
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Git::Checkout - clone and checkout a Git repository

=head1 VERSION

Version 0.003

=head1 SYNOPSIS

  # in dist.ini:
  [Git::Checkout]
  repo = https://github.com/skirmess/dzil-inc.git

=head1 DESCRIPTION

This plugin clones, or if it is already cloned, fetches and updates a Git
repository.

The plugin runs during the initialization phase, which is the same for
bundles and plugins. You can check out a Git repository and load bundles
or plugins from this repository.

  # in dist.ini
  [Git::Checkout]
  repo = https://github.com/skirmess/dzil-inc.git

  ; add the lib directory inside the checked out Git repository to @INC
  [lib]
  lib = dzil-inc/lib

  ; this bundle is run from inside the checked out Git repositories lib
  ; directory
  [@BundleFromRepository]

=head1 USAGE

=head2 checkout

Specifies what to check out. This can be a branch, a tag or a revision.
Defaults to C<master>.

=head2 dir

The repositories workspace is checked out into this directory. This defaults
to the basename of the repo without the C<.git> suffix.

=head2 push_url

Allows you to specify a different push url for the repositories origin. One
possible scenario would be if you would like to clone via http but push via
ssh. This is optional.

=head2 repo

Specifies the address of the repository to clone. This is required.

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/skirmess/Dist-Zilla-Plugin-Git-Checkout/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software. The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/skirmess/Dist-Zilla-Plugin-Git-Checkout>

  git clone https://github.com/skirmess/Dist-Zilla-Plugin-Git-Checkout.git

=head1 AUTHOR

Sven Kirmess <sven.kirmess@kzone.ch>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2020-2021 by Sven Kirmess.

This is free software, licensed under:

  The (two-clause) FreeBSD License

=head1 SEE ALSO

L<Dist::Zilla>, L<lib>

=cut

# vim: ts=4 sts=4 sw=4 et: syntax=perl
