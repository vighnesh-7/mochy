use strict;
use warnings;
use DynaLoader;

my ($library, $function, $argument) = @ARGV;
die "usage: mediaremote.pl LIBRARY FUNCTION [ARGUMENT]\n" unless $library && $function;
$ENV{MOCHY_ARG} = defined $argument ? $argument : "";
my $handle = DynaLoader::dl_load_file($library, 0) or die DynaLoader::dl_error();
my $symbol = DynaLoader::dl_find_symbol($handle, $function) or die DynaLoader::dl_error();
DynaLoader::dl_install_xsub("main::bridge", $symbol);
bridge();
