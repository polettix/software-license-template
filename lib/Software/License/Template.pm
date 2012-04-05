package Software::License::Template;

# ABSTRACT: light handler for Software::License templates

use strict;
use warnings;
use Carp;
use Exporter qw< import>;
use File::Spec::Functions qw< splitpath catpath >;

our @EXPORT_OK = qw<
   load_file
   load_license
>;

sub load_file {
   my ($filename) = @_;

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
   s{\n\z}{}mxs for values %section_for;

   return %section_for if wantarray();
   return \%section_for;
}

sub license_directory {
   (my $packfile = __PACKAGE__ . '.pm') =~ s{::}{/}g;
   (my $basedir = $INC{$packfile}) =~ s/\.pm$//mxs;
   return $basedir;
}

sub license_path {
   my ($license) = @_;
   my ($volume, $directories)
      = splitpath(license_directory(), 'no-file');
   return catpath($volume, $directories, $license);
}

sub load_license {
   my ($license) = @_;
   my $path = license_path($license);
   croak "cannot find template for license '$license' at '$path'"
      unless -r $path;
   return load_file($path);
}

sub available_licenses {
   my %opts = @_ && ref($_[0]) ? %{$_[0]} : @_;
   my $dir = license_directory();
   opendir my $dh, $dir
      or croak "cannot opendir('$dir'): $!";

   my ($volume, $directories) = splitpath($dir, 'no-file');
   my %data_for;
   for my $candidate (readdir $dh) {
      my $path = catpath($volume, $directories, $candidate);
      next if -d $path || ! -r $path;
      $data_for{$candidate} = $opts{load} ? load_file($path) : $path;
   }
   closedir $dh;

   return %data_for if wantarray();
   return \%data_for;
}

1;
__END__
