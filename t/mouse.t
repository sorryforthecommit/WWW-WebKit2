use strict;
use warnings;
use utf8;

use Test::More;
use lib 'lib';
use FindBin qw($Bin $RealBin);
use lib "$Bin/../../Gtk3-WebKit2/lib";

use_ok 'WWW::WebKit2';

my $webkit = WWW::WebKit2->new(xvfb => 1);
eval { $webkit->init; };
if ($@ and $@ =~ /\ACould not start Xvfb/) {
    $webkit = WWW::WebKit2->new();
    $webkit->init;
}
elsif ($@) {
    diag($@);
    fail('init webkit');
}

$webkit->open("$Bin/test/mouse_input.html");

ok(1, 'opened');
my $select_value = $webkit->resolve_locator('.//select[@name="dropdown_list"]')->property_search('selectedOptions[0].value');
is($select_value, 'Please select', 'Current select value is Please Select');
$webkit->select('.//select[@name="dropdown_list"]', './/option[@value="testtwo"]');
my $updated_select_value = $webkit->resolve_locator('.//select[@name="dropdown_list"]')->property_search('selectedOptions[0].value');
is($updated_select_value, 'testtwo', 'Test Two is the new selected value');

$webkit->select('css=#body .form select[name="dropdown_list"]', 'label=Testone');

my $radio_value = $webkit->resolve_locator('.//input[@id="radiotest_one"]')->property_search('checked');
is($radio_value, '"false"', 'Radio value is currently false');
$webkit->check('.//input[@id="radiotest_one"]');
$radio_value = $webkit->resolve_locator('.//input[@id="radiotest_one"]')->property_search('checked');
is($radio_value, '"true"', 'Radio is set to true');

$webkit->uncheck('.//input[@id="radiotest_one"]');
$radio_value = $webkit->resolve_locator('.//input[@id="radiotest_one"]')->property_search('checked');
is($radio_value, '"false"', 'Radio is now set to false');

$webkit->mouse_over('.//li[@id="test_item_one"]');
my $mouse_over_result = $webkit->resolve_locator('.//li[@id="test_item_new"]');
is($mouse_over_result->get_attribute('value'),'value_added' , 'mouse over worked as expected');

$webkit->mouse_down('//div[@id="mouse_down_test"]');
my $mouse_down_result = $webkit->resolve_locator('.//div[@id="mouse_down_test"]');
is($mouse_down_result->get_attribute('value'), 'mouse_is_pressed_down', 'pressing the mouse down updates the value');

$webkit->mouse_up('//div[@id="mouse_up_test"]');
my $mouse_up_result = $webkit->resolve_locator('.//div[@id="mouse_up_test"]');
is($mouse_up_result->get_attribute('value'), 'mouse_has_been_released', 'Mouse released updated value.');

$webkit->click('.//div[@id="click_test"]');
is($webkit->get_alert, 'Test Alert', 'Alert was triggered after button click');

$webkit->click('.//div[@id="click_test_out_of_sight"]');
is($webkit->get_alert, 'Found me!', 'Found element to click on after scrolling');

done_testing;
