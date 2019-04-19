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

select($select, $option)
check($locator)
uncheck($locator)
change_check($element, $set_checked)
click($locator)
mouse_over($locator)
mouse_up($locator)
fire_mouse_event($locator, $event_type)
native_drag_and_drop_to_position($source_locator, $target_x, $target_y, $options)
native_drag_and_drop_to_object($source_locator, $target_locator, $options)
move_mouse_abs
press_mouse_button
release_mouse_button

=cut

done_testing;
