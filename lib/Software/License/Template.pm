package Software::License::Template;

# ABSTRACT: light handler for Software::License templates

use strict;
use warnings;
use Carp;
use File::Spec::Functions qw< splitpath catpath >;

sub new {
   my $package = shift;
   my %opts = @_ && ref($_[0]) ? %{$_[0]} : @_;

   # Text::Template expansion of templates delimited by {{{{ }}}}
   # is triggered by default, you can pass expand => 0 to avoid
   # this and avoid require-ing Text::Template as well
   my $self = bless { expand => 1 }, $package;
   $self->{expand} = $opts{expand} if exists $opts{expand};

   return bless $self, $package;
}

sub load_file {
   my ($self, $filename) = @_;

   # Sections are kept inside a hash
   my %section_for;

   my $current_section = '';
   my $current_prefix = '';
   open my $fh, '<', $filename
      or croak "open('$filename'): $!";
   while (<$fh>) {
      if (my ($section, $prefix) = m{\A __ (.*) __ (?: >(.*)<)? \n\z}mxs) {
         ($current_section = lc $section) =~ s/\W+//gmxs;
         $current_prefix = defined $prefix ? $prefix : '';
      }
      else {
         my $line = $_;
         # Remove prefix only if present
         substr $line, 0, length($current_prefix), ''
            if index($line, $current_prefix) == 0;
         $section_for{$current_section} .= $line;
      }
   }
   close $fh;

   # strip last newline from all items
   for my $chunk (values %section_for) {
      $chunk =~ s{\n\z}{}mxs;
      if ($self->{expand}) {
         require Text::Template;
         $chunk = Text::Template->new(TYPE => 'STRING', SOURCE => $chunk,
            DELIMITERS => [qw< {{{{ }}}} >])->fill_in(HASH => { self => \$self });
      }
   }

   return %section_for if wantarray();
   return \%section_for;
}

sub license_directory {
   my ($self) = @_;
   (my $packfile = ref($self) . '.pm') =~ s{::}{/}g;
   (my $basedir = $INC{$packfile}) =~ s/\.pm$//mxs;
   return $basedir;
}

sub license_path {
   my ($self, $license) = @_;
   my ($volume, $directories)
      = splitpath($self->license_directory(), 'no-file');
   return catpath($volume, $directories, $license);
}

sub load_license {
   my ($self, $license) = @_;
   my $path = $self->license_path($license);
   croak "cannot find template for license '$license' at '$path'"
      unless -r $path;
   return $self->load_file($path);
}

sub available_licenses {
   my $self = shift;
   my %opts = @_ && ref($_[0]) ? %{$_[0]} : @_;
   my $dir = $self->license_directory();
   opendir my $dh, $dir
      or croak "cannot opendir('$dir'): $!";

   my ($volume, $directories) = splitpath($dir, 'no-file');
   my %data_for;
   for my $candidate (readdir $dh) {
      my $path = catpath($volume, $directories, $candidate);
      next if -d $path || ! -r $path;
      $data_for{$candidate} = $opts{load} ? $self->load_file($path) : $path;
   }
   closedir $dh;

   return %data_for if wantarray();
   return \%data_for;
}

1;
__END__
