#!/usr/bin/perl

push (@INC, "./");

use strict;
use warnings;
use HTTP::Tiny;
use Getopt::Long;
use Log::Log4perl;
use host;

Log::Log4perl::init('log4perl.conf');

my $logger = Log::Log4perl->get_logger("applogger");
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
    $logger->debug("Pushing new url $url on todo stack.");
    push (@hrefs, $url);
    $visitedurls{$url}=1;
    open (DFILE, ">>$urlsfilename");
    print DFILE "$url\r\n";
    close (DFILE);
  }
  $logger->trace("Leaving pushurl");
}

sub extract_host_and_protocol {
  $logger->trace("Entering extract_host");
  my ($url) = @_;
  ( $url =~ /(https?:\/\/[a-zA-Z0-9.]*)\/?/ );
  my $tmphost = $1;
  $logger->debug("Extracted host $tmphost from url $url");
  $logger->trace("Leaving extract_host");
  return $tmphost;
}

sub pushhost {
  $logger->trace("Entering pushhost");
  my ($hostname) = @_;
  $logger->debug("Pushing host \"$hostname\" to list of visited hosts");
  my $found = 1;
  foreach (@visitedhosts) {
    if ($_ eq $hostname) {
      $found=0;
      last;
    }
  }
  if ($found == 1) {
    $logger->debug("Storing hostname $hostname");
    push(@visitedhosts, $hostname);
    open (DFILE, ">>$hostsfilename");
    print DFILE "$hostname\r\n";
    close (DFILE);
  }
  $logger->trace("Leaving pushhost");
}

sub normalize_url {
  $logger->trace("Entering normalize_url");
  my ($hostname, $url) = @_;
  $logger->debug("Normalizing url $url with host $hostname");
  my $finalurl;
  chomp($url);
  if ($url =~ /^\/\//) {
    $finalurl = "";
  } else {
    if ($url =~ /^\/.*$/) {
      $finalurl = $hostname . $url;
    } else {
      if ($url =~ /^https?:\/\//) {
	$finalurl = $url;
      } else {
	$finalurl = $hostname . "/" . $url;
      }
    }
  }
  $logger->debug("Normalizing url \"$url\" -> \"$finalurl\"");
  $logger->trace("Leaving normalize_url");
  return $finalurl;
}

sub nexturl {
  my $result;
  if (scalar(@hrefs) == 0) {
    die "Ran into dead end. No urls left.";
  } else {
    if ($searchstyle == 0) {
      $result = pop(@hrefs);
    } else {
      $result = $hrefs[$urlcount];
    }
    $urlcount++;
    if ($urlcount > $umax) {
      die "umax was reached."
    }
  }
  return $result;
}

sub init() {
  $logger->trace("Entering initialization");
  GetOptions("target=s" => \$target, "umax=i" => \$umax);
  $target =~ /(https?:\/\/[a-zA-Z0-9.]+)\/?/;
  pushurl($target);
  $logger->debug("Initialized with target $target");
  $logger->trace("Leaving initialization");
}

sub main_loop() {
  while (@hrefs) {
    my $nexturl = nexturl();
    $logger->debug("Asking HTTP::Tiny to fetch url \"$nexturl\"");
    my $response = HTTP::Tiny->new->get($nexturl);
    #while (my ($k, $v) = each %{$response->{headers}}) {
    #  for (ref $v eq 'ARRAY' ? @$v : $v) {
    #    print "$k: $_\n";
    #  }
    #}
    #print $response->{content};
    $host = extract_host_and_protocol($nexturl);
    pushhost($host);
    $logger->debug("Search and process new hrefs");
    if (length ($response->{content})) {
      my @newhrefs = $response->{content} =~ /href=\"([\/a-zA-Z0-9:?&.]+)\"/gi;
      my $debugstring = "New hrefs found: ";
      foreach (@newhrefs) {
	$debugstring = $debugstring . "$_, ";
      }
      $logger->debug($debugstring);
      foreach (@newhrefs) {
	my $finalurl = normalize_url($host, $_);
	if (length($finalurl) > 0) {
	  pushurl($finalurl);
	}
      }
    }
  }
}

init();

main_loop();
