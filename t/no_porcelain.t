#!/usr/bin/perl

use 5.006;
use strict;
use warnings;

use Git::Wrapper;
use Path::Tiny;
use Test::DZil;
use Test::Fatal;
use Test::MockModule;
use Test::More 0.88;
use Test::TempDir::Tiny;

use lib path(__FILE__)->parent->child('lib')->stringify;

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

    note('no git status --porcelain');
    {
        my $module = Test::MockModule->new('Git::Wrapper');
        $module->mock( 'supports_status_porcelain', sub { return; } );

        my $tzil;
        my $exception = exception {
            $tzil = Builder->from_config(
                { dist_root => tempdir() },
                {
                    add_files => {
                        'source/dist.ini' => simple_ini(
                            '=Local::CreateFakeGitWorkspace',
                            [
                                'Git::Checkout',
                                {
                                    repo => $repo_path->stringify(),
                                    dir  => 'ws',
                                },
                            ],
                        ),
                    },
                },
            );
        };

        like( $exception, qr{ \Q[Git::Checkout] Your 'git' is to old\E }xsm, q{throws an exception if 'git status --porcelain' is not supported} );
    }

    done_testing;

    return;
}

# vim: ts=4 sts=4 sw=4 et: syntax=perl
