#!/usr/bin/perl

use 5.006;
use strict;
use warnings;

use Git::Wrapper;
use Path::Tiny;
use Test::DZil;
use Test::Fatal;
use Test::More 0.88;

use Cwd            ();
use File::Basename ();
use File::Spec     ();
use lib File::Spec->catdir( File::Basename::dirname( Cwd::abs_path __FILE__ ), 'lib' );

use Local::Test::TempDir qw(tempdir);

main();

sub main {

    note('create Git test repository');
    my $repo_path = path( tempdir() )->child('my_repo.git')->absolute;
    mkdir $repo_path or die "Cannot create $repo_path";

    {
        my $git = Git::Wrapper->new( $repo_path->stringify );
        $git->init;
        $git->config( 'user.email', 'test@example.com' );
        $git->config( 'user.name',  'Test' );

        my $file_A = $repo_path->child('D');
        $file_A->spew('5');
        $git->add('D');
        $git->commit( { message => 'initial commit' } );
    }

    note('no git in PATH');
  SKIP:
    {
        local $ENV{PATH} = path( tempdir() )->absolute->stringify;

        skip q{Cannot remove 'git' from PATH}, 1 if Git::Wrapper->has_git_in_path;

        my $tzil;
        my $exception = exception {
            $tzil = Builder->from_config(
                { dist_root => tempdir() },
                {
                    add_files => {
                        'source/dist.ini' => simple_ini(
                            [
                                'Git::Checkout',
                                {
                                    repo => $repo_path->stringify(),
                                },
                            ],
                        ),
                    },
                },
            );
        };

        like( $exception, qr{ \Q[Git::Checkout] No 'git' in PATH\E }xsm, q{throws an exception if there is no 'git' in PATH} );

    }

    done_testing;

    return;
}

# vim: ts=4 sts=4 sw=4 et: syntax=perl
