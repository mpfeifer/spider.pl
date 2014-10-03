package spider;

use strict;
use warnings;
use diagnostics;
use HTTP::Tiny;
use Log::Log4perl;

Log::Log4perl::init('log4perl.conf');

sub new {
  my $self = {
	      logger => Log::Log4perl->get_logger("applogger"),
	      target => undef,
	      host => undef,
	      umax => 15000,
	      urlsfilename => "urls.txt",
	      hostsfilename => "hosts.txt",
	      urlcount => 0,
	      searchstyle => 1, # 0 - depth first ; 1 - breadth first
	      hrefs => [],
	      visitedhosts => [],
	      visitedips => [],
	      visitedurls => {}
	     };
  bless ($self, 'spider');
  return $self;
}

#######################
## Getter and Setter ##
#######################

sub target {
  my $self = shift;
  if (@_) { $self->{target} = shift }
  return $self->{target};
}

sub umax {
  my $self = shift;
  if (@_) { $self->{umax} = shift }
  return $self->{umax};
}

sub random_url {
  my $self = shift;
  return sprintf("http://%u.%u.%u.%u/", rand(256), rand(256), rand(256), rand(256));
}

sub pushurl {
  my $self = shift;
  my $url = shift;

  $self->{logger}->trace("Entering pushurl");
  if (! exists( $self->{visitedurls}->{$url} )) {
    $self->{logger}->debug("Pushing new url $url on todo stack.");
    push (@{$self->{hrefs}}, $url);
    $self->{visitedurls}->{$url}=1;
    open (DFILE, ">>$self->{urlsfilename}");
    print DFILE "$url\r\n";
    close (DFILE);
  }
  $self->{logger}->trace("Leaving pushurl");
}

sub extract_host_and_protocol {
  my $self = shift;
  my $url = shift;
  my $tmphost = undef;

  $self->{logger}->trace("Entering extract_host");

  $url =~ /(https?:\/\/[a-zA-Z0-9.]*)\/?/;
  $tmphost = $1;

  $self->{logger}->debug("Extracted host $tmphost from url $url");
  $self->{logger}->trace("Leaving extract_host");

  return $tmphost;
}

sub pushhost {
  my $self = shift;
  my $hostname = shift;
  my $found = 1;

  $self->{logger}->trace("Entering pushhost");
  $self->{logger}->debug("Pushing host \"$hostname\" to list of visited hosts");

  foreach (@{$self->{visitedhosts}}) {
    if ($_ eq $hostname) {
      $found=0;
      last;
    }
  }

  if ($found) {
    $self->{logger}->debug("Storing hostname $hostname");
    push(@{$self->{visitedhosts}}, $hostname);
    open (DFILE, ">>$self->{hostsfilename}");
    print DFILE "$hostname\r\n";
    close (DFILE);
  };

  $self->{logger}->trace("Leaving pushhost");
}

sub normalize_url {
  my $self = shift;
  my $hostname = shift;
  my $url = shift;
  my $result;

  $self->{logger}->trace("Entering normalize_url");
  $self->{logger}->debug("Normalizing url $url with host $hostname");

  chomp($url);
  if ($url =~ /^\/\//) {
    $result = "http://" . $url;
  } else {
    if ($url =~ /^\/.*$/) {
      $result = $hostname . $url;
    } else {
      if ($url =~ /^https?:\/\//) {
	$result = $url;
      } else {
	$result = $hostname . "/" . $url;
      }
    }
  }

  $self->{logger}->debug("Normalizing url \"$url\" -> \"$result\"");
  $self->{logger}->trace("Leaving normalize_url");

  return $result;
}

sub nexturl {
  my $self = shift;
  my $result = "xyz://invalid";

  $self->{logger}->trace("Entering nexturl");


  if ($self->{hrefs} == 0) {
    die "Ran into dead end. No urls left.";
  } else {
    if ($self->{searchstyle} == 0) {
      $result = pop(@{$self->{hrefs}});
    } else {
      my $index = $self->{urlcount};
      if ($index >= $self->{hrefs}) {
	die "Ran out of urls";
      }
      $result = $self->{hrefs}[$index];
      $self->{logger}->debug("nexturl will process \"$result\"");
    }
    $self->{urlcount} = $self->{urlcount} + 1;
    $self->{logger}->debug("urlcount is now $self->{urlcount}");
    if ($self->{urlcount} > $self->{umax}) {
      die "umax was reached."
    }
  }
  $self->{logger}->trace("Leaving nexturl");
  return $result;
}

sub init() {
  my $self = shift;
  $self->{logger}->trace("Entering initialization");
  $self->{logger}->debug("Initializing spider and found target $self->{target}");
  $self->pushurl($self->{target});
  $self->{logger}->trace("Leaving initialization");
}

sub go() {
  my $self = shift;
  $self->init();
  while (@{$self->{hrefs}}) {
    my $next_url = $self->nexturl();
    $self->{logger}->debug("Asking HTTP::Tiny to fetch url \"$next_url\"");
    my $response = HTTP::Tiny->new->get($next_url);
    while (my ($k, $v) = each %{$response->{headers}}) {
      for (ref $v eq 'ARRAY' ? @$v : $v) {
        $self->{logger}->debug("$k: $_\n");
      }
    }
    $self->{logger}->debug("Response received: " . $response->{content});
    $self->{host} = $self->extract_host_and_protocol($next_url);
    $self->pushhost($self->{host});
    $self->{logger}->debug("Search and process new hrefs");
    if (length($response->{content})>0) {
      my @newhrefs = $response->{content} =~ /href=\"([\/a-zA-Z0-9:?&.]+)\"/gi;
      if (scalar @newhrefs) {
	my $debugstring = "New hrefs found: ";
	foreach (@newhrefs) {
	  $debugstring = $debugstring . "$_, ";
	}
	$self->{logger}->debug($debugstring);
	foreach (@newhrefs) {
	  my $finalurl = $self->normalize_url($self->{host}, $_);
	  if (length($finalurl) > 0) {
	    $self->pushurl($finalurl);
	  }
	}
      }
    }
  }
}

1;
