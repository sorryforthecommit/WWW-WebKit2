package WWW::WebKit2::KeyboardInput;

use Moose::Role;

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

1;

