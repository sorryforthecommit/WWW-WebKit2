package WWW::WebKit2::Locator;

use common::sense;
use JSON qw(decode_json encode_json);
use Moose;

has 'locator_string' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'locator_parent' => (
    is  => 'ro',
    isa => 'Maybe[WWW::WebKit2::Locator]',
);

has 'inspector' => (
    is       => 'ro',
    isa      => 'WWW::WebKit2',
    required => 1,
);

has 'resolved_locator' => (
    is       => 'ro',
    isa      => 'Str',
    default  => sub {
        my ($self) = @_;

        return $self->resolve_locator;
    }
);

=head2 get_text

=cut

sub get_text {
    my ($self) = @_;

    my $text = $self->property_search('textContent');
    $text =~ s/\A \s+ | \s+ \z//gxm;
    $text =~ s/\s+/ /gxms; # squeeze white space
    return $text;
}

=head2 get_inner_html

=cut

sub get_inner_html {
    my ($self) = @_;

    return $self->property_search('innerHTML');
}

=head2 set_inner_html

=cut

sub set_inner_html {
    my ($self, $value) = @_;

    return $self->property_search('innerHTML = "' . $value . '";');
}

=head2 get_tag_name

=cut

sub get_tag_name {
    my ($self) = @_;

    return $self->property_search('tagName');
}

=head2 get_id

=cut

sub get_id {
    my ($self) = @_;

    return $self->property_search('id');
}

=head2 get_node_name

=cut

sub get_node_name {
    my ($self) = @_;

    return $self->property_search('tagName');
}

=head2 get_attribute

=cut

sub get_attribute {
    my ($self, $attribute) = @_;

    my $value = $self->property_search("getAttribute('$attribute')");

    return $value;
}

=head2 set_attribute

=cut

sub set_attribute {
    my ($self, $attribute, $value) = @_;

    $value =~ s/'/\\'/gis;

    return $self->property_search("setAttribute('$attribute', '$value')");
}

=head2 remove_attribute

=cut

sub remove_attribute {
    my ($self, $attribute) = @_;

    return $self->property_search("removeAttribute('$attribute')");
}

=head2 get_property

=cut

sub get_property {
    my ($self, $property) = @_;

    return $self->get_attribute($property);
}

=head2 get_offset_width

=cut

sub get_offset_width {
    my ($self) = @_;

    return $self->property_search('offsetWidth');
}

=head2 get_offset_height

=cut

sub get_offset_height {
    my ($self) = @_;

    return $self->property_search('offsetHeight');
}

=head2 get_checked

=cut

sub get_checked {
    my ($self) = @_;

    return $self->get_attribute("checked");
}

=head2 get_value

=cut

sub get_value {
    my ($self) = @_;

    return $self->property_search('value');
}

=head2 set_value

=cut

sub set_value {
    my ($self, $value) = @_;

    return $self->property_search('value = "' . $value . '";');
}

=head2 is_unique

=cut

sub is_unique {
    my ($self) = @_;

    return defined $self->property_search('length');
}

=head2 get_length

=cut

sub get_length {
    my ($self) = @_;

    my $search = $self->prepare_elements_search('length');

    return $self->inspector->run_javascript($search);
}

=head2 scroll_into_view

=cut

sub scroll_into_view {
    my ($self) = @_;

    return $self->property_search('scrollIntoView()');
}

=head2 get_screen_position

=cut

sub get_screen_position {
    my ($self) = @_;

    my $search = $self->prepare_element .
        'var boundingrect = element.getBoundingClientRect();
         var element_top = boundingrect.top;
         var element_left = boundingrect.left;
         var win_left = window.screenLeft ? window.screenLeft : window.screenX;
         var win_top = window.screenTop ? window.screenTop : window.screenY;
         var result = { "y": element_top + win_top, "x": element_left + win_left };
         JSON.stringify(result)';

    my $result = decode_json $self->inspector->run_javascript($search);
    return ($result->{x}, $result->{y});
}

=head2 focus

=cut

sub focus {
    my ($self) = @_;

    return $self->property_search('focus()');
}

=head2 submit

=cut

sub submit {
    my ($self) = @_;

    $self->property_search('submit()');

    $self->inspector->wait_for_condition(sub {
        $self->inspector->load_status eq 'started'
    });

    $self->inspector->process_page_load;

    return 1;
}

