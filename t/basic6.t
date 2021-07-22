#!/usr/bin/perl

use 5.006;
use strict;
use warnings;

use Git::Wrapper;
use Path::Tiny;
use Test::DZil;
use Test::Fatal;
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

            my $file_A = $repo_path->child('A');
            my $file_B = $repo_path->child('B');
            $file_A->spew('5');
            $git->add('A');
            $git->commit( { message => 'initial commit' } );

            $file_A->spew('7');
            $git->add('A');
            $git->commit( { message => 'second commit' } );

            $git->branch('dev');
            $git->checkout('dev');

            $file_A->spew('11');
            $git->add('A');
            $file_B->spew('13');
            $git->add('B');
            $git->commit( { message => 'commit on dev branch' } );

            $git->checkout('master');
        }

        note('checkout branch and tag');
        {
            my $git = Git::Wrapper->new( $repo_path->stringify );
            $git->tag('my-tag');

            my $ws = tempdir();

            print STDERR __LINE__;
            my $git2 = Git::Wrapper->new( $ws );
            print STDERR __LINE__;
            $git2->clone( $repo_path->stringify(), $ws );
            print STDERR __LINE__;

            print STDERR __LINE__;
            my ($push_url) = eval { $git2->config('remote.origin.pushurl'); };
            print STDERR __LINE__;
            $git2->checkout('my-tag');
            print STDERR __LINE__;

#            print STDERR "repo_path: $repo_path\n";
#            my $t = tempdir();
#            print STDERR "t: $t\n";
#
#            my $tzil = Builder->from_config(
#                { dist_root => $t },
#                {
#                    add_files => {
#                        'source/dist.ini' => simple_ini(
#                            [
#                                'Git::Checkout',
#                                'tagCheckout',
#                                {
#                                    repo     => $repo_path->stringify(),
#                                    dir      => 'my_tag',
#                                    checkout => 'my-tag',
#                                },
#                            ],
#                        ),
#                    },
#                },
#            );


        }

    done_testing;

    return;
}

# vim: ts=4 sts=4 sw=4 et: syntax=perl
