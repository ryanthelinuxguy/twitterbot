#!/usr/bin/env perl
#yum install perl-Config-IniFiles
#0 */3 * * * /usr/local/bin/diskspace.pl 1>/tmp/diskspace.pl 2>&1
use strict;
use Config::INI::Reader;
use Net::Twitter;

my $default_threshold = 80;
my @headers = qw(name size used free capacity mount); #This is used for easy parsing df
my $hostname = `hostname -s`; #TODO: Find better way
my $configfile = '/var/tmp/disk.ini';
my $dfcommand;

#Detect FreeBSD or Linux
if ( "$^O" eq 'freebsd' ) {
	$dfcommand = 'df | grep -v devfs | tail -n +2';
} elsif ( "$^O" eq 'linux' )  {
	$dfcommand='df -t ext3 -t ext4 -t ext2 -t btrfs -t vfat -t xfs | tail -n +2';
}
#Twitter Information
my $consumer_key = '';
my $consumer_secret = '';
my $token        = '';
my $token_secret = '';
my $nt = Net::Twitter->new(
      traits   => [qw/API::RESTv1_1/],
      consumer_key        => $consumer_key,
      consumer_secret     => $consumer_secret,
      access_token        => $token,
      access_token_secret => $token_secret,
      ssl                 => 1,
  );
if ( ! -e "$configfile" ) {
	my $df=`$dfcommand`;

	#Setup headers
	my @part; #Store the partitions

	open( INI, '>', "$configfile");
	foreach (split(/\n/, $df )) {
		my %info;
		@info{@headers} = split /\s+/;
		print INI "@info{mount}=$default_threshold\n";
	}
	my $result = $nt->update("\@ryanyoung1633 $hostname generated the ini file");
	
} else { 
	my $config = Config::INI::Reader->read_file( "$configfile");
	my $df=`$dfcommand`;
	foreach (split(/\n/, $df )) {
		my %info;
		@info{@headers} = split /\s+/;
		my $vol = @info{mount};
		my $threshold = $config->{'_'}->{$vol};
		my $current = @info{capacity};
		$current =~ tr/\%//d;

		#Lets check for a blank value, if we have a blank value then we can take care of it
		if ( $threshold == '' ) { 
			print "Blank threshold adding $vol\n";
			open( INI, '>>', "$configfile");
			print INI "$vol=$default_threshold\n";
			close INI;
			next;
		}
		if ( $current >= $threshold ) { 
			my $result = $nt->update("\@ryanyoung1633 $hostname $vol is ${current}% of a threshold of ${threshold}%");
		}
	}


}
