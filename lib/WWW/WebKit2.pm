package WWW::WebKit2;

=head1 NAME

WWW::WebKit2 - Perl extension for controlling an embedding WebKit2 engine

=head1 SYNOPSIS

    use WWW::WebKit2;

    my $webkit = WWW::WebKit2->new(xvfb => 1);
    $webkit->init;

    $webkit->open("http://www.google.com");
    $webkit->type("q", "hello world");
    $webkit->click("btnG");
    $webkit->wait_for_page_to_load(5000);
    print $webkit->get_title;

=head1 DESCRIPTION

WWW::WebKit2 is a drop-in replacement for WWW::Selenium using Gtk3::WebKit2
as browser instead of relying on an external Java server and an installed browser.

=head2 EXPORT

None by default.

=cut

use 5.10.0;
use Moose;

with 'WWW::WebKit2::MouseInput';
with 'WWW::WebKit2::KeyboardInput';
with 'WWW::WebKit2::Events';
with 'WWW::WebKit2::Navigator';
with 'WWW::WebKit2::Inspector';
with 'WWW::WebKit2::Settings';

use lib 'lib';
use lib '/home/pl/lib/Gtk3-WebKit2/lib';
use Gtk3;
use Gtk3::WebKit2;
use Gtk3::JavaScriptCore;
use Glib qw(TRUE FALSE);
use Time::HiRes qw(time usleep);
use X11::Xlib;
use Carp qw(carp croak);
use XSLoader;
use English '-no_match_vars';
use POSIX qw<F_SETFD F_GETFD FD_CLOEXEC>;

our $VERSION = '0.1';

use constant DOM_TYPE_ELEMENT => 1;
use constant ORDERED_NODE_SNAPSHOT_TYPE => 7;

=head2 PROPERTIES

=cut

has xvfb => (
    is  => 'ro',
    isa => 'Bool',
);

has view => (
    is        => 'ro',
    isa       => 'Gtk3::WebKit2::WebView',
    lazy      => 1,
    clearer   => 'clear_view',
    predicate => 'has_view',
    default   => sub {

        my $ctx = Gtk3::WebKit2::WebContext::get_default();
        my $view = Gtk3::WebKit2::WebView->new_with_context($ctx);

        return $view;
    },
);

has scrolled_view => (
    is        => 'ro',
    isa       => 'Gtk3::ScrolledWindow',
    lazy      => 1,
    clearer   => 'clear_scrolled_view',
    predicate => 'has_scrolled_view',
    default   => sub {
        Gtk3::ScrolledWindow->new;
    }
);

has window_width => (
    is      => 'ro',
    isa     => 'Int',
    default => 1600,
);

has window_height => (
    is      => 'ro',
    isa     => 'Int',
    default => 1200,
);

has window => (
    is        => 'ro',
    isa       => 'Gtk3::Window',
    lazy      => 1,
    clearer   => 'clear_window',
    predicate => 'has_window',
    default   => sub {
        my ($self) = @_;
        my $sw = $self->scrolled_view;
        $sw->add($self->view);

        my $win = Gtk3::Window->new;
        $win->set_title($self->window_title);
        $win->set_default_size($self->window_width, $self->window_height);
        $win->add($sw);

        return $win;
    }
);

has window_title => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => sub {
        return 'www_webkit_window_' . int(rand() * 100000);
    },
);

has alerts => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has confirmations => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has prompt_answers => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has confirm_answers => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has accept_confirm => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

has display => (
    is        => 'ro',
    isa       => 'X11::Xlib',
    lazy      => 1,
    clearer   => 'clear_display',
    predicate => 'has_display',
    default   => sub {
        my $display = X11::Xlib->new;
        return $display;
    },
);

has event_send_delay => (
    is  => 'rw',
    isa => 'Int',
    default => 5, # ms
);

=head3 console_messages

WWW::WebKit saves console messages in this array but still lets the default console handler
handle the message. I'm not sure if this is the best way to go but you should be able
to override this easily:

    use Glib qw(TRUE FALSE);
    $webkit->view->signal_connect('console-message' => sub {
        push @{ $webkit->console_messages }, $_[1];
        return TRUE;
    });

The TRUE return value prevents any further handlers from kicking in which in turn should
prevent any messages from getting printed.

=cut

