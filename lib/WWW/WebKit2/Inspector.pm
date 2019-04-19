package WWW::WebKit2::Inspector;

use Moose::Role;
use JSON qw(encode_json);

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

sub run_javascript {
    my ($self, $javascript_string) = @_;

    my $done = 0;
    my $js_result = '';

    $self->view->run_javascript($javascript_string, undef, sub {
        my ($object, $result, $user_data) = @_;
        $done = 1;
        $js_result = $self->get_json_from_javascript_result($result);
    }, undef);

    Gtk3::main_iteration while Gtk3::events_pending or not $done;

    return $js_result;
}

sub get_json_from_javascript_result {
    my ($self, $result) = @_;

    my $value = $self->view->run_javascript_finish($result);
    my $js_value = $value->get_js_value;

    return $js_value->to_string if $js_value->is_string;

    my $json = JSON->new;
    $json = encode_json($js_value->to_string);

    use Data::Printer;
    p $json;

    return $json;
}

1;

