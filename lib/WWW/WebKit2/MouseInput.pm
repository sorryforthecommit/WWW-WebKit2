package WWW::WebKit2::MouseInput;

use Moose::Role;

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

1;

