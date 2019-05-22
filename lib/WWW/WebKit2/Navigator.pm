package WWW::WebKit2::Navigator;

use Moose::Role;
use File::Slurper 'read_text';

=head3 open($url)

=cut

sub open {
    my ($self, $url) = @_;

    if ($url =~ /^http:/ or $url =~ /^file:/) {
        $self->view->load_uri($url);
    }
    else {
        $self->view->load_html(read_text($url), $url);
    }

    $self->process_page_load;
}

=head3 refresh()

=cut

sub refresh {
    my ($self) = @_;

    $self->view->reload;
    $self->process_page_load;
}

=head3 go_back()

=cut

sub go_back {
    my ($self) = @_;

    $self->view->go_back;
    $self->process_page_load;
}

=head3 submit($locator)

=cut

sub submit {
    my ($self, $locator) = @_;

    my $form = $self->resolve_locator($locator) or return;

    $form->submit;

    return 1;
}

1;
