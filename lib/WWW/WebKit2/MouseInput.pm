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


sub select {
    my ($self, $select, $option) = @_;

    my $select_dummy = $select;
    $select = $self->resolve_locator($select) or return;

    $option = $self->resolve_locator($option) or return;
    my $option_value = $option->get_value;
        warn '=====';
    my $set_select =
        $select->prepare_element .
        'var select_element = element;
        var option_element = ' . "'$option_value'" .
        ';
        select_element.value = option_element;
    ';
    warn $set_select;
    $self->run_javascript($set_select);
    warn $select->get_value;
    $select_dummy = $self->resolve_locator($select_dummy);
    warn $select_dummy->get_value;
    $self->pause(20000);
    warn $self->get_html_source;

}
1;

