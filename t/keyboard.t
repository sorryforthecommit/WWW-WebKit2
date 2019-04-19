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

type($locator, $text)
key_press($locator, $key, $elem)
type_keys($locator, $string)
is_upper_case($char)
control_key_down
control_key_up
shift_key_down
shift_key_up
answer_on_next_confirm($answer)
answer_on_next_prompt($answer)
delete_text($locator) (for contenteditable=true)

=cut

done_testing;
