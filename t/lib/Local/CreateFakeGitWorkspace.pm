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

package Local::CreateFakeGitWorkspace;

our $VERSION = '0.001';

use Moose;
use namespace::autoclean;

with 'Dist::Zilla::Role::Plugin';

use Path::Tiny;

around plugin_from_config => sub {
    my $orig         = shift @_;
    my $plugin_class = shift @_;

    my $instance = $plugin_class->$orig(@_);

    path( $instance->zilla->root )->child('ws/.git')->mkpath;

    return $instance;
};

__PACKAGE__->meta->make_immutable;

1;

__END__
