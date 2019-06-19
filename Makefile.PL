use 5.010000;
use ExtUtils::MakeMaker;
use ExtUtils::PkgConfig;
use Glib::MakeHelper;
use ExtUtils::Depends;

my %pkg_info = ExtUtils::PkgConfig->find('gdk-3.0');
my %gtk_info = ExtUtils::PkgConfig->find('gtk+-3.0');

my @xs_files = qw(WebKit.xs);
my %pm_files = (
#  'XSHelper.pm' => '$(INST_LIBDIR)/XSHelper.pm',
);

my $deps = ExtUtils::Depends->new ('WWW::WebKit2' => 'Glib');
$deps->set_inc ($pkg_info{cflags}, $gtk_info{cflags});
$deps->set_libs ($pkg_info{libs}, $gtk_info{libs});
$deps->add_pm (%pm_files);
$deps->add_xs (@xs_files);
#$deps->save_config ('build/IFiles.pm');

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'WWW::WebKit2',
    VERSION_FROM      => 'lib/WWW/WebKit2.pm', # finds $VERSION
    LICENSE           => 'perl',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
        'ExtUtils::PkgConfig' => 0,
        'ExtUtils::Depends' => 0,
        'Glib::MakeHelper' => 0,
    },
    BUILD_REQUIRES => {
        'URI' => 0,
        'Test::More' => 0.88,
    },
    PREREQ_PM         => {
        'Gtk3'                 => 0,
        'Gtk3::WebKit2'        => 0.02,
        'Gtk3::JavaScriptCore' => 0,
        Glib                   => 1.329,
        Moose                  => 2.2011,
        'Moose::Role'          => 2.2011,
        'Time::HiRes'          => 1.9760,
        'X11::Xlib'            => 0.18,
        Carp                   => 1.50,
        constant               => 1.33,
        'File::Sluper'         => 0.012,

    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/WWW/WebKit2.pm', # retrieve abstract from module
       AUTHOR         => 'Jason Carty <jc@blueyonder.co.uk>') : ()),
    LIBS              => [ExtUtils::PkgConfig->libs_only_L('gdk-3.0')], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => $pkg_info{cflags},
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
    $deps->get_makefile_vars,
);
