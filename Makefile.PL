use 5.006;
use strict;
use warnings;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "clone and checkout a Git repository",
  "AUTHOR" => "Sven Kirmess <sven.kirmess\@kzone.ch>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Dist-Zilla-Plugin-Git-Checkout",
  "LICENSE" => "open_source",
  "MIN_PERL_VERSION" => "5.006",
  "NAME" => "Dist::Zilla::Plugin::Git::Checkout",
  "PREREQ_PM" => {
    "Dist::Zilla::Role::BeforeRelease" => 0,
    "Git::Wrapper" => 0,
    "Moose" => 0,
    "MooseX::Types::Moose" => 0,
    "Path::Tiny" => 0,
    "Term::ANSIColor" => 0,
    "namespace::autoclean" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Dist::Zilla::Role::Plugin" => 0,
    "Test::DZil" => 0,
    "Test::Fatal" => 0,
    "Test::MockModule" => 0,
    "Test::More" => "0.88",
    "Test::TempDir::Tiny" => 0,
    "lib" => 0
  },
  "VERSION" => "0.003",
  "test" => {
    "TESTS" => "t/*.t"
  }
);

my %FallbackPrereqs = (
  "Dist::Zilla::Role::BeforeRelease" => 0,
  "Dist::Zilla::Role::Plugin" => 0,
  "Git::Wrapper" => 0,
  "Moose" => 0,
  "MooseX::Types::Moose" => 0,
  "Path::Tiny" => 0,
  "Term::ANSIColor" => 0,
  "Test::DZil" => 0,
  "Test::Fatal" => 0,
  "Test::MockModule" => 0,
  "Test::More" => "0.88",
  "Test::TempDir::Tiny" => 0,
  "lib" => 0,
  "namespace::autoclean" => 0,
  "strict" => 0,
  "warnings" => 0
);

unless ( eval { ExtUtils::MakeMaker->VERSION('6.63_03') } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
