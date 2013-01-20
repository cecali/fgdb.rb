#!/usr/bin/perl

use strict;
use warnings;

my $config =  "/etc/svn/rtrc";

use RT::Client::REST;    
use RT::Client::REST::Ticket;    

use JSON;

my $F;
open $F, $config;
my %conf = ();
foreach(<$F>) {
    my @a = split /\s+/, $_;
    $conf{$a[0]} = $a[1];
}

my $rt = RT::Client::REST->new(server => $conf{server});
$rt->login(username => $conf{user}, password => $conf{passwd});

my $json = JSON->new->allow_nonref;

my $f = $ARGV[0];
open my $FH, '<', $f;
my @a = <$FH>;
my $json_s = join '', @a;

my $data = $json->decode($json_s);

#print "HERES YOUR INFORMATION\n";
#use Data::Dumper;
#print Dumper($data) . "\n";

#$data{}; # to be pushed into fields

#exit;

my $os = $data->{"OS"}; # already in initial content
my $tech = $data->{"Technician ID"};
my $type = $data->{"Type of Box"};
my $issues = $data->{"Issues"};
my $name = $data->{"Adopter Name"};
my $email = $data->{"Email"};
my $phone = $data->{"Phone"};
my $source = $data->{"Source"};
my $ts_source = $data->{"Ticket Source"};
my $content = $data->{"Initial Content"};
my $requestor = $data->{"Requestor"};
my $subject = $name . " - " . $type . " - " . $issues;
my @issues = split(", ", $issues);

my $ticket = RT::Client::REST::Ticket->new(
    rt  => $rt,
    priority => 50,
    requestors => [$requestor],
    queue => 'TechSupport',
    subject => $subject,
    
    cf => {
        'Support Level' => 'Irrelevant',
        'Ticket Source' => $ts_source,
	'Box source' => $source,
	'Type of Box' => $type,
	'Email' => $email,
	'phone' => $phone,
      'Adopter Name' => $name,
      'Intake Technician ID' => $tech,
	'Tech Support Issue' => \@issues
    },
    )->store(text => $content);
print $ticket->id . "\n";