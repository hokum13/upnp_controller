#!/usr/bin/perl
use Net::UPnP;
use Net::UPnP::ControlPoint;
use Net::UPnP::AV::MediaRenderer;
use Net::UPnP::Device;
use Proc::Daemon;
use Proc::PID::File;
use threads;
my $host = 'localhost';
my $database = 'test';
my $password = 'password';
my $user = 'root';
my %threads = ();

while (1) {
	print '-';
	my @uuids = get_render_list( $host, $database, $password, $user);
	foreach my $uuid ( @uuids) {
		if (not defined $threads{ $uuid}) {
				print '+';
				$threads{ $uuid} = threads->create( \&thread_main, $uuid);
		} else {
			if ( not $threads{ $uuid}->is_running()) {
				print '+';
				$threads{ $uuid} = threads->create( \&thread_main, $uuid);
			}
		}
	}
	sleep( 600);
}

sub get_render_list {
	use DBI;
	my ( $host, $database, $password, $user) = @_;
	my $dbh = DBI->connect( "DBI:mysql:".$database.":".$host, $user, $password);
	my $quest = "select uuid from render_list";
	my $sth = $dbh->prepare( $quest);
	$sth->execute();
	my @uuids;
	while ( my @uuid = $sth->fetchrow_array()) {
#		print $uuid[0];
		push @uuids, $uuid[0];
	}
	return @uuids;
	$sth->finish();
	$dbh->disconnect();
}

sub thread_main {

	my $dev = get_render($_[ 0]);
	if ( $dev eq "3") {
		print "*";
	} else {
		while ( 1) {
			my $address = get_file( $_[ 0], $host, $database, $password, $user);
			my $meta = get_meta($address);
			if ($address eq "3") {
				sleep( 10);
			} else {
				play_to_render( $address, $meta, $dev);
			}
		}
	}
}

sub get_meta { 
	my ($file_address) = @_;
	my $meta = '&lt;DIDL-Lite xmlns=&quot;urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/&quot; xmlns:dc=&quot;http://purl.org/dc/elements/1.1/&quot; xmlns:upnp=&quot;urn:schemas-upnp-org:metadata-1-0/upnp/&quot; xmlns:dlna=&quot;urn:schemas-dlna-org:metadata-1-0/&quot;&gt;';
	$meta .= '&lt;item id=&quot;3$16$5&quot; parentID=&quot;3$16&quot; refID=&quot;64$5&quot; restricted=&quot;1&quot;&gt;';
	$meta .= '&lt;dc:title&gt;';
	$meta .= 'jpg';
	$meta .= '&lt;/dc:title&gt;';
	$meta .= '&lt;dc:creator&gt;';
	$meta .= 'Unknown';
	$meta .= '&lt;/dc:creator&gt;';
	$meta .= '&lt;upnp:genre&gt;';
	$meta .= 'Unknown';
	$meta .= '&lt;/upnp:genre&gt;';
	$meta .= '&lt;res size=&quot;622918&quot; resolution=&quot;1920x1080&quot; protocolInfo=&quot;http-get:*:image/jpeg:DLNA.ORG_PN=JPEG_LRG;DLNA.ORG_OP=01;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=00F00000000000000000000000000000&quot;&gt;';
	$meta .= $file_address;
	$meta .= '&lt;/res&gt;';
	$meta .= '&lt;upnp:class&gt';
	$meta .= ';object.item.imageItem.photo';
	$meta .= '&lt;/upnp:class&gt;';
	$meta .= '&lt;/item&gt;';
	$meta .= '&lt;/DIDL-Lite&gt;';
	return $meta;
}

sub play_to_render {
	my ($address, $meta, $dev) = @_;
	print "\n".$address."\n";
	my $renderer = Net::UPnP::AV::MediaRenderer->new();
	$renderer->setdevice($dev);
	$renderer->stop(); 
	$renderer->setAVTransportURI(InstanceID => 0,CurrentURI => $address, CurrentURIMetaData => $meta);
	$renderer->play(); 
}

sub get_file {
	use DBI;
	my ( $uuid, $host, $database, $password, $user) = @_;
	my $dbh = DBI->connect( "DBI:mysql:".$database.":".$host, $user, $password);
	my $quest = "select address, id from play_list where tv_uuid like '".$uuid."' and CURRENT_TIMESTAMP > starttime limit 1";
	my $sth = $dbh->prepare( $quest);
	$sth->execute();
	if ( my ( $address, $id) = $sth->fetchrow_array()) {
		$quest = "DELETE FROM play_list WHERE id = ".$id;
		$dbh->do( $quest);
		return $address;
	} else {
		return "3";
	}
	$sth->finish();
	$dbh->disconnect();
}

sub get_render {
	my ( $uuid) = @_;
	my $obj = Net::UPnP::ControlPoint->new();
	my @dev_list = ();
	while (@dev_list <= 0 || $retry_cnt > 5) {
		@dev_list = $obj->search(st =>'upnp:rootdevice', mx => 3);
		$retry_cnt++;
	} 
	
	foreach $dev ( @dev_list) {
		my $udn = $dev->getudn();
#		print $udn."\n";
		my @udns = split /:/, $udn;
		if ( $udns[ 1] eq $uuid) {
			return $dev;
			next;
		}
	} 
	return "3";
}
