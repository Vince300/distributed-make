#!/bin/bash
# This file is a provisioning script that setups required software for this project to run on a x64 jessie system.
# Note: this shell script is self-contained, once uploaded to a host it can be run with only internet access as a
# dependency

# Fail if any command fail
set -eo pipefail

# This script must be run as root.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# List of packages to install
apt_required=""

# A function that installs requirements through apt-get
apt_get_require () {
  test_name="$1"; shift
  if [[ -z "$1" ]]; then
    apt_name="$test_name"
  else
    apt_name="$1"; shift
  fi

  if ! hash "$test_name" 2>/dev/null; then
    apt_required="$apt_required $apt_name"
  else
    echo "$apt_name is already installed, skipping."
  fi
}

apt_get_install () {
  # Only install packages if there are packages to install
  if [[ -n "$apt_required" ]]; then
    # Update before install
    apt-get update

    # Install packages
    apt-get install -y $apt_required
  fi
}

# Disable progress on curl
echo "-s
-S
" >~/.curlrc

if [[ -d ~vagrant ]]; then
  cp ~/.curlrc ~vagrant/.curlrc
  chown vagrant:vagrant ~vagrant/.curlrc
fi

# Install required packages

# First requirements
apt_get_require curl
apt_get_require git

# Requirements for various example Makefiles
apt_get_require convert ImageMagick
apt_get_require unzip
apt_get_require ffmpeg
apt_get_require bc
apt_get_require avconv "libav-tools=7:3.2-2~bpo8+2"

# Use gawk as the testing tool for ruby dependencies
apt_get_require gawk "gawk g++ libreadline6-dev zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 autoconf libgmp-dev libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev"

# Use mesa-utils as the testing tool for blender dependencies
apt_get_require glxinfo "libjpeg62-turbo libsdl1.2debian mesa-utils"

# Install all apt packages (saves reading the database multiple times)
apt_get_install

# Install RVM
if ! hash rvm 2>/dev/null; then
  curl -sSL https://rvm.io/mpapis.asc | gpg --import -
  curl -sSL https://get.rvm.io | bash -s stable

  # Activate RVM
  if ! type rvm 2>/dev/null; then
    source /etc/profile.d/rvm.sh
  fi
else
  echo "rvm is already installed, skipping."

   # Activate RVM
   source /etc/profile.d/rvm.sh
fi

# Install Ruby 2.3.1
if ! rvm list default | grep "ruby-2.3.1" >/dev/null 2>/dev/null; then
  # Install Ruby
  rvm install 2.3.1

  # Use installed Ruby
  rvm use 2.3.1
fi

# Install Bundler
if ! hash bundle 2>/dev/null; then
  gem install bundler -v 1.13.2
fi

blender_install () {
  version="$1"; shift
  source_url="$1"; shift

  if ! hash blender-$version 2>/dev/null; then
    # Download tarball
    curl -sS -o /tmp/blender-$version.tar.bz2 "$source_url"

    # Extract Blender
    mkdir -p /opt/blender-$version
    tar -C /opt/blender-$version --strip-components 1 -xf /tmp/blender-$version.tar.bz2
    rm -f /opt/blender-$version.tar.bz2

    # Make link
    ln -s /opt/blender-$version/blender /usr/local/bin/blender-$version
  else
    echo "blender-$version is already installed, skipping."
  fi
}

# Install Blender 2.49
blender_install "2.49" "http://download.blender.org/release/Blender2.49/blender-2.49-linux-glibc236-py26-x86_64.tar.bz2"

# Install Blender 2.59
blender_install "2.59" "http://download.blender.org/release/Blender2.59/blender-2.59-linux-glibc27-x86_64.tar.bz2"

# Install "premier"
if ! hash premier 2>/dev/null; then
  echo "#include<stdio.h>
#include<stdlib.h>
#include<math.h>