has console_messages => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has print_requests => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has default_timeout => (
    is      => 'rw',
    isa     => 'Int',
    default => 30_000,
);

has modifiers => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {control => 0, 'shift' => 0} },
);

has pending_requests => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

has load_status => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { '' },
);

=head2 METHODS

=head3 init

Initializes WebKit2 and GTK3. Must be called before any of the other methods.

=cut

sub init {
    my ($self) = @_;

    $self->setup_xvfb if $self->xvfb;

    return $self->init_webkit;
}

sub init_webkit {
    my ($self) = @_;

    # connect to X server to keep it alive till we don't need it anymore
    $self->display;
    Gtk3::init;

    $self->view->signal_connect('script-dialog' => sub {
        my ($dialog) = $_[1];
        my $message = $dialog->get_message;
        my $type = $dialog->get_dialog_type;
        if ($type eq 'confirm') {
            push @{ $self->confirmations }, $message;

            $dialog->confirm_set_confirmed(
                @{ $self->confirm_answers }
                    ? pop @{ $self->confirm_answers }
                    : ($self->accept_confirm ? TRUE : FALSE)
            );
        }
        if ($type eq 'alert') {
            push @{ $self->alerts }, $message;
        }

        if ($type eq 'prompt') {
            $dialog->prompt_set_text(pop @{ $self->prompt_answers });
        }

        return TRUE;
    });

    $self->view->signal_connect('print' => sub {
        push @{ $self->print_requests }, $_[1];
        return TRUE;
    });

    $self->view->signal_connect('resource-load-started' => sub {
        return $self->handle_resource_request(@_);
    });

    $self->view->signal_connect('load-changed' => sub {
        my ($view, $load_event) = @_;
        $self->load_status($load_event);
    });

    $self->enable_file_access_from_file_urls;

    $self->window->show_all;
    $self->process_events;

    return $self;
}

sub pending {
    my ($self) = @_;

    return scalar keys %{ $self->pending_requests };
}

sub process_events {
    my ($self) = @_;
    Gtk3::main_iteration while Gtk3::events_pending;
}

sub process_page_load {
    my ($self) = @_;

    Gtk3::main_iteration while Gtk3::events_pending or $self->is_loading;
}

sub is_loading {
    my ($self) = @_;

    return 1 if $self->view->is_loading;

    return 0;
}

sub handle_resource_request {
    my ($self, $view, $resource, $request) = @_;

    $self->pending_requests->{"$request"}++;

    $resource->signal_connect('received-data' => sub {
        delete $self->pending_requests->{"$request"};
    });
    $resource->signal_connect('failed' => sub {
        # If someone decides not to wait_for_pending_requests, this signal is received
        # during global destruction with $self being undefined.
        delete $self->pending_requests->{"$request"} if defined $self;
    });
}

sub setup_xvfb {
    my ($self) = @_;

    # close STDERR to avoid Xvfb's noise
    open my $stderr, '>&', \*STDERR or die "Can't dup STDERR: $!";
    close STDERR;

    if (system('Xvfb -help') != 0) {
        open STDERR, '>&', $stderr;
        die 'Could not start Xvfb';
    }

    # restore STDERR
    open STDERR, '>&', $stderr or die "Can't open STDERR: $!";;

    pipe my $read, my $write;
    my $writefd = fileno $write;

    # prevent pipe FD from being closed on exec when starting Xvfb:
    $SYSTEM_FD_MAX = $writefd;
    my $flags = fcntl $write, F_GETFD, 0;
    $flags &= ~FD_CLOEXEC;
    fcntl $write, F_SETFD, $flags;

    open STDERR, '>', '/dev/null' or die "Cant' open STDERR: $!";

    my $screen_dimensions = join 'x', $self->window_width, $self->window_height, 24;
    system ("Xvfb -nolisten tcp -terminate -screen 0 $screen_dimensions -displayfd $writefd &");

    open STDERR, '>&', $stderr or die "Can't open STDERR: $!";

    # Xvfb prints the display number newline terminated to our pipe
    my $display = <$read>;
    chomp $display;

    $ENV{DISPLAY} = ":$display";

    return;
}

