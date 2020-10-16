package WWW::WebKit2::Settings;

use Carp qw(carp croak);
use Glib qw(TRUE FALSE);
use Moose::Role;

=head1 NAME

WWW::WebKit2::Settings - setting management methods for webkit2

=cut

=head1 DESCRIPTION

Small list of methods for accessing Webkit2s built in methods. The full list of settings is here
https://webkitgtk.org/reference/webkit2gtk/stable/WebKitSettings.html

To enable or disable settings that are not here you can do
$self->settings->SETTINGNAME(TRUE/FALSE)
to enable webkit_settings_set_enable_javascript you just provide

$self->settings->set_enable_javascript(TRUE)

To disable:

$self->settings->set_enable_javascript(FALSE)

To check the status of a setting
$self->settings->get_SETTINGNAME;
if it is active you will get a one if it is not you will get 0
webkit_settings_get_enable_javascript()
$self->settings->get_enable_javascript()

Please note that some settings like
- webkit_settings_set_hardware_acceleration_policy
have specific commands for changing their settings. Please check the Webkit2 documentation for the exact parameters

=cut

=head2 On by default

The settings below are turned on by default when webkit2->init is called.
- webkit_settings_set_enable_developer_extras
- webkit_settings_set_allow_file_access_from_file_urls
- webkit_settings_set_hardware_acceleration_policy

=cut


=head3 enable_file_access_from_file_urls

=cut

sub enable_file_access_from_file_urls {
    my ($self) = @_;

    my $settings = $self->settings;
    $settings->set_allow_file_access_from_file_urls(TRUE);
    $settings->set_allow_universal_access_from_file_urls(TRUE);
    return $self->save_settings($settings);
}

=head3 enable_console_log

=cut

sub enable_console_log {
    my ($self) = @_;

    my $settings = $self->settings;
    $settings->set_enable_write_console_messages_to_stdout(TRUE);
    return $self->save_settings($settings);
}

=head3 enable_developer_extras

=cut

sub enable_developer_extras {
    my ($self) = @_;

    my $settings = $self->settings;
    $settings->set_enable_developer_extras(TRUE);
    return $self->save_settings($settings);
}

=head3 enable_hardware_acceleration

=cut

sub enable_hardware_acceleration {
    my ($self) = @_;

    my $settings = $self->settings;
    $settings->set_hardware_acceleration_policy("WEBKIT_HARDWARE_ACCELERATION_POLICY_ALWAYS");
    return $self->save_settings($settings);
}

=head3 disable_plugins()

Disables WebKit plugins. Use this if you don't need plugins like Java and Flash
and want to for example silence plugin loading messages.

=cut

sub disable_plugins {
    my ($self) = @_;

    my $settings = $self->settings;
    $settings->set_enable_plugins(FALSE);
    return $self->save_settings($settings);
}

=head3 enable_plugins()

=cut

sub enable_plugins {
    my ($self) = @_;

    my $settings = $self->settings;
    $settings->set_enable_plugins(TRUE);
    return $self->save_settings($settings);
}

=head3 settings

=cut

sub settings {
    my ($self) = @_;

    return $self->view->get_settings;
}

=head3 save_settings

=cut

sub save_settings {
    my ($self, $settings) = @_;

    $self->view->set_settings($settings);
    return 1;
}

1;
