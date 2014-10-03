#!/usr/bin/perl

push (@INC, "./");

use strict;
use warnings;
use spider;

my $spider = spider->new();
$spider->target("http://dir.yahoo.com/computers_and_internet/communications_and_networking/home_networking/");
$spider->umax("10000");
$spider->go();
