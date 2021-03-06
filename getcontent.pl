#!/usr/bin/perl
use Net::UPnP::ControlPoint;
use Net::UPnP::AV::MediaServer;

my $host = 'localhost';
my $database = 'test';
my $password = 'password';
my $user = 'root';

my $obj = Net::UPnP::ControlPoint->new();

@dev_list = $obj->search(st =>'upnp:rootdevice', mx => 3);

$devNum= 0;
foreach $dev (@dev_list) {
	$device_type = $dev->getdevicetype();
	if  ($device_type ne 'urn:schemas-upnp-org:device:MediaServer:1') {
		next;
	}
	unless ($dev->getservicebyname('urn:schemas-upnp-org:service:ContentDirectory:1')) {
		next;
	}
	$mediaServer = Net::UPnP::AV::MediaServer->new();
	$mediaServer->setdevice($dev);
	@content_list = $mediaServer->getcontentlist(ObjectID => 0);
	foreach $content (@content_list) {
		print_content($mediaServer, $content, 1);
	}
	$devNum++;
}

sub print_content {
	my ($mediaServer, $content, $indent) = @_;
	my $id = $content->getid();
	my $title = $content->gettitle();
	for ($n=0; $n<$indent; $n++) {
	}
	if ($content->isitem()) {
		if (not in_base( $content->geturl(), $host, $database, $password, $user)) {
			set_to_base( $content->geturl(), $content->gettitle(), $host, $database, $password, $user);
		}
	}
	unless ($content->iscontainer()) {
		return;
	}
	@child_content_list = $mediaServer->getcontentlist(ObjectID => $id );
	if (@child_content_list <= 0) {
		return;
	}
	$indent++;
	foreach my $child_content (@child_content_list) {
		print_content($mediaServer, $child_content, $indent);
	}

}

sub in_base {
	use DBI;
	my ( $url, $host, $database, $password, $user) = @_;
	my $dbh = DBI->connect( "DBI:mysql:".$database.":".$host, $user, $password);
	my $quest = "select id from dlna_files where address like '".$url."'";
	my $sth = $dbh->prepare( $quest);
	$sth->execute();
	if ( my ( $address, $id) = $sth->fetchrow_array()) {
		return "1";
	} else {
		return "0";
	}
	$sth->finish();
	$dbh->disconnect();
}

sub set_to_base {
	use DBI;
	my ( $url, $name, $host, $database, $password, $user) = @_;
	my $dbh = DBI->connect( "DBI:mysql:".$database.":".$host, $user, $password);
	$quest = "INSERT INTO dlna_files (`id`, `address`, `name`) VALUES (NULL, '".$url."', '".$name."')";
	$dbh->do( $quest);
	$dbh->disconnect();
}