sub uninit {
    my ($self) = @_;

    if ($self->has_view) {
        $self->scrolled_view->remove($self->view) if $self->has_scrolled_view and $self->scrolled_view and $self->view;
        $self->view->destroy if $self->view;
        $self->clear_view;
    }

    if ($self->has_scrolled_view) {
        $self->window->remove($self->scrolled_view) if $self->has_window and $self->window and $self->scrolled_view;
        $self->scrolled_view->destroy if $self->scrolled_view;
        $self->clear_scrolled_view;
    }

    if ($self->has_window) {
        $self->window->destroy if $self->window;
        $self->clear_window;
    }

    $self->clear_display;
}

sub DESTROY {
    my ($self) = @_;

    $self->uninit;
}

=head2 Implemented methods of the Selenium API

Please see L<WWW::Selenium> for the full documentation of these methods.


=cut

sub set_timeout {
    my ($self, $timeout) = @_;

    $self->default_timeout($timeout);
}

=head3 select($select, $option)

=cut

sub select {
    my ($self, $select, $option) = @_;

    my $document = $self->view->get_dom_document;
    $select = $self->resolve_locator($select, $document)          or return;
    $option = $self->resolve_locator($option, $document, $select) or return;

    my $options = $select->get_property('options');
    foreach my $i (0 .. $options->get_length) {
        my $current = $options->item($i);

        if ($current->is_same_node($option)) {
            $select->set_selected_index($i);

            my $changed = $document->create_event('Event');
            $changed->init_event('change', TRUE, TRUE);
            $select->dispatch_event($changed);

            $self->process_page_load;
            return 1;
        }
    }

    return;
}

=head3 click($locator)

=cut

sub click {
    my ($self, $locator) = @_;
    return $self->fire_mouse_event($locator, 'click');
}

=head3 check($locator)

=cut

sub check {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator);
    return $self->change_check($element, 1);

    return;
}

=head3 uncheck($locator)

=cut

sub uncheck {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator);
    return $self->change_check($element, undef);

    return;
}

sub change_check {
    my ($self, $element, $set_checked) = @_;

    my $document = $self->view->get_dom_document;

    unless ($set_checked) {
        $element->remove_attribute('checked');
    }
    else {
        $element->set_attribute('checked', 'checked');
    }

    my $changed = $document->create_event('Event');
    $changed->init_event('change', TRUE, TRUE);
    $element->dispatch_event($changed);

    $self->process_page_load;
    return 1;
}


=head3 type($locator, $text)

=cut

sub type {
    my ($self, $locator, $text) = @_;

    $self->resolve_locator($locator)->set_value($text);

    $self->process_page_load;

    return 1;
}

my %keycodes = (
    '\013' => 36,  # Carriage Return
    "\n"   => 36,  # Carriage Return
    '\9'   => 23,  # Tabulator
    "\t"   => 23,  # Tabulator
    '\027' => 9,   # Escape
    ' '    => 65,  # Space
    '\032' => 65,  # Space
    '\127' => 119, # Delete
    '\8'   => 22,  # Backspace
    '\044' => 59,  # Comma
    ','    => 59,  # Comma
    '\045' => 20,  # Hyphen
    '-'    => 20,  # Hyphen
    '\046' => 60,  # Dot
    '.'    => 60,  # Dot
);

sub key_press {
    my ($self, $locator, $key, $elem) = @_;
    my $display = X11::Xlib->new;

    my $keycode = exists $keycodes{$key} ? $keycodes{$key} : $display->XKeysymToKeycode(X11::Xlib::XStringToKeysym($key));

    $elem ||= $self->resolve_locator($locator) or return;
    $elem->focus;

    my $shift_keycode = 62;
    $display->XTestFakeKeyEvent($shift_keycode, 1, 1) if $self->modifiers->{'shift'};
    $display->XTestFakeKeyEvent($keycode, 1, 1);
    $display->XTestFakeKeyEvent($keycode, 0, 1);
    $display->XTestFakeKeyEvent($shift_keycode, 0, 1) if $self->modifiers->{'shift'};
    $display->XFlush;

    usleep 50000; # time for the X server to deliver the event

    # Unfortunately just does nothing:
    #Gtk3::test_widget_send_key($self->view, int($key), 'GDK_MODIFIER_MASK');

    $self->process_page_load;

    return 1;
}

=head3 type_keys($locator, $string)

=cut

sub type_keys {
    my ($self, $locator, $string) = @_;

    my $element = $self->resolve_locator($locator) or return;

    foreach (split //, $string) {
        $self->shift_key_down if $self->is_upper_case($_);
        $self->key_press($locator, $_, $element) or return;
        $self->shift_key_up if $self->is_upper_case($_);
    }

    return 1;
}