=head2 fire_event

=cut

sub fire_event {
    my ($self, $event_type) = @_;

    my $fire_event = $self->prepare_element . '
        var event = new Event("' . $event_type . '");
        element.dispatchEvent(event);
    ';

    my $result = $self->inspector->run_javascript($fire_event);
    $self->inspector->pause(100);
    return $result;
}

=head2 is_visible

Taken from jQuery's codebase.
https://stackoverflow.com/questions/19669786/check-if-element-is-visible-in-dom

=cut

sub is_visible {
    my ($self, $attribute) = @_;

    my $search = $self->prepare_element;

    $search .= "
        function isVisible(e) {
            if (e == undefined) {
                return 0;
            }

            if(getComputedStyle(e).visibility === 'hidden') {
                return 0;
            }

            var visible = !!( e.offsetWidth || e.offsetHeight || e.getClientRects().length );
            return visible ? 1 : 0;
        }
        isVisible(element)
    ";

    return $self->inspector->run_javascript($search);
}

=head2 resolve_locator

=cut

sub resolve_locator {
    my ($self) = @_;

    my $locator = $self->locator_string;

    if (my ($label) = $locator =~ /^label=(.*)/) {
        return $label eq ''
            ? qq{.//*[not(text())]} : qq{.//*[text()="$label"]};
    }
    elsif (my ($link) = $locator =~ /^link=(.*)/) {
        return $link eq ''
            ? qq{.//a[not(descendant-or-self::text())]}
            : qq{.//a[descendant-or-self::text()="$link"]};
    }
    elsif (my ($value) = $locator =~ /^value=(.*)/) {
        return qq{.//*[\@value="$value"]};
    }
    elsif (my ($index) = $locator =~ /^index=(.*)/) {
        return qq{.//option[position()="$index"]};
    }
    elsif (my ($id) = $locator =~ /^id=(.*)/) {
        return qq{.//*[\@id="$id"]};
    }
    elsif (my ($class) = $locator =~ /^class=(.*)/) {
        return qq{.//*[contains(\@class, "$class")]};
    }
    elsif (my ($name) = $locator =~ /^name=(.*)/) {
        return qq{.//*[\@name="$name"]};
    }
    elsif (my ($xpath) = $locator =~ /^(?: xpath=)?(.*)/xm) {
        return $xpath;
    }
    elsif (my ($xpath_fallback) = $locator =~ /^(\/\/.*)/xm) {
        return $xpath_fallback;
    }

    return;
}

my $get_elements_function = q{
    function getElementsByXPath(xpath, parent) {
        let results = [];
        let query = document.evaluate(xpath, parent || document,
            null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);

        if (query.snapshotLength > 1) {
            throw('xpath returned more than 1 result: ' + xpath);
        }

        for (let i = 0, length = query.snapshotLength; i < length; ++i) {
            results.push(query.snapshotItem(i));
        }
        return results;
    };
};

=head2 prepare_element

=cut

sub prepare_element {
    my ($self, $element_name) = @_;

    $element_name //= 'element';

    my $locator = $self->resolved_locator;

    my ($parent, $parent_param) = ('', '');

    if ($self->locator_parent) {

        $parent = $self->locator_parent->prepare_element('parent');
        $parent_param = ", parent";
    }

    my $search = "
        $get_elements_function
        $parent
        var $element_name = getElementsByXPath('$locator'$parent_param);
        $element_name = $element_name" . "[0];
    ";

    return $search;
}

=head2 prepare_element_search

=cut

sub prepare_element_search {
    my ($self, $function) = @_;

    my $search = $self->prepare_element;
    $search .= "element.$function;";

    return $search;
}

=head2 prepare_elements

=cut

sub prepare_elements {
    my ($self) = @_;

    my $locator = $self->resolved_locator;

    my $search = "
        $get_elements_function
        var elements = getElementsByXPath('$locator');
    ";

    return $search;
}

=head2 prepare_elements_search

=cut

sub prepare_elements_search {
    my ($self, $function) = @_;

    my $search = $self->prepare_elements;
    $search .= "elements.$function;";

    return $search;
}

=head2 property_search

=cut

sub property_search {
    my ($self, $property) = @_;

    my $search = $self->prepare_element_search($property);

    return $self->inspector->run_javascript($search);
}

__PACKAGE__->meta->make_immutable;

1;
