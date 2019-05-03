package WWW::WebKit2::LocatorCSS;

use common::sense;
use Moose;
use base 'WWW::WebKit2::Locator';

=head2 resolve_locator

=cut

sub resolve_locator {
    my ($self) = @_;

    my $locator = $self->locator_string;

    if (my ($css) = $locator =~ /^css=(.*)/) {
        return $css;
    }

    return $locator;
}

=head2 prepare_element

=cut

sub prepare_element {
    my ($self) = @_;

    my $locator = $self->resolved_locator;

    my $search = "var element = document.querySelector('$locator');";

    return $search;
}

=head2 prepare_elements

=cut

sub prepare_elements {
    my ($self) = @_;

    my $locator = $self->resolved_locator;

    my $search = "var elements = document.querySelectorAll('$locator');";

    return $search;
}

=head2 prepare_elements_search

=cut

sub prepare_elements_search {
    my ($self, $function) = @_;

    my $locator = $self->resolved_locator;

    my $search = "document.querySelectorAll('$locator').$function;";

    return $search;
}

__PACKAGE__->meta->make_immutable;

1;