sub is_upper_case {
    my ($self, $char) = @_;

    return $char =~ /[A-Z]/;
}

sub control_key_down {
    my ($self) = @_;

    $self->modifiers->{control} = 1;
}

sub control_key_up {
    my ($self) = @_;

    $self->modifiers->{control} = 0;
}

sub shift_key_down {
    my ($self) = @_;

    $self->modifiers->{'shift'} = 1;
}

sub shift_key_up {
    my ($self) = @_;

    $self->modifiers->{'shift'} = 0;
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

=head3 is_ordered($first, $second)

=cut

sub is_ordered {
    my ($self, $first, $second) = @_;
    return $self->resolve_locator($first)->compare_document_position($self->resolve_locator($second)) == 4;
}


=head3 mouse_over($locator)

=cut

sub mouse_over {
    my ($self, $locator) = @_;
    return $self->fire_mouse_event($locator, 'mouseover');
}

=head3 mouse_down($locator)

=cut

sub mouse_down {
    my ($self, $locator) = @_;
    return $self->fire_mouse_event($locator, 'mousedown');
}

=head3 mouse_up($locator)

=cut

sub mouse_up {
    my ($self, $locator) = @_;
    return $self->fire_mouse_event($locator, 'mouseup');
}

=head3 fire_mouse_event($locator, $event_type)

=cut

sub fire_mouse_event {
    my ($self, $locator, $event_type) = @_;

    my $document = $self->view->get_dom_document;
    my $target = $self->resolve_locator($locator) or return;

    my $event = $document->create_event('MouseEvent');
    my ($x, $y) = $self->get_center_screen_position($locator);
    $event->init_mouse_event(
        $event_type, TRUE, TRUE, $document->get_property('default_view'), 1,
        $x, $y, $x, $y, $self->modifiers->{control} ? TRUE : FALSE,
        FALSE, FALSE, FALSE, 0, $target
    );
    $target->dispatch_event($event);

    $self->process_page_load;
    return 1;
}

=head3 get_value($locator)

=cut

sub get_value {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator);

    if (
        lc $element->get_node_name eq 'input'
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

=head3 submit($locator)

=cut

sub submit {
    my ($self, $locator) = @_;

    my $form = $self->resolve_locator($locator) or return;
    $form->submit;

    $self->process_page_load;

    return 1;
}

=head3 get_html_source()

Returns the source code of the current HTML page as it was transferred over the network.

Use $webkit->view->get_dom_document->get_document_element->get_outer_html to get the serialized
current DOM tree (with all modifications by Javascript)


=cut
#
# sub get_html_source {
#     my ($self) = @_;
#
#     my $data = $self->view->get_main_frame->get_data_source->get_data;
#     return $data->{str} if ref $data;
#     return $data;
# }

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

=head3 print_requested()

=cut

sub print_requested {
    my ($self) = @_;

    return pop @{ $self->print_requests } ? 1 : 0;
}

=head3 answer_on_next_confirm

=cut

sub answer_on_next_confirm {
    my ($self, $answer) = @_;

    push @{ $self->confirm_answers }, $answer;
}

=head3 answer_on_next_prompt($answer)

=cut

sub answer_on_next_prompt {
    my ($self, $answer) = @_;

    push @{ $self->prompt_answers }, $answer;
}


=head2 Additions to the Selenium API

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
    $self->press_mouse_button(1);
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

    my $target = $self->resolve_locator($target_locator)->get_length
        or croak "did not find element $target_locator";

    my $source = $self->resolve_locator($source_locator)->get_length
        or croak "did not find element $source_locator";

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

    $self->process_page_load;
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

1;

=head1 SEE ALSO

See L<WWW::Selenium> for API documentation.
See L<Test::WWW::WebKit> for a replacement for L<Test::WWW::Selenium>.
See L<Test::WWW::WebKit::Catalyst> for a replacement for L<Test::WWW::Selenium::Catalyst>.

The current development version can be found in the git repository at:
https://github.com/jscarty/WWW-WebKit2

=head1 AUTHOR

Stefan Seifert, E<lt>nine@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Stefan Seifert

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.3 or,
at your option, any later version of Perl 5 you may have available.

=cut