int main(int argc, char **argv) {

	if (argc != 3) {
		fprintf(stderr, \"usage : %s début fin\\n\", argv[0]);
		exit(1);
	}

	int debut = atoi(argv[1]);
	int fin = atoi(argv[2]);
	int i;
	for(i = debut; i <= fin ; i++) {
		int j;
		char i_premier = 1;
		if (i % 2 == 0) {
			i_premier = 0;
		} else {
			for(j = 3 ; j <= sqrt(i) ; j+=2) {
				if (i % j == 0) {
					i_premier = 0;
					break;
				}
			}
		}
		if (i_premier) printf(\"%d\\n\", i);
	}
	exit(0);
}
" >/tmp/premier.c

  gcc -o /usr/local/bin/premier -O3 /tmp/premier.c -lm
  echo "installed premier to /usr/local/bin/premier."
else
  echo "premier is already installed, skipping."
fi

# Install matrix multiplication tools
tee /usr/local/bin/matfuse <<\FUSE
#!/usr/bin/env perl

use strict;
use warnings;

my ($out, $sx, $sy) = splice(@ARGV, 0, 3);

my @C;
my $current_x = 0;
my $last_x = 0;
my $current_y = 0;
my $matrix_count = 0;

my $file;
foreach $file (@ARGV) {
	open(IN, " < $file");
	my $header = <IN>;
	my @line;
	my $count = 0;
	$matrix_count++;
	while(<IN>) {
		chomp();
		@line = split / /;
		#put at right place
		$C[$current_x] = [] unless defined $C[$current_x];
		$C[$current_x][$current_y+$_] = $line[$_] foreach (0..$#line);
		$current_x++;
		$count++;
	}
	close(IN);
	if ($matrix_count == $sy) {
		$matrix_count = 0;
		$last_x += $count;
		$current_y = 0;
	} else {
		$current_x = $last_x;
		$current_y += scalar @line;
	}
}

open(OUT, "> $out");
my $m = scalar @C;
my $n = scalar @{$C[0]};
print OUT "$m $n\n";
foreach(@C) {
	print OUT join(" ", @{$_})."\n";
}
close(OUT);
FUSE
chmod +x /usr/local/bin/matfuse
echo "installed matfuse to /usr/local/bin/matfuse."

tee /usr/local/bin/matmultiply <<\MULTIPLY
#!/usr/bin/env perl

use strict;
use warnings;

my ($out, $in1, $in2) = @ARGV;

open(IN1, " < $in1");
open(IN2, " < $in2");
my $header = <IN1>;
chomp($header);
my ($m, $n) = split(/ /, $header);
$header = <IN2>;
chomp($header);
my($n2, $o) = split(/ /, $header);
die "error in sizes" unless $n == $n2;
my @A;
while(<IN1>) {
	chomp();
	my @line = split / /;
	push @A, [@line];
}
close(IN1);
my @B;
while(<IN2>) {
	chomp();
	my @line = split / /;
	push @B, [@line];
}
close(IN2);

my @C;

my ($i, $j, $k);
foreach $i (0..($m-1)) {
	push @C, [];
	foreach $j (0..($o-1)) {
		my $sum = 0;
		foreach $k (0..($n-1)) {
			$sum += $A[$i][$k] * $B[$k][$j];
		}
		$C[$i][$j] = $sum;
	}
}

open(OUT, "> $out");
print OUT "$m $o\n";
foreach(@C) {
	print OUT join(" ", @{$_})."\n";
}
close(OUT);
MULTIPLY
chmod +x /usr/local/bin/matmultiply
echo "installed matmultiply to /usr/local/bin/matmultiply."

tee /usr/local/bin/matsplit <<\SPLIT
#!/usr/bin/env perl

use strict;
use warnings;

my ($output_file, $input_file, $sx, $sy, $x, $y) = @ARGV;

die "parameters missing" unless defined $y;

open(FILE, "< $input_file");
my $header = <FILE>;
my ($w, $h) = split(/ /, $header);
my $bw = $w / $sx;
my $bh = $h / $sy;
my $start_x = $bw * ($x-1);
my $end_x = $bw * $x;
my $start_y = $bh * ($y-1);

open(DFILE, "> $output_file");
print DFILE "$bw $bh\n";

my $count = 0;
while(<FILE>) {
	chomp();
	last if $count >= $end_x;
	if ($count >= $start_x) {
		my @line = split / /;
		my @selection = splice(@line, $start_y, $bh);
		print DFILE join(" ", @selection)."\n";
	}
	$count++;
}

close(FILE);
close(DFILE);
SPLIT
chmod +x /usr/local/bin/matsplit
echo "installed matsplit to /usr/local/bin/matsplit."

tee /usr/local/bin/matsum <<\SUM
#!/usr/bin/env perl

use strict;
use warnings;

my ($out, @in) = @ARGV;
my ($m, $n);
my @A_in=();
my $size=0;
foreach (@in) {
	open(IN, " < $_");
	my $header = <IN>;
	chomp($header);
	my ($m1, $n1) = split(/ /, $header);
  ($m, $n)=($m1, $n1) unless defined $m and defined $n;
	die "error in sizes" unless $n == $n1 and $m == $m1;
  my @tmp;
	while(<IN>) {
	  chomp();
	  my @line = split / /;
	  push @tmp, [@line];
	}
	close(IN);
  $A_in[$size]=[@tmp];
  $size++;
}
	my @C;

	my ($i, $j);
	foreach $i (0..($m-1)) {
	  push @C, [];
	  foreach $j (0..($n-1)) {
      my $k;
      for($k=0;$k<$size;$k++){
        $C[$i][$j] += $A_in[$k][$i][$j];
      }
	  }
	}

	open(OUT, "> $out");
	print OUT "$m $n\n";
	foreach(@C) {
	  print OUT join(" ", @{$_})."\n";
	}
	close(OUT);
SUM
chmod +x /usr/local/bin/matsum
echo "installed matsum to /usr/local/bin/matsum."
