#!/usr/bin/perl

use 5.006;
use strict;
use warnings;

use Git::Repository;
use Path::Tiny;
use Test::DZil;
use Test::Fatal;
use Test::More 0.88;

use lib path(__FILE__)->absolute->parent->child('lib')->stringify;

use Local::Test::TempDir qw(tempdir);

main();

sub main {
    note('no attributes');
    {
        my $exception = exception {
            Builder->from_config(
                { dist_root => tempdir() },
                {
                    add_files => {
                        'source/dist.ini' => simple_ini(
                            'Git::Checkout',
                        ),
                    },
                },
            );
        };

        ok( defined $exception, q{throws an exception without a 'repo'} );
    }

  SKIP:
    {
        skip 'Cannot find Git in PATH',    1 if !eval { Git::Repository->version };
        skip 'Git must be at least 1.7.0', 1 if !Git::Repository->version_ge('1.7.0');

        note('create Git test repository');
        my $repo_path  = path( tempdir() )->child('my_repo.git')->absolute->stringify;
        my $repo_path2 = path($repo_path)->parent->child('my_repo2.git')->stringify;
        {
            my $error;
            {
                local $@;
                my $ok = eval {

                    # branch master, 2 commits, A ->  7
                    # branch dev,    3 commits, A -> 11, B -> 13
                    Git::Repository->run( 'clone', '--bare', path(__FILE__)->absolute->parent(2)->child('corpus/test.bundle')->stringify(), $repo_path, { quiet => 1, fatal => ['!0'] } );
                    my $git = Git::Repository->new( work_tree => $repo_path );
                    $git->run( 'remote', 'remove', 'origin', { quiet => 1, fatal => ['!0'] } );

                    # branch master, 1 commit, C -> 419
                    Git::Repository->run( 'clone', '--bare', path(__FILE__)->absolute->parent(2)->child('corpus/test2.bundle')->stringify(), $repo_path2, { quiet => 1, fatal => ['!0'] } );
                    $git = Git::Repository->new( work_tree => $repo_path2 );
                    $git->run( 'remote', 'remove', 'origin', { quiet => 1, fatal => ['!0'] } );

                    1;
                };

                if ( !$ok ) {
                    $error = $@;
                }
            }
            skip "Cannot setup test repository: $error", 1 if defined $error;
        }

        note('fresh checkouts');
        {
            my $tzil = Builder->from_config(
                { dist_root => tempdir() },
                {
                    add_files => {
                        'source/dist.ini' => simple_ini(
                            [
                                'Git::Checkout',
                                {
                                    repo => $repo_path,
                                },
                            ],
                            [
                                'Git::Checkout',
                                'secondCheckout',
                                {
                                    repo => $repo_path,
                                    dir  => 'my_repo2',
                                },
                            ],
                            [
                                'Git::Checkout',
                                'thirdCheckout',
                                {
                                    repo     => $repo_path,
                                    dir      => 'my_repo3',
                                    push_url => 'http://example.com/my_repo.git',
                                },
                            ],
                            [
                                'Git::Checkout',
                                'devBranchCheckout',
                                {
                                    repo     => $repo_path,
                                    dir      => 'my_repo_dev',
                                    checkout => 'dev',
                                },
                            ],
                            [
                                'Git::Checkout',
                                'devBranchCheckout2',
                                {
                                    repo     => $repo_path,
                                    dir      => 'my_repo_dev2',
                                    checkout => 'dev',
                                    push_url => 'http://example.com/my_dev_repo.git',
                                },
                            ],
                        ),
                    },
                },
            );

            note('default');
            {
                my $workdir = path( $tzil->root )->child('my_repo');
                ok( $workdir->is_dir(),                'workspace is checked out' );
                ok( $workdir->child('.git')->is_dir(), '... with a .git directory' );
                ok( -f $workdir->child('A'),           '... with the correct file ...' );
                ok( !-e $workdir->child('B'),          '... only' );
                is( $workdir->child('A')->slurp, '7', '... with the correct content' );

                my $git    = Git::Repository->new( work_tree => $workdir->stringify );
                my @config = $git->run( 'config', '-l' );
                is( scalar grep( { m{ ^ \Qremote.origin.pushurl=\E }xsm } @config ), 0, '... no push url is defined' );

                is( ( scalar grep { $_ eq "[Git::Checkout] Cloning $repo_path into $workdir" } @{ $tzil->log_messages() } ), 1, '... clone message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
                is( ( scalar grep { $_ eq "[Git::Checkout] Checking out master in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
            }

            note('with dir');
            {
                my $workdir = path( $tzil->root )->child('my_repo2');
                ok( $workdir->is_dir(),                'workspace is checked out' );
                ok( $workdir->child('.git')->is_dir(), '... with a .git directory' );
                ok( -f $workdir->child('A'),           '... with the correct file' );
                ok( !-e $workdir->child('B'),          '... only' );
                is( $workdir->child('A')->slurp, '7', '... with the correct content' );

                my $git    = Git::Repository->new( work_tree => $workdir->stringify );
                my @config = $git->run( 'config', '-l' );
                is( scalar grep( { m{ ^ \Qremote.origin.pushurl=\E }xsm } @config ), 0, '... no push url is defined' );

                is( ( scalar grep { $_ eq "[secondCheckout] Cloning $repo_path into $workdir" } @{ $tzil->log_messages() } ), 1, '... clone message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
                is( ( scalar grep { $_ eq "[secondCheckout] Checking out master in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
            }

            note('with dir and push_url');
            {
                my $workdir = path( $tzil->root )->child('my_repo3');
                ok( $workdir->is_dir(),                'workspace is checked out' );
                ok( $workdir->child('.git')->is_dir(), '... with a .git directory' );
                ok( -f $workdir->child('A'),           '... with the correct file' );
                ok( !-e $workdir->child('B'),          '... only' );
                is( $workdir->child('A')->slurp, '7', '... with the correct content' );

                my $git    = Git::Repository->new( work_tree => $workdir->stringify );
                my @config = $git->run( 'config', '-l' );
                is( scalar grep( { m{ ^ \Qremote.origin.pushurl=http://example.com/my_repo.git\E $ }xsm } @config ), 1, '... correct push url is defined' );

                is( ( scalar grep { $_ eq "[thirdCheckout] Cloning $repo_path into $workdir" } @{ $tzil->log_messages() } ), 1, '... clone message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
                is( ( scalar grep { $_ eq "[thirdCheckout] Checking out master in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
            }

            note('with dir, and checkout');
            {
                my $workdir = path( $tzil->root )->child('my_repo_dev');
                ok( $workdir->is_dir(),                'workspace is checked out' );
                ok( $workdir->child('.git')->is_dir(), '... with a .git directory' );
                ok( -f $workdir->child('A'),           '... with the correct file (A)' )
                  and is( $workdir->child('A')->slurp, '11', '... with the correct content' );
                ok( -f $workdir->child('B'), '... with the correct file (B)' )
                  and is( $workdir->child('B')->slurp, '13', '... with the correct content' );

                my $git    = Git::Repository->new( work_tree => $workdir->stringify );
                my @config = $git->run( 'config', '-l' );
                is( scalar grep( { m{ ^ \Qremote.origin.pushurl=\E }xsm } @config ), 0, '... no push url is defined' );

                is( ( scalar grep { $_ eq "[devBranchCheckout] Cloning $repo_path into $workdir" } @{ $tzil->log_messages() } ), 1, '... clone message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
                is( ( scalar grep { $_ eq "[devBranchCheckout] Checking out dev in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
            }

            note('with dir, checkout, and push_url');
            {
                my $workdir = path( $tzil->root )->child('my_repo_dev2');
                ok( $workdir->is_dir(),                'workspace is checked out' );
                ok( $workdir->child('.git')->is_dir(), '... with a .git directory' );
                ok( -f $workdir->child('A'),           '... with the correct file (A)' )
                  and is( $workdir->child('A')->slurp, '11', '... with the correct content' );
                ok( -f $workdir->child('B'), '... with the correct file (B)' )
                  and is( $workdir->child('B')->slurp, '13', '... with the correct content' );

                my $git    = Git::Repository->new( work_tree => $workdir->stringify );
                my @config = $git->run( 'config', '-l' );
                is( scalar grep( { m{ ^ \Qremote.origin.pushurl=http://example.com/my_dev_repo.git\E $ }xsm } @config ), 1, '... correct push url is defined' );

                is( ( scalar grep { $_ eq "[devBranchCheckout2] Cloning $repo_path into $workdir" } @{ $tzil->log_messages() } ), 1, '... clone message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
                is( ( scalar grep { $_ eq "[devBranchCheckout2] Checking out dev in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
            }
        }

        note('dir exists already');
        {
            my $exception = exception {
                Builder->from_config(
                    { dist_root => tempdir() },
                    {
                        add_files => {
                            'source/dist.ini' => simple_ini(
                                '=Local::CreateWorkspace',
                                [
                                    'Git::Checkout',
                                    {
                                        repo => $repo_path,
                                        dir  => 'ws',
                                    },
                                ],
                            ),
                        },
                    },
                );
            };

            like( $exception, qr{ \Q[Git::Checkout] Directory \E .*\Qws exists but is not a Git repository\E }xsm, 'throws an exception if the workspace directory exists already but is not a Git workspace' );
        }

        note('dir exists already but is not workspace for the correct repository');
        {
            my $exception = exception {
                Builder->from_config(
                    { dist_root => tempdir() },
                    {
                        add_files => {
                            'source/dist.ini' => simple_ini(
                                [
                                    'Git::Checkout',
                                    'wrongRepoCheckout',
                                    {
                                        repo => $repo_path2,
                                        dir  => 'ws',
                                    },
                                ],
                                [
                                    'Git::Checkout',
                                    {
                                        repo => $repo_path,
                                        dir  => 'ws',
                                    },
                                ],
                            ),
                        },
                    },
                );
            };

            like( $exception, qr{ \Q[Git::Checkout] Directory \E .*\Qws is not a Git repository for $repo_path\E }xsm, 'throws an exception if the workspace directory exists but is not a Git workspace for the correct repository' );
        }

        note('dirty dir');
        {
            my $tzil = Builder->from_config(
                { dist_root => tempdir() },
                {
                    add_files => {
                        'source/dist.ini' => simple_ini(
                            [
                                'Git::Checkout',
                                {
                                    repo => $repo_path,
                                    dir  => 'ws',
                                },
                            ],
                            '=Local::MakeWorkspaceDirty',
                            [
                                'Git::Checkout',
                                'secondCheckout',
                                {
                                    repo => $repo_path,
                                    dir  => 'ws',
                                },
                            ],
                        ),
                    },
                },
            );

            my $workdir = path( $tzil->root )->child('ws');
            ok( $workdir->is_dir(),                'workspace is checked out' );
            ok( $workdir->child('.git')->is_dir(), '... with a .git directory' );
            ok( -f $workdir->child('A'),           '... with the correct file (A)' )
              and is( $workdir->child('A')->slurp, '67', '... with the correct (dirty) content' );

            is( ( scalar grep { $_ =~ m{ ^\Q[secondCheckout] \E.*\QGit workspace $workdir is dirty - skipping checkout\E }xsm } @{ $tzil->log_messages() } ), 1, '... correct message is logged (is dirty)' )
              or diag 'got log messages: ', explain $tzil->log_messages;
            is( ( scalar grep { $_ eq "[secondCheckout] Fetching $repo_path in $workdir" } @{ $tzil->log_messages() } ), 0, '... _checkout stops when dirty' )
              or diag 'got log messages: ', explain $tzil->log_messages;
        }

        note('fetch');
        {
            my $tzil = Builder->from_config(
                { dist_root => tempdir() },
                {
                    add_files => {
                        'source/dist.ini' => simple_ini(
                            [
                                'Git::Checkout',
                                {
                                    repo     => $repo_path,
                                    dir      => 'ws',
                                    checkout => 'dev',
                                },
                            ],
                            [
                                'Git::Checkout',
                                'secondCheckout',
                                {
                                    repo => $repo_path,
                                    dir  => 'ws',
                                },
                            ],
                        ),
                    },
                },
            );

            my $workdir = path( $tzil->root )->child('ws');
            ok( $workdir->is_dir(),                'workspace is checked out' );
            ok( $workdir->child('.git')->is_dir(), '... with a .git directory' );
            ok( -f $workdir->child('A'),           '... with the correct file' )
              and is( $workdir->child('A')->slurp, '7', '... with the correct (dirty) content' );

            is( ( scalar grep { $_ eq "[Git::Checkout] Cloning $repo_path into $workdir" } @{ $tzil->log_messages() } ), 1, '... clone message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;
            is( ( scalar grep { $_ eq "[Git::Checkout] Checking out dev in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;

            is( ( scalar grep { $_ eq "[secondCheckout] Fetching $repo_path in $workdir" } @{ $tzil->log_messages() } ), 1, '... fetch message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;
            is( ( scalar grep { $_ eq "[secondCheckout] Checking out master in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;
        }

        note('push_url gets removed');
        {
            my $tzil = Builder->from_config(
                { dist_root => tempdir() },
                {
                    add_files => {
                        'source/dist.ini' => simple_ini(
                            [
                                'Git::Checkout',
                                {
                                    repo     => $repo_path,
                                    dir      => 'ws',
                                    push_url => 'http://example.com/my_repo.git',
                                },
                            ],
                            [
                                'Git::Checkout',
                                'secondCheckout',
                                {
                                    repo => $repo_path,
                                    dir  => 'ws',
                                },
                            ],
                        ),
                    },
                },
            );

            my $workdir = path( $tzil->root )->child('ws');
            ok( $workdir->is_dir(),                'workspace is checked out' );
            ok( $workdir->child('.git')->is_dir(), '... with a .git directory' );
            ok( -f $workdir->child('A'),           '... with the correct file' )
              and is( $workdir->child('A')->slurp, '7', '... with the correct (dirty) content' );

            my $git    = Git::Repository->new( work_tree => $workdir->stringify );
            my @config = $git->run( 'config', '-l' );
            is( scalar grep( { m{ ^ \Qremote.origin.pushurl=\E }xsm } @config ), 0, '... no push url is defined' );

            is( ( scalar grep { $_ eq "[Git::Checkout] Cloning $repo_path into $workdir" } @{ $tzil->log_messages() } ), 1, '... clone message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;
            is( ( scalar grep { $_ eq "[Git::Checkout] Checking out master in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;

            is( ( scalar grep { $_ eq "[secondCheckout] Fetching $repo_path in $workdir" } @{ $tzil->log_messages() } ), 1, '... fetch message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;
            is( ( scalar grep { $_ eq "[secondCheckout] Checking out master in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;
        }

        note('release is aborted if workspace is dirty');
        {
            my $tzil = Builder->from_config(
                { dist_root => tempdir() },
                {
                    add_files => {
                        'source/dist.ini' => simple_ini(
                            'FakeRelease',
                            [
                                'Git::Checkout',
                                {
                                    repo => $repo_path,
                                    dir  => 'ws',
                                },
                            ],
                            '=Local::MakeWorkspaceDirty',
                            [
                                'Git::Checkout',
                                'secondCheckout',
                                {
                                    repo => $repo_path,
                                    dir  => 'ws',
                                },
                            ],
                        ),
                    },
                },
            );

            my $workdir = path( $tzil->root )->child('ws');
            ok( $workdir->is_dir(),                'workspace is checked out' );
            ok( $workdir->child('.git')->is_dir(), '... with a .git directory' );
            ok( -f $workdir->child('A'),           '... with the correct file' )
              and is( $workdir->child('A')->slurp, '67', '... with the correct (dirty) content' );

            my $git    = Git::Repository->new( work_tree => $workdir->stringify );
            my @config = $git->run( 'config', '-l' );
            is( scalar grep( { m{ ^ \Qremote.origin.pushurl=\E }xsm } @config ), 0, '... no push url is defined' );

            is( ( scalar grep { $_ eq "[Git::Checkout] Cloning $repo_path into $workdir" } @{ $tzil->log_messages() } ), 1, '... clone message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;
            is( ( scalar grep { $_ eq "[Git::Checkout] Checking out master in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;

            is( ( scalar grep { $_ =~ m{ ^\Q[secondCheckout] \E.*\QGit workspace $workdir is dirty - skipping checkout\E }xsm } @{ $tzil->log_messages() } ), 1, '... correct message is logged (is dirty)' )
              or diag 'got log messages: ', explain $tzil->log_messages;

            like( exception { $tzil->release }, qr{ \QAborting release\E }xsm, '... release is aborted if dirty' )
              or diag 'got log messages: ', explain $tzil->log_messages;
        }

        note('release is not aborted if workspace is not dirty');
        {
            my $tzil = Builder->from_config(
                { dist_root => tempdir() },
                {
                    add_files => {
                        'source/dist.ini' => simple_ini(
                            'FakeRelease',
                            [
                                'Git::Checkout',
                                {
                                    repo => $repo_path,
                                    dir  => 'ws',
                                },
                            ],
                            [
                                'Git::Checkout',
                                'secondCheckout',
                                {
                                    repo => $repo_path,
                                    dir  => 'ws',
                                },
                            ],
                        ),
                    },
                },
            );

            my $workdir = path( $tzil->root )->child('ws');
            ok( $workdir->is_dir(),                'workspace is checked out' );
            ok( $workdir->child('.git')->is_dir(), '... with a .git directory' );
            ok( -f $workdir->child('A'),           '... with the correct file' )
              and is( $workdir->child('A')->slurp, '7', '... with the correct (dirty) content' );

            my $git    = Git::Repository->new( work_tree => $workdir->stringify );
            my @config = $git->run( 'config', '-l' );
            is( scalar grep( { m{ ^ \Qremote.origin.pushurl=\E }xsm } @config ), 0, '... no push url is defined' );

            is( ( scalar grep { $_ eq "[Git::Checkout] Cloning $repo_path into $workdir" } @{ $tzil->log_messages() } ), 1, '... clone message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;
            is( ( scalar grep { $_ eq "[Git::Checkout] Checking out master in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;

            is( ( scalar grep { $_ eq "[secondCheckout] Fetching $repo_path in $workdir" } @{ $tzil->log_messages() } ), 1, '... fetch message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;
            is( ( scalar grep { $_ eq "[secondCheckout] Checking out master in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
              or diag 'got log messages: ', explain $tzil->log_messages;

            # don't know how to test the prompt_yn stuff
            unlike( exception { $tzil->release }, qr{ \QAborting release\E }xsm, '... release is aborted if dirty' )
              or diag 'got log messages: ', explain $tzil->log_messages;
        }

        note('checkout branch and tag');
        {
            my $tzil = Builder->from_config(
                { dist_root => tempdir() },
                {
                    add_files => {
                        'source/dist.ini' => simple_ini(
                            [
                                'Git::Checkout',
                                'branchCheckout',
                                {
                                    repo => $repo_path,
                                },
                            ],
                            [
                                'Git::Checkout',
                                'tagCheckout',
                                {
                                    repo     => $repo_path,
                                    dir      => 'my_tag',
                                    checkout => 'my-tag',
                                },
                            ],
                            [
                                '=Local::UpdateRemote',
                                {
                                    repo => $repo_path,
                                },
                            ],

                            # branch master, 3 commits, A ->  7
                            # branch dev,    3 commits, A -> 11, B -> 13, C -> 1087
                            [
                                'Git::Checkout',
                                'branchUpdate',
                                {
                                    repo => $repo_path,
                                },
                            ],
                            [
                                'Git::Checkout',
                                'tagUpdate',
                                {
                                    repo     => $repo_path,
                                    dir      => 'my_tag',
                                    checkout => 'my-tag',
                                },
                            ],
                        ),
                    },
                },
            );

            skip "Test setup failed\n$Local::UpdateRemote::NOK", 1 if defined $Local::UpdateRemote::NOK;

            note(q{checkout and update branch 'master'});
            {
                my $workdir = path( $tzil->root )->child('my_repo');
                ok( $workdir->is_dir(),                'workspace is checked out' );
                ok( $workdir->child('.git')->is_dir(), '... with a .git directory' );
                ok( -f $workdir->child('A'),           '... with the correct file ...' );
                ok( !-e $workdir->child('B'),          '... only' );
                ok( -f $workdir->child('C'),           '... updated file exists' )
                  and is( $workdir->child('C')->slurp, '1087', '... with the correct content' );

                my $git    = Git::Repository->new( work_tree => $workdir->stringify );
                my @config = $git->run( 'config', '-l' );
                is( scalar grep( { m{ ^ \Qremote.origin.pushurl=\E }xsm } @config ), 0, '... no push url is defined' );

                is( ( scalar grep { $_ eq "[branchCheckout] Cloning $repo_path into $workdir" } @{ $tzil->log_messages() } ), 1, '... clone message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
                is( ( scalar grep { $_ eq "[branchCheckout] Checking out master in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
                is( ( scalar grep { $_ eq "[branchUpdate] Fetching $repo_path in $workdir" } @{ $tzil->log_messages() } ), 1, '... fetch message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
                is( ( scalar grep { $_ eq "[branchUpdate] Checking out master in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
            }

            note(q{checkout and update tag 'my-tag'});
            {
                my $workdir = path( $tzil->root )->child('my_tag');
                ok( $workdir->is_dir(),                'workspace is checked out' );
                ok( $workdir->child('.git')->is_dir(), '... with a .git directory' );
                ok( -f $workdir->child('A'),           '... with the correct file ...' );
                ok( !-e $workdir->child('B'),          '... only' );
                ok( -f $workdir->child('C'),           '... updated file exists' );
                is( $workdir->child('C')->slurp, '1087', '... with the correct content' );

                my $git    = Git::Repository->new( work_tree => $workdir->stringify );
                my @config = $git->run( 'config', '-l' );
                is( scalar grep( { m{ ^ \Qremote.origin.pushurl=\E }xsm } @config ), 0, '... no push url is defined' );

                is( ( scalar grep { $_ eq "[tagCheckout] Cloning $repo_path into $workdir" } @{ $tzil->log_messages() } ), 1, '... clone message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
                is( ( scalar grep { $_ eq "[tagCheckout] Checking out my-tag in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
                is( ( scalar grep { $_ eq "[tagUpdate] Fetching $repo_path in $workdir" } @{ $tzil->log_messages() } ), 1, '... clone message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
                is( ( scalar grep { $_ eq "[tagUpdate] Checking out my-tag in $workdir" } @{ $tzil->log_messages() } ), 1, '... checkout message got logged' )
                  or diag 'got log messages: ', explain $tzil->log_messages;
            }

        }

    }

    done_testing;

    return;
}

# vim: ts=4 sts=4 sw=4 et: syntax=perl
