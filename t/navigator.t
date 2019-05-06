use strict;
use warnings;
use utf8;

use Test::More;
use lib 'lib';
use lib '/home/pl/lib';
use FindBin qw($Bin $RealBin);
use lib "$Bin/../../Gtk3-WebKit2/lib";
use URI;

use_ok 'WWW::WebKit2';

my $sel = WWW::WebKit2->new(xvfb => 0);
eval { $sel->init; };
if ($@ and $@ =~ /\ACould not start Xvfb/) {
    $sel = WWW::WebKit2->new();
    $sel->init;
}
elsif ($@) {
    diag($@);
    fail('init webkit');
}

$sel->open("$Bin/test/load.html");
ok(1, 'opened');
$sel->refresh;
$sel->open("$Bin/test/type.html");
$sel->go_back;

# submitting leads to a "URL can't be shown" error, but technically it works.
$sel->open("$Bin/test/type.html");
$sel->submit('css=form');

done_testing;
