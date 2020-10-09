use strict;
use warnings;
use utf8;

use Test::More;
use lib 'lib';
use FindBin qw($Bin $RealBin);
use lib "$Bin/../../Gtk3-WebKit2/lib";
use URI;
use WWW::WebKit2;

#Running tests as root will sometimes spawn an X11 that cannot be closed automatically and leave the test hanging
plan skip_all => 'Tests run as root may hang due to X11 server not closing.' unless $>;

my $wkit = WWW::WebKit2->new(xvfb => 1);
$wkit->init;

$wkit->open("$Bin/test/iframe.html");
ok(1, 'opened');

done_testing;
