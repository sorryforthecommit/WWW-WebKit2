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

my $js = $sel->run_javascript('document.title');
is($js, 'test', 'document.title is test');

=head2

eval_js
code_for_locator
resolve_locator
get_xpath_count
get_text($locator)
get_body_text
get_title
get_value($locator)
get_attribute($locator)
get_html_source
get_confirmation
get_alert
is_visible($locator)
check_window_bounds
get_screen_position($element)
get_center_screen_position($element)
is_element_present($locator)
is_ordered($first, $second)
disable_plugins
print_requested

=cut

done_testing;
