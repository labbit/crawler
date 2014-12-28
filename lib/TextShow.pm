package TextShow;
use Mojo::Base 'Mojolicious';

use DBIx::Connector;

has 'dbconn' => sub {	
	my $self = shift;

	my $conn = DBIx::Connector->new( 'dbi:mysql:dbname=sometest;', 'someus', 'Cho8yi4G', {RaiseError => 1, AutoCommit => 0});
	my $dbh = $conn->dbh;
	$dbh->do('set names utf8');	

	return $conn;
};


sub startup {
	my $self = shift;

	# show text 
	my $r = $self->routes;
	$r->get('/')->to('show#all');
	$r->get('/:id' => [id => qr/\d+/])->to('show#someone', id => 2);
	$r->get('/tag/:tag')->to('show#taglist');

	
	# admin part
	$r->get('/form')->to('admin#auth', mymessage=> 'login, please');
	$r->get('/login')->to('admin#login');
	$r->get('/logout')->to('admin#logout');

	my $rn = $r->bridge('/admin')->to('admin#check');	
	$rn->route ->via('get')->to('admin#list');
	$rn->get('/:id/edit' => [id => qr/\d+/])->to('admin#edit');	
	$rn->get('/:id/preview' => [id => qr/\d+/])->to('admin#preview');	
	$rn->post('/:id/save' => [id => qr/\d+/])->to('admin#update');	

}



1;
