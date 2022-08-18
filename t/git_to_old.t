#!/usr/bin/perl

# vim: ts=4 sts=4 sw=4 et: syntax=perl
#
# Copyright (c) 2020-2022 Sven Kirmess
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use 5.006;
use strict;
use warnings;

use Git::Background 0.003;
use Git::Version::Compare;
use Path::Tiny;
use Test::DZil;
use Test::Fatal;
use Test::MockModule 0.14;
use Test::More 0.88;

use lib path(__FILE__)->absolute->parent->child('lib')->stringify;

use Local::Test::TempDir qw(tempdir);

main();

sub main {
    note('Dist::Zilla::Plugin::Git::Checkout requires at least Git 1.7.10');
  SKIP:
    {
        skip 'Cannot find Git in PATH', 1 if !defined Git::Background->version;

        note('create Git test repository');
        my $repo_path = path( tempdir() )->child('my_repo.git')->absolute->stringify;
        {
            my $future = Git::Background->run( 'clone', '--bare', path(__FILE__)->absolute->parent(2)->child('corpus/test.bundle')->stringify(), $repo_path );
            $future->await;
            if ( $future->is_failed ) {
                my ($error) = $future->failure;
                skip "Cannot setup test repository: $error", 1;
            }
        }

        {
            my $mock = Test::MockModule->new('Git::Version::Compare');
            $mock->redefine( 'ge_git', sub { return; } );

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
                                        repo => $repo_path,
                                        dir  => 'ws',
                                    },
                                ],
                            ),
                        },
                    },
                );
            };

            like( $exception, qr{ \Q[Git::Checkout] Your 'git' is too old. At least Git 1.7.10 is needed.\E }xsm, q{throws an exception if Git is too old} );

            $mock->unmock('ge_git');
        }
    }

    done_testing;

    return;
}
