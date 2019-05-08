package WWW::WebKit2::Events;

use Moose::Role;
use Time::HiRes qw(time usleep);

=head3 set_timeout($timeout)

Set the default timeout to $timeout.

=cut

sub set_timeout {
    my ($self, $timeout) = @_;

    $self->default_timeout($timeout);
}

=head3 pause($time)

=cut

sub pause {
    my ($self, $time) = @_;

    my $expiry = time + $time / 1000;

    while (1) {
        $self->process_events;

        if (time < $expiry) {
            usleep 10000;
        }
        else {
            last;
        }
    }
}

=head3 wait_for_condition($condition, $timeout)

Wait for the given $condition sub to return a true value or $timeout to expire.
Returns the return value of $condition or 0 on timeout.

    $webkit->wait_for_condition(sub {
        $webkit->is_visible('id=foo');
    }, 10000);

=cut

sub wait_for_condition {
    my ($self, $condition, $timeout) = @_;

    $timeout ||= $self->default_timeout;

    my $expiry = time + $timeout / 1000;

    $self->process_events;

    my $result;
    until ($result = $condition->()) {
        $self->process_events;

        return 0 if time > $expiry;
        usleep 10000;
    }

    $self->process_events;

    return $result;
}

=head3 wait_for_element_present($locator, $timeout)

=cut

sub wait_for_element_present {
    my ($self, $locator, $timeout) = @_;

    return $self->wait_for_condition(sub {
        $self->is_element_present($locator)
    }, $timeout);
}

=head3 wait_for_element_to_disappear($locator, $timeout)

=cut

sub wait_for_element_to_disappear {
    my ($self, $locator, $timeout) = @_;

    return $self->wait_for_condition(sub {
        not $self->is_element_present($locator)
    }, $timeout);
}

=head3 wait_for_page_to_load($timeout)

=cut

sub wait_for_page_to_load {
    my ($self, $timeout) = @_;

    return $self->wait_for_condition(sub {
        $self->load_status eq 'ready_for_next_url' or
        $self->load_status eq 'finished';
    }, $timeout);
}

=head3 wait_for_pending_requests($timeout)

Waits for all pending requests to finish. This is most useful for AJAX applications,
since wait_for_page_to_load does not wait for AJAX requests.

=cut

sub wait_for_pending_requests {
    my ($self, $timeout) = @_;

    return $self->wait_for_condition(sub {
        $self->pending == 0;
    }, $timeout);
}

=head3 wait_for_alert($text, $timeout)

Wait for an alert with the given text to happen.
If $text is undef, it waits for any alert.
Since alerts do not get automatically cleared,
this has to be done manually before causing the action that is supposed to throw a new alert:

    $webkit->alerts([]);
    $webkit->click('...');
    $webkit->wait_for_alert;

=cut

sub wait_for_alert {
    my ($self, $text, $timeout) = @_;

    return $self->wait_for_condition(sub {
        defined $text
            ? (@{ $self->alerts } and $self->alerts->[-1] eq $text)
            : @{ $self->alerts };
    }, $timeout);
}

=head3 fire_event($locator, $event_type)

=cut

sub fire_event {
    my ($self, $locator, $event_type) = @_;

    my $target = $self->resolve_locator($locator);

    return unless $target->get_length;

    $target->fire_event($event_type);

    return 1;
}

1;
