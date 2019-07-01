package WWW::WebKit2::Inspector;

use Carp qw(carp croak);
use Glib qw(TRUE FALSE);
use Moose::Role;
use JSON qw(decode_json encode_json);
use WWW::WebKit2::Locator;
use WWW::WebKit2::LocatorCSS;

sub run_javascript {
    my ($self, $javascript_string) = @_;

    my $done = 0;
    my $js_result = '';

    $self->view->run_javascript($javascript_string, undef, sub {
        my ($object, $result, $user_data) = @_;
        $done = 1;
        $js_result = $self->get_javascript_result($result);
    }, undef);

    Gtk3::main_iteration while Gtk3::events_pending or not $done;

    return $js_result;
}

sub get_javascript_result {
    my ($self, $result) = @_;

    my $value = $self->view->run_javascript_finish($result);
    my $js_value = $value->get_js_value;

    return undef if ($js_value->is_null or $js_value->is_undefined);

    return $js_value->to_string;
}

=head3 resolve_locator

=cut

sub resolve_locator {
    my ($self, $locator, $locator_parent) = @_;

    $locator =~ s/'/"/g;

    if (my ($css) = $locator =~ /^css=(.*)/) {
        return WWW::WebKit2::LocatorCSS->new({
            locator_string => $locator,
            inspector      => $self,
        });
    }

    return WWW::WebKit2::Locator->new({
        locator_string => $locator,
        locator_parent => $locator_parent,
        inspector      => $self,
    });
}

=head3 get_title

=cut

sub get_title {
    my ($self) = @_;

    my $value = $self->run_javascript('document.title');

    return $value;
}

=head3 get_body_text

=cut

sub get_body_text {
    my ($self) = @_;

    return $self->get_text('xpath=//body');
}

=head3 get_html_source

=cut

sub get_html_source {
    my ($self) = @_;

    my $html_source = $self->run_javascript("document.getElementsByTagName('html')[0].innerHTML");

    return $html_source;
}

=head3 get_text

=cut

sub get_text {
    my ($self, $locator) = @_;

    return $self->resolve_locator($locator)->get_text;
}

=head3 eval_js

=cut

sub eval_js {
    my ($self, $javascript_string) = @_;

    return $self->run_javascript($javascript_string);
}

=head3 get_xpath_count

=cut

sub get_xpath_count {
    my ($self, $xpath) = @_;

    return $self->resolve_locator($xpath)->get_length;
}

=head3 get_value($locator)

=cut

sub get_value {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator);

    if (
        lc $element->get_node_name eq 'input'
        and $element->get_property('type')
        and $element->get_property('type') =~ /\A(checkbox|radio)\z/
    ) {
        return $element->get_checked ? 'on' : 'off';
    }
    else {
        my $value = $element->get_value;
        $value =~ s/\A \s+ | \s+ \z//gxm;
        return $value;
    }
}

=head3 get_attribute($locator)

=cut

sub get_attribute {
    my ($self, $locator) = @_;
    ($locator, my $attr) = $locator =~ m!\A (.*?) /?@ ([^@]*) \z!xm;

    return $self->resolve_locator($locator)->get_attribute($attr);
}

=head2 get_screen_position

=cut

sub get_screen_position {
    my ($self, $locator) = @_;

    return $self->resolve_locator($locator)->get_screen_position;
}

=head2 get_center_screen_position

=cut

sub get_center_screen_position {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator);

    my ($x, $y) = $element->get_screen_position;

    $x += $element->get_offset_width / 2;
    $y += $element->get_offset_height / 2;

    return ($x, $y);
}

=head3 is_element_present($locator)

=cut

sub is_element_present {
    my ($self, $locator) = @_;

    my $result = eval { $self->resolve_locator($locator)->is_unique; };

    return $result;
}

=head3 is_visible($locator)

=cut

sub is_visible {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator);

    croak "element not found: $locator" unless $element->get_length;

    return $element->is_visible;
}

=head3 is_ordered($first, $second)

=cut

sub is_ordered {
    my ($self, $first, $second) = @_;

    my $first_element = $self->resolve_locator($first);
    my $second_element = $self->resolve_locator($second);

    my $javascript_string = $first_element->prepare_element .
        'var first_element = element;' .
        $second_element->prepare_element .
        'var second_element = element;' .
        'var position = first_element.compareDocumentPosition(second_element);' .
        '(position == 4) ? 1 : 0';

    return decode_json $self->run_javascript($javascript_string);
}

=head2 check_window_bounds

=cut

sub check_window_bounds {
    my ($self, $x, $y, $obj_description) = @_;

    my ($max_x, $max_y) = ($self->window_width, $self->window_height);
    if ($x > $max_x or $y > $max_y) {
        croak
            "$obj_description out of bounds (position: $x, $y - window bounds: $max_x x $max_y). "
            . "Raise window_width/window_height!"
    }

    return 1;
}

=head3 print_requested()

=cut

sub print_requested {
    my ($self) = @_;

    return pop @{ $self->print_requests } ? 1 : 0;
}

=head3 get_confirmation()

=cut

sub get_confirmation {
    my ($self) = @_;

    return pop @{ $self->confirmations };
}

=head3 get_alert()

=cut

sub get_alert {
    my ($self) = @_;

    return pop @{ $self->alerts };
}

1;
