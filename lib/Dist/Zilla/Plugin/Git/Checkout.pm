package Dist::Zilla::Plugin::Git::Checkout;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.003';

use Moose;

with 'Dist::Zilla::Role::BeforeRelease';

use Git::Wrapper;
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

    $self->log_fatal(q{No 'git' in PATH}) if !Git::Wrapper->has_git_in_path;

    print STDERR `git --version`;

    my $dir      = path( $self->zilla->root )->child( path( $self->dir ) )->absolute;
    my $repo     = $self->repo;
    my $checkout = $self->checkout;

    print STDERR "Line: ", __LINE__, "\n";

    my $git = Git::Wrapper->new( $dir->stringify );
    print STDERR "Line: ", __LINE__, "\ndir = $dir\n";

    if ( -d $dir ) {
    print STDERR "Line: ", __LINE__, "\n";
        $self->log_fatal("Directory $dir exists but is not a Git repository") if !-d $dir->child('.git');
    print STDERR "Line: ", __LINE__, "\n";

        $self->log_fatal(q{Your 'git' is to old}) if !$git->supports_status_porcelain;
    print STDERR "Line: ", __LINE__, "\n";

        my ($origin) = $git->config('remote.origin.url');
    print STDERR "Line: ", __LINE__, "\n";
        $self->log_fatal("Directory $dir is not a Git repository for $repo") if $origin ne $repo;
    print STDERR "Line: ", __LINE__, "\n";

        if ( $git->status->is_dirty ) {
    print STDERR "Line: ", __LINE__, "\n";
            $self->log( colored( "Git workspace $dir is dirty - skipping checkout", 'yellow' ) );
    print STDERR "Line: ", __LINE__, "\n";
            $self->_is_dirty(1);
    print STDERR "Line: ", __LINE__, "\n";
            return;
        }
    print STDERR "Line: ", __LINE__, "\n";

        $self->log("Fetching $repo in $dir");
    print STDERR "Line: ", __LINE__, "\n";
        $git->fetch( '--tags', '-f' );
    print STDERR "Line: ", __LINE__, "\n";
    }
    else {
    print STDERR "Line: ", __LINE__, "\n";
        $self->log("Cloning $repo into $dir");
    print STDERR "Line: ", __LINE__, "\n";
        $git->clone( $repo, $dir->stringify );
    print STDERR "Line: ", __LINE__, "\n";
    }

    print STDERR "Line: ", __LINE__, "\n";
    # Configure or remove the push url
    if ( defined $self->push_url ) {
    print STDERR "Line: ", __LINE__, "\n";
        $git->remote( 'set-url', '--push', 'origin', $self->push_url );
    }
    else {
    print STDERR "Line: ", __LINE__, "\n";
        my ($push_url) = eval { $git->config('remote.origin.pushurl'); };
    print STDERR "Line: ", __LINE__, "\n";
        if ( defined $push_url ) {
    print STDERR "Line: ", __LINE__, "\n";
            $git->remote( 'set-url', '--delete', '--push', 'origin', $push_url );
    print STDERR "Line: ", __LINE__, "\n";
        }
    print STDERR "Line: ", __LINE__, "\n";
    }

    # We don't know what the default branch is. It's easier to just check it out again.
    print STDERR "Line: ", __LINE__, "\n";
    $self->log("Checking out $checkout in $dir");
    print STDERR "Checking out $checkout in $dir\n";
    {
        print STDERR `cd $dir && git tag`, "\n";
        #print `cd $dir && git status`;
        #print `cd $dir && git checkout $checkout`;
    }
    print STDERR "Line: ", __LINE__, "\n";
    print STDERR "-->", `ls -la $dir`, "<--\n";
    $git->checkout($checkout);
    print STDERR "Line: ", __LINE__, "\n";

    # This fails if we're not on a tracking branch - ignore the failure
    eval { $git->pull('--ff-only'); };    ## no critic (ErrorHandling::RequireCheckingReturnValueOfEval)
    print STDERR "Line: ", __LINE__, "\n";

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
