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

my $sel = WWW::WebKit2->new(xvfb => 1);
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

=head2

pause($time)
set_timeout
fire_event($locator)
wait_for_page_to_load
wait_for_element_present
wait_for_pending_requests($timeout)
wait_for_element_to_disappear($locator, $timeout)
wait_for_alert($text, $timeout)
wait_for_condition($condition, $timeout)

=cut

done_testing;
