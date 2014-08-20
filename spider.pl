#!/usr/bin/perl

use strict;
use warnings;
use HTTP::Tiny;
use Getopt::Long;
use Log::Log4perl;

Log::Log4perl::init('log4perl.conf');

# TODO:
#      - remove http:// prefix from hosts
#      - resolve ips of hosts
#      - do a breadth first search
#      - configure search style breadth/depths-first

my $logger = Log::Log4perl->get_logger("spider");
my $target;
my $host;
my $umax=15000;
my $urlsfilename="urls.txt";
my $hostsfilename="hosts.txt";
my $urlcount=0;
my $searchstyle=1; # 0 - depth first ; 1 - breadth first

my @hrefs;
my @visitedhosts;
my @visitedips;

my %visitedurls;

sub random_url {
  return sprintf("http://%u.%u.%u.%u/", rand(256), rand(256), rand(256), rand(256));
}

sub pushurl {
  $logger->trace("Entering pushurl");
  my ($url) = @_;
  if (! exists($visitedurls{$url})) {
    $logger->debug("Pushing new url $url.");
    push (@hrefs, $url);
    $visitedurls{$url}=1;
    open (DFILE, ">>$urlsfilename");
    print DFILE "$url\r\n";
    close (DFILE);
  }
  $logger->trace("Leaving pushurl");
}

sub extract_host {
  $logger->trace("Entering extract_host");
  my ($url) = @_;
  ( $url =~ /(https?:\/\/[a-zA-Z0-9.]+)\/?/ );
  my $host = $1;
  $logger->trace("Leaving extract_host");
  return $host;
}

sub pushhost {
  $logger->trace("Entering pushhost");
  my ($hostname) = @_;
#  $hostname =~ s/https?:\/\///;
  $logger->debug("Found host $host");
  my $found = 1;
  foreach (@visitedhosts) {
    if ($_ eq $host) {
      $found=0;
      last;
    }
  }
  if ($found == 1) {
    push(@visitedhosts, $hostname);
    open (DFILE, ">>$hostsfilename");
    print DFILE "$host\r\n";
    close (DFILE);
  }
  $logger->trace("Leaving pushhost");
}

sub normalize_url {
  $logger->trace("Entering normalize_url");
  my ($hostname, $url) = @_;
  my $finalurl;
  if ($url =~ /^[\/].*$/) {
    $finalurl = $hostname . $url;
  } else {
    if ($url =~ /^https?:\/\//) {
      $finalurl = $url;
    } else {
      $finalurl = $hostname . "/" . $url;
    }
  }
  $logger->debug("Normalizing url \"$url\" -> \"$finalurl\"");
  $logger->trace("Leaving normalize_url");
  return $finalurl;
}

sub nexturl {
  my $result;
  if ($searchstyle == 0) {
    $result = pop(@hrefs);
  } else {
    $result = $hrefs[$urlcount];
  }
  $urlcount++;
  if ($urlcount > $umax) {
    die "umax was reached."
  }
  return $result;
}

sub init() {
  $target=random_url();
  GetOptions("target=s" => \$target, "umax=i" => \$umax);
  $target =~ /(https?:\/\/[a-zA-Z0-9.]+)\/?/;
  $host=$1;
  $logger->debug("Starting spider with target host \"$host\"");
  pushurl($target);
}

sub main_loop() {
  while (@hrefs) {
    my $nexturl = nexturl();
    $logger->debug("Fetching url \"$nexturl\"");
    my $response = HTTP::Tiny->new->get($nexturl);
    #while (my ($k, $v) = each %{$response->{headers}}) {
    #  for (ref $v eq 'ARRAY' ? @$v : $v) {
    #    print "$k: $_\n";
    #  }
    #}
    #print $response->{content};
    $host = extract_host($nexturl);
    pushhost($host);
    if (length ($response->{content})) {
      my @newhrefs = $response->{content} =~ /href=\"([\/a-zA-Z0-9:.]+)\"/ig;
      foreach (@newhrefs) {
	my $finalurl = normalize_url($host, $_);
	pushurl($finalurl);
      }
    }
  }
}

init();

main_loop();
