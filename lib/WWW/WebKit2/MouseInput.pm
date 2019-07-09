package WWW::WebKit2::MouseInput;

use Moose::Role;
use Carp qw(carp croak);

has event_send_delay => (
    is  => 'rw',
    isa => 'Int',
    default => 5, # ms
);

sub select {
    my ($self, $select, $option) = @_;

    $select = $self->resolve_locator($select) or return;
    $option = $self->resolve_locator($option, $select) or return;

    my $option_value = $option->get_value;
    my $set_select =
        $select->prepare_element .
        'var options = element.options;
        for (var i = 0; i < options.length; i++) {
            if (options[i].value === ' . "'$option_value'" . ' ) {
                options[i].selected = true;
                break;
            }
        }
    ';

    $self->run_javascript($set_select);

    $select->fire_event('change');

    $self->process_page_load;

    $self->wait_for_condition(sub {
       return $select->get_value eq $option_value;
    });

    return 1;
}

sub change_check {
    my ($self, $element, $set_checked) = @_;

    if ($set_checked) {
        $element->set_attribute('checked', 'checked');
    }
    else {
        $element->remove_attribute('checked');
    }
    $element->fire_event('change');

    return 1;
}

=head3 check($locator)

=cut

sub check {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator);
    return $self->change_check($element, 'true');
}

=head3 uncheck($locator)

=cut

sub uncheck {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator);
    return $self->change_check($element, undef);
}

sub click {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator);

    die "Element doesn't exist: " . $locator unless $element->get_length;

    $element->property_search('style.border ="2px solid red"');
    $element->property_search('style.background ="green"');
    $element->scroll_into_view;

    unless ($element->is_visible) {
        die "ELEMENT IS NOT VISIBLE: " . $locator;
    }

    my ($x, $y) = $self->get_center_screen_position($locator);
    $self->move_mouse_abs($x, $y);
    $self->left_click;

    $self->process_page_load;

    return 1;
}

sub left_click {
    my ($self) = @_;

    $self->clear_events;
    $self->press_mouse_button(1);
    $self->wait_for_mouse_click_event;
    $self->pause(100);

    $self->clear_events;
    $self->release_mouse_button(1);
    $self->wait_for_mouse_click_event;
    $self->pause(100);

    return 1;
}

sub wait_for_mouse_motion_event {
    my ($self) = @_;

    $self->wait_for_condition(sub {
        $self->find_event(sub {
            my $event_type = scalar $_;
            return $event_type =~ /EventMotion/;
        });
    });
}

sub wait_for_mouse_click_event {
    my ($self) = @_;

    $self->wait_for_condition(sub {
        $self->find_event(sub {
            my $event_type = scalar $_;
            return $event_type =~ /EventButton/;
        });
    });
}

sub mouse_over {
    my ($self, $locator) = @_;

    my $mouse_over = $self->resolve_locator($locator);

    return $self->fire_mouse_event($mouse_over, 'mouseover');
}

=head3 mouse_down($locator)

=cut

sub mouse_down {
    my ($self, $locator) = @_;

    my $mouse_down = $self->resolve_locator($locator);

    return $self->fire_mouse_event($mouse_down, 'mousedown');
}

=head3 mouse_up($locator)

=cut

sub mouse_up {
    my ($self, $locator) = @_;

    my $mouse_up = $self->resolve_locator($locator);

    return $self->fire_mouse_event($mouse_up, 'mouseup');
}

sub fire_mouse_event {
    my ($self, $element, $event) = @_;

    my $mouse_up_script = $element->prepare_element .
        " var clickEvent = document.createEvent('MouseEvents');
        clickEvent.initMouseEvent ('$event', true, true);
        element.dispatchEvent(clickEvent);
    ";
    $self->run_javascript($mouse_up_script);
}

sub move_mouse_abs {
    my ($self, $x, $y) = @_;

    $self->display->XTestFakeMotionEvent(0, $x, $y, $self->event_send_delay);
    $self->display->XFlush;
}

sub press_mouse_button {
    my ($self, $button) = @_;

    $self->display->XTestFakeButtonEvent($button, 1, $self->event_send_delay);
    $self->display->XFlush;
}

sub release_mouse_button {
    my ($self, $button) = @_;

    $self->display->XTestFakeButtonEvent($button, 0, $self->event_send_delay);
    $self->display->XFlush;
}

=head3 native_drag_and_drop_to_position($source_locator, $target_x, $target_y, $options)

Drag source element and drop it to position $target_x, $target_y.

=cut

sub native_drag_and_drop_to_position {
    my ($self, $source_locator, $target_x, $target_y, $options) = @_;
    $self->check_window_bounds($target_x, $target_y, "target");

    my $steps = $options->{steps} // 5;
    my $step_delay =  $options->{step_delay} // 150; # ms
    $self->event_send_delay($options->{event_send_delay}) if $options->{event_send_delay};

    my ($source_x, $source_y) = $self->get_center_screen_position($source_locator);
    $self->check_window_bounds($source_x, $source_y, "source '$source_locator'");

    my ($delta_x, $delta_y) = ($target_x - $source_x, $target_y - $source_y);
    my ($step_x, $step_y) = (int($delta_x / $steps), int($delta_y / $steps));
    my ($x, $y) = ($source_x, $source_y);

    $self->move_mouse_abs($source_x, $source_y);
    $self->pause($step_delay);
    $self->clear_events;
    $self->press_mouse_button(1);
    $self->wait_for_mouse_click_event;
    $self->pause($step_delay);

    foreach (1..$steps) {
        $self->move_mouse_abs($x += $step_x, $y += $step_y);
        $self->pause($step_delay);
    }

    $self->move_mouse_abs($target_x, $target_y);
    $self->pause($step_delay);
    $self->release_mouse_button(1);
    $self->pause($step_delay);
    $self->move_mouse_abs($target_x, $target_y);
    $self->pause($step_delay);

    $self->process_page_load;
}


=head3 native_drag_and_drop_to_object($source_locator, $target_locator, $options)

Drag source element and drop it into target element.

=cut

sub native_drag_and_drop_to_object {
    my ($self, $source_locator, $target_locator, $options) = @_;

    my $steps = $options->{steps} // 5;
    my $step_delay =  $options->{step_delay} // 150; # ms
    $self->event_send_delay($options->{event_send_delay}) if $options->{event_send_delay};

    my ($x, $y) = $self->get_center_screen_position($source_locator);
    $self->check_window_bounds($x, $y, "source '$source_locator'");

    $self->pause($step_delay);
    $self->move_mouse_abs($x, $y);
    $self->pause($step_delay);
    $self->press_mouse_button(1);
    $self->pause($step_delay);

    my ($target_x, $target_y) = $self->get_center_screen_position($target_locator);
    $self->check_window_bounds($target_x, $target_y, "target '$target_locator'");

    foreach (0 .. $steps - 1) {
        my $delta_x = $target_x - $x;
        my $delta_y = $target_y - $y;
        my $step_x = int($delta_x / ($steps - $_));
        my $step_y = int($delta_y / ($steps - $_));


        $self->move_mouse_abs($x += $step_x, $y += $step_y);
        $self->pause($step_delay);
    }

    # "move" mouse again to cause a dragover event on the target
    # otherwise a drop may not work
    $self->move_mouse_abs($x, $y);
    $self->pause($step_delay);

    $self->release_mouse_button(1);
    $self->pause($step_delay);
    $self->move_mouse_abs($x, $y);
    $self->pause($step_delay);
    $self->is_loading;

}

1;
