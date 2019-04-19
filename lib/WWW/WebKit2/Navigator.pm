package WWW::WebKit2::Navigator;

use Moose::Role;
use File::Slurper 'read_text';

=head2
set_timeout($timeout)
open($url)
refresh
go_back
pause($time)
submit($locator)
=cut


=head3 open($url)

=cut

sub open {
    my ($self, $url) = @_;

    warn $url;

    if ($url =~ /http/) {
        warn " LOADED URL ";
        $self->view->load_uri($url);
    }
    else {
        warn " LOADED FILE ";
        $self->view->load_html(read_text($url), $url);
    }

    $self->process_page_load;

    warn " PROCESSED PAGE LOAD ";
}

1;

