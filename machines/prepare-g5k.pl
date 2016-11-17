#!/usr/bin/env perl
# Supplementary steps for running distributed-make on g5k
use strict;
use warnings;
use threads;
use threads::shared;

sub provision_host {
  my ($host, $first) = @_;
  system('ssh root@' . $host . ' "bash -s" < root-provision.sh');
  system('ssh root@' . $host . ' "bash -s" < g5k-provision.sh');

  if ($first) {
    system('scp ~/.ssh/id_rsa dismake@' . $host . ':~/.ssh/');
    system('ssh dismake@' . $host . q{ 'mkdir ~/distributed-make-src'});
    system('scp -r ../../distributed-make/* dismake@' . $host . ':~/distributed-make-src/');
    system('ssh dismake@' . $host . q{ 'bash -c "cd distributed-make-src && /usr/local/rvm/bin/rvm default do bundle install"'})
  }
}

my @workers = (
  "[]",
  "[a]",
  "[a, b]",
  "[a, b, c]",
  "[a, b, c, d]",
  "[a, b, c, d, e]",
  "[a, b, c, d, e, f]",
  "[a, b, c, d, e, f, g]",
  "[a, b, c, d, e, f, g, h]"
);

# Read hosts to an array
open HOSTFILE, 'hostfile.txt';
my @hosts;
while (<HOSTFILE>) {
  chomp;
  push @hosts, $_
}
close HOSTFILE;

# Remove the old yml files in ../config
unlink for <../config/grid5000-*.yml>;

# Build files for all worker counts up to hosts * 8 - 1
for my $cnt (1..(8 * (scalar @hosts) - 1)) {
  my $filename = sprintf('grid5000-%.3d.yml', $cnt);
  open ENVFILE, ">../config/$filename";
  print ENVFILE <<EOT;
---
release_path: /home/dismake/distributed-make
user: dismake
hosts:
EOT

  my $c = $cnt;
  for my $host (@hosts) {
    my $n = 8;
    $n = 7 if $host eq $hosts[0];
    $n = $c if $n > $c;
    print ENVFILE "  $host: " . $workers[$n] . "\n";
    $c -= $n;
    last unless $c;
  }
  close ENVFILE;
}

my @threads = map { threads->create(\&provision_host, $_, $_ eq $hosts[0]) } @hosts;
$_->join for @threads
